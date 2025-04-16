import Foundation
import Flutter
import AVFoundation
import AudioToolbox

@objc public class NativeMetronomePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel!
    private var isPlaying = false
    private var currentBpm: Double = 100.0
    private var useVibration = false // バイブレーション設定を保持する変数を追加
    
    // オーディオエンジン関連
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode? // iOS 12以前のフォールバック用に追加する可能性あり
    
    // iOS 13以降でのみ利用可能
    @available(iOS 13.0, *)
    private var schedulerNode: AVAudioSourceNode? {
        get {
            // Swiftのsynthesized getter/setterを使うために必要
            // 実際には直接アクセスせず、ラッパー経由でアクセスする
            _schedulerNodeStorage as? AVAudioSourceNode
        }
        set {
            _schedulerNodeStorage = newValue
        }
    }
    private var _schedulerNodeStorage: Any? // 型をAnyにしてバージョン差異を吸収
    
    private var clickBuffer: AVAudioPCMBuffer?
    
    // リアルタイム処理用
    private var sampleTime: Double = 0
    private var nextBeatSampleTime: Double = 0
    private var engineSampleRate: Double = 44100.0
    private var beatIntervalSamples: Double = 0
    private let mutex = NSLock()
    
    // メトロノーム音の生成用パラメータ
    private let clickDurationMs: Int = 25
    private let frequency: Double = 900.0 // Hz
    private let amplitude: Double = 0.8
    private let sampleRate: Double = 44100.0
    
    // クリック波形データ（事前計算）
    private var clickWaveform: [Float] = []
    private var clickLength: Int = 0
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.example.native_metronome", binaryMessenger: registrar.messenger())
        let instance = NativeMetronomePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeAudio()
            result(true)
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let bpm = args["bpm"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            startMetronome(bpm: bpm)
            result(true)
        case "stop":
            stopMetronome()
            result(true)
        case "setTempo":
            guard let args = call.arguments as? [String: Any],
                  let bpm = args["bpm"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            setTempo(bpm: bpm)
            result(true)
        case "setVibration":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["useVibration"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            setVibration(enabled: enabled)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeAudio() {
        // クリック波形をあらかじめ生成
        generateClickWaveform()
        
        // オーディオセッションを設定
        configureAudioSession()
        
        // AVAudioEngineの初期化
        audioEngine = AVAudioEngine()
        
        guard let engine = audioEngine else { return }
        
        // サンプルレートを取得
        engineSampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        NSLog("Audio engine sample rate: \(engineSampleRate) Hz")
        
        if #available(iOS 13.0, *) {
            // iOS 13以降: AVAudioSourceNodeを使用
            let format = AVAudioFormat(standardFormatWithSampleRate: engineSampleRate, channels: 1)!
            
            // リアルタイムスレッドで動作するオーディオコールバック
            schedulerNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self, self.isPlaying else {
                    // 非再生中は無音を出力
                    let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                    for buffer in ablPointer {
                        memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                    }
                    return noErr
                }
                
                self.mutex.lock()
                
                // 出力バッファの取得
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let outputBuffer = ablPointer[0]
                let bufferPointer = outputBuffer.mData!.assumingMemoryBound(to: Float.self)
                
                // 各サンプルに波形データを書き込む
                for frame in 0..<Int(frameCount) {
                    var sample: Float = 0.0
                    
                    // メトロノームの拍のタイミングを計算
                    if self.sampleTime >= self.nextBeatSampleTime {
                        // 次の拍のタイミングを設定
                        self.nextBeatSampleTime += self.beatIntervalSamples
                        
                        // バイブレーション設定が有効であれば実行
                        if self.useVibration {
                            DispatchQueue.main.async {
                                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            }
                        }
                        
                        // メトロノーム拍をFlutterに通知（負荷が大きいのでメインスレッドで実行）
                        DispatchQueue.main.async {
                            let beatInfo: [String: Any] = [
                                "timestamp": Date().timeIntervalSince1970 * 1000,
                                "currentBpm": self.currentBpm
                            ]
                            self.channel.invokeMethod("onBeat", arguments: beatInfo)
                        }
                    }
                    
                    // サンプル位置が拍の開始からクリック長以内なら波形データを適用
                    let clickPosition = Int(self.sampleTime - (self.nextBeatSampleTime - self.beatIntervalSamples))
                    if clickPosition >= 0 && clickPosition < self.clickLength {
                        sample = self.clickWaveform[clickPosition]
                    }
                    
                    // バッファに書き込み
                    bufferPointer[frame] = sample
                    
                    // サンプル時間を進める
                    self.sampleTime += 1
                }
                
                self.mutex.unlock()
                
                return noErr
            }
            
            // エンジンにノードを接続
            engine.attach(schedulerNode!)
            engine.connect(schedulerNode!, to: engine.mainMixerNode, format: format)
            NSLog("Using AVAudioSourceNode for high precision (iOS 13+)")
            
        } else {
            // iOS 12以前: フォールバック (ここではエラーログのみ)
            NSLog("Error: iOS 13.0 or later is required for high-precision audio scheduling via AVAudioSourceNode.")
            // 必要に応じて、以前のAVAudioPlayerNode+CADisplayLink実装などをここに記述
        }
        
        // エンジンの開始
        do {
            try engine.start()
            NSLog("AVAudioEngine started successfully")
        } catch {
            NSLog("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    private func generateClickWaveform() {
        // クリック波形の長さを計算（サンプル数）
        clickLength = Int(sampleRate * Double(clickDurationMs) / 1000.0)
        clickWaveform = Array(repeating: 0.0, count: clickLength)
        
        // サイン波ベースのクリック音を生成
        let decay = exp(-5.0 / Double(clickLength))
        var currentAmplitude = amplitude
        
        for i in 0..<clickLength {
            let t = Double(i) / sampleRate
            let sample = sin(2.0 * .pi * frequency * t) * currentAmplitude
            
            // 波形データを格納
            clickWaveform[i] = Float(sample)
            
            // 減衰を適用（クリック音の減衰）
            currentAmplitude *= decay
        }
        
        NSLog("Click waveform generated: \(clickLength) samples")
    }
    
    private func startMetronome(bpm: Double) {
        mutex.lock()
        defer { mutex.unlock() }
        
        if isPlaying { return }
        
        currentBpm = bpm
        
        // テンポからサンプル間隔を計算（高精度）
        let beatsPerSecond = bpm / 60.0
        beatIntervalSamples = engineSampleRate / beatsPerSecond
        
        // 最初の拍を即座に再生（現在のサンプル時間に設定）
        sampleTime = 0
        nextBeatSampleTime = 0
        
        isPlaying = true
        
        NSLog("Metronome started with high precision: \(currentBpm) BPM, interval: \(beatIntervalSamples) samples")
    }
    
    private func stopMetronome() {
        mutex.lock()
        isPlaying = false
        mutex.unlock()
        
        NSLog("Metronome stopped")
    }
    
    private func setTempo(bpm: Double) {
        mutex.lock()
        currentBpm = bpm
        
        // テンポからサンプル間隔を再計算
        let beatsPerSecond = bpm / 60.0
        beatIntervalSamples = engineSampleRate / beatsPerSecond
        
        if isPlaying {
            // 次の拍のタイミングを再設定
            nextBeatSampleTime = sampleTime + beatIntervalSamples
        }
        mutex.unlock()
        
        NSLog("Tempo changed with high precision: \(bpm) BPM, interval: \(beatIntervalSamples) samples")
    }
    
    private func setVibration(enabled: Bool) {
        useVibration = enabled
        NSLog("Vibration setting changed: \(enabled)")
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // リアルタイム処理に最適な設定
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // バッファサイズを最小に設定
            let minDuration = 0.002 // 2ms（可能な限り小さく）
            try session.setPreferredIOBufferDuration(minDuration)
            
            // サンプルレートを最大に設定
            try session.setPreferredSampleRate(48000)
            
            try session.setActive(true)
            
            let actualBufferDuration = session.ioBufferDuration
            let actualSampleRate = session.sampleRate
            
            NSLog("Audio session configured for real-time processing:")
            NSLog("Buffer duration: \(actualBufferDuration * 1000) ms")
            NSLog("Sample rate: \(actualSampleRate) Hz")
            
        } catch {
            NSLog("Failed to configure audio session: \(error)")
        }
    }
    
    deinit {
        stopMetronome()
        audioEngine?.stop()
    }
}

import Foundation
import Flutter
import AVFoundation
import AudioToolbox

@objc public class NativeMetronomePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel!
    private var isPlaying = false
    private var currentBpm: Double = 100.0
    private var shouldVibrate = true
    
    // オーディオエンジン関連
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    
    // iOS 13+ で使用
    private var usesModernAPI: Bool = false
    private var schedulerNode: Any? // AVAudioSourceNodeをAnyとして保持（iOS 12との互換性のため）
    
    // リアルタイム処理用
    private var sampleTime: Double = 0
    private var nextBeatSampleTime: Double = 0
    private var engineSampleRate: Double = 44100.0
    private var beatIntervalSamples: Double = 0
    private let mutex = NSLock()
    
    // 従来のタイマー処理用
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var nextBeatTime: TimeInterval = 0
    private var lastBeatTime: TimeInterval = 0
    
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
                  let bpm = args["bpm"] as? Double,
                  let vibrate = args["vibrate"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            startMetronome(bpm: bpm, vibrate: vibrate)
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
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            shouldVibrate = enabled
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeAudio() {
        // iOS 13以上かどうかをチェック
        if #available(iOS 13.0, *) {
            usesModernAPI = true
            initializeModernAudio()
        } else {
            usesModernAPI = false
            initializeLegacyAudio()
        }
    }
    
    // iOS 13以上用の初期化（AVAudioSourceNode使用）
    @available(iOS 13.0, *)
    private func initializeModernAudio() {
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
        
        // オーディオソースノード（リアルタイム処理用）を作成
        let format = AVAudioFormat(standardFormatWithSampleRate: engineSampleRate, channels: 1)!
        
        // リアルタイムスレッドで動作するオーディオコールバック
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self, self.isPlaying else {
                // 非再生中は無音を出力
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in ablPointer {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }
            
            self.mutex.lock()
            defer { self.mutex.unlock() }
            
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
                    
                    // ビブレーションが有効ならメインスレッドで実行
                    if self.shouldVibrate {
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
            
            return noErr
        }
        
        schedulerNode = sourceNode
        
        // エンジンにノードを接続
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        
        // エンジンの開始
        do {
            try engine.start()
            NSLog("AVAudioEngine started successfully with real-time callback (iOS 13+ mode)")
        } catch {
            NSLog("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    // iOS 12以下用の初期化（従来の方法）
    private func initializeLegacyAudio() {
        // クリック波形からバッファを生成
        generateClickBuffer()
        
        // オーディオセッションを設定
        configureAudioSession()
        
        // AVAudioEngineの初期化
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let playerNode = audioPlayerNode, let buffer = clickBuffer else { return }
        
        // ノードを接続
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        
        // エンジンの開始
        do {
            try engine.start()
            NSLog("AVAudioEngine started successfully (iOS 12 compatibility mode)")
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
    
    private func generateClickBuffer() {
        let numSamples = Int(sampleRate * Double(clickDurationMs) / 1000.0)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(numSamples)) else {
            NSLog("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = buffer.frameCapacity
        
        // オーディオデータの生成
        let decay = exp(-5.0 / Double(numSamples))
        var currentAmplitude = amplitude
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let sample = sin(2.0 * .pi * frequency * t) * currentAmplitude
            
            // バッファにサンプルを書き込み
            buffer.floatChannelData?[0][i] = Float(sample)
            
            // 減衰を適用
            currentAmplitude *= decay
        }
        
        clickBuffer = buffer
        NSLog("Click buffer generated: \(numSamples) samples")
    }
    
    private func startMetronome(bpm: Double, vibrate: Bool) {
        mutex.lock()
        defer { mutex.unlock() }
        
        if isPlaying { return }
        
        currentBpm = bpm
        shouldVibrate = vibrate
        
        if usesModernAPI {
            startModernMetronome()
        } else {
            startLegacyMetronome()
        }
    }
    
    private func startModernMetronome() {
        // テンポからサンプル間隔を計算（高精度）
        let beatsPerSecond = currentBpm / 60.0
        beatIntervalSamples = engineSampleRate / beatsPerSecond
        
        // 最初の拍を即座に再生（現在のサンプル時間に設定）
        sampleTime = 0
        nextBeatSampleTime = 0
        
        isPlaying = true
        
        NSLog("Metronome started with high precision: \(currentBpm) BPM, interval: \(beatIntervalSamples) samples")
    }
    
    private func startLegacyMetronome() {
        // 従来のタイマー方式でメトロノームを開始
        lastBeatTime = CACurrentMediaTime()
        nextBeatTime = lastBeatTime
        
        // DisplayLinkを使用して高精度のタイミングで処理
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.preferredFramesPerSecond = 0 // デバイスの最大リフレッシュレート
        displayLink?.add(to: .current, forMode: .common)
        
        isPlaying = true
        playLegacyBeat() // 最初のビートを即座に再生
        
        NSLog("Metronome started with legacy mode: \(currentBpm) BPM")
    }
    
    private func stopMetronome() {
        mutex.lock()
        isPlaying = false
        mutex.unlock()
        
        if !usesModernAPI {
            displayLink?.invalidate()
            displayLink = nil
            audioPlayerNode?.stop()
        }
        
        NSLog("Metronome stopped")
    }
    
    private func setTempo(bpm: Double) {
        mutex.lock()
        currentBpm = bpm
        
        if usesModernAPI {
            // テンポからサンプル間隔を再計算
            let beatsPerSecond = bpm / 60.0
            beatIntervalSamples = engineSampleRate / beatsPerSecond
            
            if isPlaying {
                // 次の拍のタイミングを再設定
                nextBeatSampleTime = sampleTime + beatIntervalSamples
            }
            
            NSLog("Tempo changed with high precision: \(bpm) BPM, interval: \(beatIntervalSamples) samples")
        } else {
            if isPlaying {
                // 従来のタイマーモードでテンポ変更
                lastBeatTime = CACurrentMediaTime()
                nextBeatTime = lastBeatTime
            }
            
            NSLog("Tempo changed with legacy mode: \(bpm) BPM")
        }
        
        mutex.unlock()
    }
    
    @objc private func displayLinkTick() {
        guard isPlaying else { return }
        
        let now = CACurrentMediaTime()
        let intervalSec = 60.0 / currentBpm
        
        // 次の拍のタイミングをチェック
        if now >= nextBeatTime {
            // 拍を再生
            playLegacyBeat()
            
            // 次の拍のタイミングを計算（累積誤差を防ぐため）
            nextBeatTime = lastBeatTime + intervalSec * ceil((now - lastBeatTime) / intervalSec)
        }
    }
    
    private func playLegacyBeat() {
        // バイブレーション
        if shouldVibrate {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        // オーディオ再生
        guard let playerNode = audioPlayerNode, let buffer = clickBuffer else { return }
        
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        playerNode.play()
        
        // Flutterに通知
        let beatInfo: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "currentBpm": currentBpm
        ]
        channel.invokeMethod("onBeat", arguments: beatInfo)
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

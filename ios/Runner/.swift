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
    
    // 高精度タイマー関連
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var nextBeatTime: TimeInterval = 0
    private var lastBeatTime: TimeInterval = 0
    private var beatCount: Int = 0
    
    // メトロノーム音の生成用パラメータ
    private let clickDurationMs: Int = 25
    private let frequency: Double = 900.0 // Hz
    private let amplitude: Double = 0.8
    private let sampleRate: Double = 44100.0
    
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
        // AVAudioEngineの初期化
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        // クリック音を生成
        clickBuffer = generateClickBuffer()
        
        // ノードを接続
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: clickBuffer!.format)
        
        do {
            try engine.start()
            NSLog("AVAudioEngine started successfully")
        } catch {
            NSLog("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    private func startMetronome(bpm: Double, vibrate: Bool) {
        if isPlaying { return }
        
        currentBpm = bpm
        shouldVibrate = vibrate
        isPlaying = true
        beatCount = 0
        
        // AudioSessionを設定
        configureAudioSession()
        
        // 開始時刻を記録
        lastBeatTime = CACurrentMediaTime()
        nextBeatTime = lastBeatTime
        
        // CADisplayLinkを使用して高精度のタイミングで処理
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.preferredFramesPerSecond = 120 // 可能な限り高い更新頻度
        displayLink?.add(to: .current, forMode: .common)
        
        NSLog("Metronome started: \(currentBpm) BPM")
    }
    
    private func stopMetronome() {
        if !isPlaying { return }
        
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        
        NSLog("Metronome stopped")
    }
    
    private func setTempo(bpm: Double) {
        currentBpm = bpm
        // テンポ変更時の処理（特別な対応が必要なければ何もしない）
    }
    
    @objc private func displayLinkTick() {
        guard isPlaying else { return }
        
        let now = CACurrentMediaTime()
        let intervalSec = 60.0 / currentBpm
        
        // 次のビートの時間を計算（累積誤差を防ぐため、初期時刻からの計算）
        if now >= nextBeatTime {
            // ビートを再生
            playBeat()
            beatCount += 1
            
            // 次回のビート時刻を計算
            nextBeatTime = lastBeatTime + (Double(beatCount) * intervalSec)
            
            // Flutterに通知
            let beatInfo: [String: Any] = [
                "beatCount": beatCount,
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "currentBpm": currentBpm
            ]
            
            DispatchQueue.main.async {
                self.channel.invokeMethod("onBeat", arguments: beatInfo)
            }
        }
    }
    
    private func playBeat() {
        // バイブレーション
        if shouldVibrate {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        // オーディオ再生
        guard let playerNode = audioPlayerNode, let buffer = clickBuffer else { return }
        
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        // 可能な限り即座に再生を開始（レイテンシを最小化）
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        playerNode.play()
    }
    
    private func generateClickBuffer() -> AVAudioPCMBuffer? {
        let numSamples = Int(sampleRate * Double(clickDurationMs) / 1000.0)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
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
        
        return buffer
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            NSLog("Failed to configure audio session: \(error)")
        }
    }
    
    deinit {
        stopMetronome()
        audioEngine?.stop()
        audioPlayerNode?.stop()
    }
}

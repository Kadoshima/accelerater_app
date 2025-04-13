package com.example.flutter_ble_acc_example

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.*
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.math.PI
import kotlin.math.sin

class NativeMetronomePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var isPlaying = false
    private var currentBpm = 100.0
    private var shouldVibrate = true
    
    // オーディオ関連
    private var audioTrack: AudioTrack? = null
    private val sampleRate = 44100
    private val audioBufferSize = AudioTrack.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )
    
    // 高精度タイマー関連
    private val mainHandler = Handler(Looper.getMainLooper())
    private var nextBeatTime: Long = 0
    private var lastBeatTime: Long = 0
    private var beatCount = 0
    
    // メトロノーム音の生成用パラメータ
    private val clickDurationMs = 25
    private val frequency = 900.0 // Hz
    private val amplitude = 0.8
    
    // バイブレーター
    private var vibrator: Vibrator? = null
    
    // ビートスケジューラー
    private val beatScheduler = object : Runnable {
        override fun run() {
            if (!isPlaying) return
            
            val now = SystemClock.elapsedRealtime()
            val intervalMs = (60000.0 / currentBpm).toLong()
            
            // 次のビートの時間を計算（累積誤差を防ぐため、初期時刻からの計算）
            if (nextBeatTime <= now) {
                // ビートを再生
                playBeat()
                beatCount++
                
                // 次回のビート時刻を計算
                nextBeatTime = lastBeatTime + (beatCount * intervalMs)
                
                // Flutterに通知
                val beatInfo = HashMap<String, Any>()
                beatInfo["beatCount"] = beatCount
                beatInfo["timestamp"] = System.currentTimeMillis()
                beatInfo["currentBpm"] = currentBpm
                
                mainHandler.post {
                    channel.invokeMethod("onBeat", beatInfo)
                }
            }
            
            // 次の確認タイミングを計算（より精度高く）
            val timeUntilNextBeat = nextBeatTime - now
            val nextCheckTime = if (timeUntilNextBeat > 10) 5L else 1L
            
            // 次の確認をスケジュール
            mainHandler.postDelayed(this, nextCheckTime)
        }
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // チャンネルが既に初期化されていない場合のみ初期化
        if (!::channel.isInitialized) {
            channel = MethodChannel(binding.binaryMessenger, "com.example.native_metronome")
            channel.setMethodCallHandler(this)
        }
        
        Log.d("NativeMetronomePlugin", "Plugin attached to engine with context: $context")
        
        // バイブレーターの初期化
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        // 音声の初期化（必要に応じて）
        initializeAudio()
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseResources()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeAudio()
                result.success(true)
            }
            "start" -> {
                val bpm = call.argument<Double>("bpm") ?: 100.0
                val vibrate = call.argument<Boolean>("vibrate") ?: true
                startMetronome(bpm, vibrate)
                result.success(true)
            }
            "stop" -> {
                stopMetronome()
                result.success(true)
            }
            "setTempo" -> {
                val bpm = call.argument<Double>("bpm") ?: 100.0
                setTempo(bpm)
                result.success(true)
            }
            "setVibration" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                shouldVibrate = enabled
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun initializeAudio() {
        // AudioTrackの初期化
        if (audioTrack == null) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
                
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build())
                .setBufferSizeInBytes(audioBufferSize)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
                
            // クリック音を生成してロード
            val clickBuffer = generateClickWaveform()
            audioTrack?.write(clickBuffer, 0, clickBuffer.size)
        }
    }
    
    private fun startMetronome(bpm: Double, vibrate: Boolean) {
        if (isPlaying) return
        
        currentBpm = bpm
        shouldVibrate = vibrate
        isPlaying = true
        beatCount = 0
        
        // 開始時刻の記録
        lastBeatTime = SystemClock.elapsedRealtime()
        nextBeatTime = lastBeatTime
        
        // 高精度タイマーで処理開始
        mainHandler.post(beatScheduler)
    }
    
    private fun stopMetronome() {
        if (!isPlaying) return
        
        isPlaying = false
        mainHandler.removeCallbacks(beatScheduler)
        
        // 最後に再生位置をリセット
        audioTrack?.stop()
        audioTrack?.reloadStaticData()
    }
    
    private fun setTempo(bpm: Double) {
        currentBpm = bpm
        // テンポ変更時の処理（特別な対応が必要なければ何もしない）
    }
    
    private fun playBeat() {
        try {
            // バイブレーション
            if (shouldVibrate && vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(15)
                }
            }
            
            // オーディオ再生
            audioTrack?.let { track ->
                track.stop()
                track.reloadStaticData()
                track.play()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun generateClickWaveform(): ShortArray {
        val numSamples = sampleRate * clickDurationMs / 1000
        val buffer = ShortArray(numSamples)
        val decay = Math.exp(-5.0 / numSamples)
        var currentAmplitude = amplitude
        
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val sample = sin(2 * PI * frequency * t) * currentAmplitude
            buffer[i] = (sample * Short.MAX_VALUE).toInt().toShort()
            currentAmplitude *= decay
        }
        
        return buffer
    }
    
    private fun releaseResources() {
        isPlaying = false
        mainHandler.removeCallbacks(beatScheduler)
        
        audioTrack?.release()
        audioTrack = null
    }

    // 静的メソッドを追加（プラグイン登録用）
    companion object {
        @JvmStatic
        fun registerWith(messenger: BinaryMessenger) {
            try {
                val plugin = NativeMetronomePlugin()
                val channel = MethodChannel(messenger, "com.example.native_metronome")
                channel.setMethodCallHandler(plugin)
                plugin.channel = channel
                
                // コンテキストはFlutterPluginのライフサイクルメソッドで取得するため、ここでは設定しない
                // Contextは後でonAttachedToEngineで適切に設定されるので、ここではコンテキスト関連の初期化は行わない
                Log.d("NativeMetronomePlugin", "Plugin registered via messenger - waiting for context in onAttachedToEngine")
            } catch (e: Exception) {
                Log.e("NativeMetronomePlugin", "Failed to register plugin: ${e.message}")
                e.printStackTrace()
            }
        }
    }
} 
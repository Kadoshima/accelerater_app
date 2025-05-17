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
import kotlin.math.max

class NativeMetronomePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var isPlaying = false
    private var currentBpm = 100.0
    
    // オーディオ関連
    private var audioTrack: AudioTrack? = null
    private lateinit var clickBuffer: ShortArray
    private val sampleRate = 44100
    private val audioBufferSize = AudioTrack.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    // 高精度タイマー関連
    private val mainHandler = Handler(Looper.getMainLooper())
    private val schedulerThread = HandlerThread("MetronomeScheduler")
    private lateinit var schedulerHandler: Handler
    private var nextBeatTime: Long = 0
    private var lastBeatTime: Long = 0
    private var beatCount = 0
    
    // メトロノーム音の生成用パラメータ
    private val clickDurationMs = 25
    private val frequency = 900.0 // Hz
    private val amplitude = 0.8
    
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
            schedulerHandler.postDelayed(this, nextCheckTime)
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

        // スケジューラースレッドの初期化
        if (!schedulerThread.isAlive) {
            schedulerThread.start()
            schedulerHandler = Handler(schedulerThread.looper)
        }

        // 音声の初期化（必要に応じて）
        initializeAudio()
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseResources()
        schedulerThread.quitSafely()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeAudio()
                result.success(true)
            }
            "start" -> {
                val bpm = call.argument<Double>("bpm") ?: 100.0
                startMetronome(bpm)
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

            clickBuffer = generateClickWaveform()
            val bufferSize = max(audioBufferSize, clickBuffer.size * 2)

            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            audioTrack?.write(clickBuffer, 0, clickBuffer.size)
        } else {
            audioTrack?.stop()
            audioTrack?.setPlaybackHeadPosition(0)
        }
    }
    
    private fun startMetronome(bpm: Double) {
        if (isPlaying) return
        
        currentBpm = bpm
        isPlaying = true
        beatCount = 0
        
        // 開始時刻の記録
        lastBeatTime = SystemClock.elapsedRealtime()
        nextBeatTime = lastBeatTime
        
        // 高精度タイマーで処理開始
        schedulerHandler.post(beatScheduler)
    }

    private fun stopMetronome() {
        if (!isPlaying) return

        isPlaying = false
        schedulerHandler.removeCallbacks(beatScheduler)

        // 最後に再生位置をリセット
        audioTrack?.stop()
        audioTrack?.setPlaybackHeadPosition(0)
    }
    
    private fun setTempo(bpm: Double) {
        currentBpm = bpm
        // テンポ変更時の処理（特別な対応が必要なければ何もしない）
    }
    
    private fun playBeat() {
        try {
            // オーディオ再生
            audioTrack?.let { track ->
                track.stop()
                track.setPlaybackHeadPosition(0)
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
        schedulerHandler.removeCallbacks(beatScheduler)

        audioTrack?.release()
        audioTrack = null

        if (schedulerThread.isAlive) {
            schedulerThread.quitSafely()
        }
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
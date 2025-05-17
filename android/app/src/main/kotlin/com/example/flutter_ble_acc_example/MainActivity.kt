package com.example.flutter_ble_acc_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        // ネイティブメトロノームプラグインを登録
        // flutterEngine.plugins.add(NativeMetronomePlugin()) // この行は動作していない
        // 正しい登録方法に修正
        NativeMetronomePlugin.registerWith(flutterEngine.dartExecutor.binaryMessenger)
    }
} 
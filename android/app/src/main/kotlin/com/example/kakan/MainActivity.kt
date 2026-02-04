package com.example.kakan

import android.graphics.PixelFormat
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ⚙️ Fix Mali diagonal green glitch: force RGBA_8888 pixel format
        window.setFormat(PixelFormat.RGBA_8888)

        // ✅ Sanity check ExoPlayer creation (safe for all GPUs)
        try {
            val testPlayer = CustomExoPlayerFactory.create(this)
            testPlayer.release()
        } catch (_: Throwable) { }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativeVideoPlugin())
    }
}

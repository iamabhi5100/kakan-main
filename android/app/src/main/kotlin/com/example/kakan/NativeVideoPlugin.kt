package com.example.kakan

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeVideoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "native-video-view",
            NativeVideoViewFactory()
        )
        channel = MethodChannel(binding.binaryMessenger, "kakan/native_video")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: run {
            result.error("INVALID_ARGS", "Missing id", null)
            return
        }
        val view = NativeVideoRegistry.get(id)
        if (view == null) {
            result.error("NOT_FOUND", "No NativeVideoView with id=$id", null)
            return
        }
        when (call.method) {
            "play" -> {
                view.play()
                result.success(null)
            }
            "pause" -> {
                view.pause()
                result.success(null)
            }
            "seekTo" -> {
                val millis = call.argument<Number>("position")?.toLong() ?: 0L
                view.seekTo(millis)
                result.success(null)
            }
            "getPosition" -> {
                result.success(view.getPosition())
            }
            "getDuration" -> {
                result.success(view.getDuration())
            }
            else -> result.notImplemented()
        }
    }
}

package com.example.kakan

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.RenderersFactory

@UnstableApi
object CustomExoPlayerFactory {
    fun create(context: Context): ExoPlayer {
        val renderersFactory: RenderersFactory =
            DefaultRenderersFactory(context)
                .setEnableDecoderFallback(true)
                .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        return ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .build()
    }
}

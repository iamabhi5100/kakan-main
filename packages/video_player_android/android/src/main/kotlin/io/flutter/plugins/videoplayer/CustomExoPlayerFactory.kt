package io.flutter.plugins.videoplayer

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.RenderersFactory

/**
 * Creates ExoPlayer with a custom RenderersFactory to reduce green diagonal
 * glitch / pixelation on some Android devices (e.g. Mali GPUs).
 *
 * - Prefer extension (software) decoders when available to avoid HW decoder bugs.
 * - Decoder fallback enabled so a working decoder is used if the preferred one fails.
 */
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

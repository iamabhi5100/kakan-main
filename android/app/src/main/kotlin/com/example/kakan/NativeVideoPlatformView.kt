package com.example.kakan

import android.net.Uri
import android.util.Log
import android.view.SurfaceHolder
import android.view.View
import android.widget.FrameLayout
import android.view.SurfaceView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.platform.PlatformView
import java.io.File

/**
 * Native Android video view using Media3 ExoPlayer + SurfaceView (no PlayerView).
 * Avoids ClassCastException with video_player's exoplayer2.ui by not using media3-ui.
 * Supports more formats than VideoView and avoids Mali texture glitches.
 */
internal class NativeVideoPlatformView(
    private val context: android.content.Context,
    private val viewId: Int,
    private val creationParams: Map<String?, Any?>?,
) : PlatformView {

    companion object {
        private const val TAG = "NativeVideoView"
    }

    private val container = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }
    private val surfaceView = SurfaceView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }
    private var player: ExoPlayer? = null

    init {
        container.addView(surfaceView)
        val path = creationParams?.get("path") as? String
        val id = creationParams?.get("id") as? String ?: "default"
        NativeVideoRegistry.register(id, this)
        if (!path.isNullOrBlank()) {
            setupPlayer(path)
        } else {
            Log.w(TAG, "NativeVideoPlatformView: path is null or blank")
        }
    }

    private fun setupPlayer(path: String) {
        val file = File(path)
        val uri: Uri = if (file.exists()) {
            Uri.fromFile(file)
        } else {
            if (path.startsWith("/")) Uri.parse("file://${path.replace(" ", "%20")}") else Uri.parse(path)
        }

        val exoPlayer = ExoPlayer.Builder(context).build().apply {
            repeatMode = Player.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_READY -> Log.d(TAG, "ExoPlayer ready")
                        Player.STATE_ENDED -> Log.d(TAG, "ExoPlayer ended")
                        Player.STATE_IDLE, Player.STATE_BUFFERING -> { }
                    }
                }
                override fun onPlayerError(error: PlaybackException) {
                    Log.e(TAG, "ExoPlayer error: ${error.message}", error)
                }
            })
        }

        exoPlayer.setMediaItem(MediaItem.fromUri(uri))
        exoPlayer.prepare()

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                exoPlayer.setVideoSurface(holder.surface)
                exoPlayer.play()
            }
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                exoPlayer.clearVideoSurface(holder.surface)
            }
        })
        if (surfaceView.holder.surface?.isValid == true) {
            exoPlayer.setVideoSurface(surfaceView.holder.surface)
            exoPlayer.play()
        }

        player = exoPlayer
    }

    fun play() {
        player?.play()
    }

    fun pause() {
        player?.pause()
    }

    fun seekTo(millis: Long) {
        player?.seekTo(millis)
    }

    fun getPosition(): Long = player?.currentPosition ?: 0L

    fun getDuration(): Long {
        val d = player?.duration ?: return 0L
        return if (d >= 0) d else 0L
    }

    override fun getView(): View = container

    override fun dispose() {
        val id = creationParams?.get("id") as? String
        if (id != null) NativeVideoRegistry.unregister(id)
        player?.setVideoSurface(null)
        player?.release()
        player = null
        container.removeAllViews()
    }
}

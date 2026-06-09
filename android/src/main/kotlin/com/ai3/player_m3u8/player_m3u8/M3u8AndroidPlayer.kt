package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry

class M3u8AndroidPlayer(
    private val context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
) : TextureRegistry.SurfaceProducer.Callback, Player.Listener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var disposed = false
    private var savedState: SavedState? = null
    private var lastProgressSentAt = 0L
    private var initialized = false
    private val diskCachePrefetcher = M3u8DiskCachePrefetcher(
        context = context,
        url = url,
        headers = headers,
        playerIdProvider = { surfaceProducer.id() },
        eventSinkProvider = eventSinkProvider,
    )

    private val progressRunnable = object : Runnable {
        override fun run() {
            if (disposed) {
                return
            }
            sendProgress()
            mainHandler.postDelayed(this, PROGRESS_INTERVAL_MS)
        }
    }

    init {
        runOnMain {
            surfaceProducer.setCallback(this)
            createPlayer()
            diskCachePrefetcher.start()
            mainHandler.post(progressRunnable)
        }
    }

    fun play() {
        runOnMain {
            player?.playWhenReady = true
            sendPlaybackEvent("playing")
        }
    }

    fun pause() {
        runOnMain {
            player?.playWhenReady = false
            sendPlaybackEvent("paused")
        }
    }

    fun seekTo(positionMs: Long) {
        runOnMain {
            player?.seekTo(positionMs)
            sendProgress(force = true)
        }
    }

    fun dispose() {
        runOnMain {
            if (disposed) {
                return@runOnMain
            }
            disposed = true
            mainHandler.removeCallbacks(progressRunnable)
            diskCachePrefetcher.cancel()
            player?.removeListener(this)
            player?.release()
            player = null
            surfaceProducer.setCallback(null)
            surfaceProducer.release()
        }
    }

    override fun onSurfaceAvailable() {
        runOnMain {
            if (!disposed && player == null) {
                createPlayer(savedState)
                savedState = null
            } else {
                player?.setVideoSurface(surfaceProducer.getSurface())
            }
        }
    }

    override fun onSurfaceCleanup() {
        runOnMain {
            val currentPlayer = player ?: return@runOnMain
            savedState = SavedState(
                positionMs = currentPlayer.currentPosition.coerceAtLeast(0L),
                playWhenReady = currentPlayer.playWhenReady,
            )
            currentPlayer.removeListener(this)
            currentPlayer.release()
            player = null
            initialized = false
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING -> sendPlaybackEvent("buffering")
            Player.STATE_READY -> {
                if (!initialized) {
                    initialized = true
                    sendInitialized()
                }
                if (player?.playWhenReady == true) {
                    sendPlaybackEvent("playing")
                } else {
                    sendPlaybackEvent("paused")
                }
            }
            Player.STATE_ENDED -> sendPlaybackEvent("completed")
            Player.STATE_IDLE -> Unit
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        sendPlaybackEvent(if (isPlaying) "playing" else "paused")
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (initialized) {
            sendInitialized()
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        sendEvent(
            mapOf(
                "event" to "error",
                "error" to mapOf(
                    "code" to (error.errorCodeName ?: "playback_error"),
                    "message" to (error.message ?: "Playback failed."),
                    "details" to error.cause?.message,
                ),
            ),
        )
    }

    private fun createPlayer(state: SavedState? = null) {
        val mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMimeType(MimeTypes.APPLICATION_M3U8)
            .build()
        val mediaSourceFactory = DefaultMediaSourceFactory(
            M3u8CacheManager.mediaDataSourceFactory(context, headers),
        )
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                MIN_BUFFER_MS,
                MAX_BUFFER_MS,
                BUFFER_FOR_PLAYBACK_MS,
                BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
            )
            .build()
        val newPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
            .build()
        newPlayer.addListener(this)
        newPlayer.setMediaItem(mediaItem)
        newPlayer.setVideoSurface(surfaceProducer.getSurface())
        if (state != null) {
            newPlayer.seekTo(state.positionMs)
            newPlayer.playWhenReady = state.playWhenReady
        }
        newPlayer.prepare()
        player = newPlayer
    }

    private fun sendInitialized() {
        val currentPlayer = player ?: return
        val videoSize = currentPlayer.videoSize
        var width = videoSize.width
        var height = videoSize.height
        if (
            videoSize.unappliedRotationDegrees == 90 ||
                videoSize.unappliedRotationDegrees == 270
        ) {
            width = videoSize.height
            height = videoSize.width
        }
        sendEvent(
            playbackPayload("initialized") + mapOf(
                "width" to width,
                "height" to height,
            ),
        )
    }

    private fun sendPlaybackEvent(event: String) {
        sendEvent(playbackPayload(event))
    }

    private fun sendProgress(force: Boolean = false) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (!force && now - lastProgressSentAt < PROGRESS_INTERVAL_MS - 20L) {
            return
        }
        lastProgressSentAt = now
        sendEvent(playbackPayload("progress"))
    }

    private fun playbackPayload(event: String): Map<String, Any> {
        val currentPlayer = player
        val duration = currentPlayer?.duration?.takeIf { it >= 0L } ?: 0L
        return mapOf(
            "event" to event,
            "position" to (currentPlayer?.currentPosition?.coerceAtLeast(0L) ?: 0L),
            "duration" to duration,
            "bufferedPosition" to (currentPlayer?.bufferedPosition?.coerceAtLeast(0L) ?: 0L),
        )
    }

    private fun sendEvent(payload: Map<String, Any?>) {
        val event = HashMap<String, Any?>()
        event["playerId"] = surfaceProducer.id()
        event.putAll(payload)
        mainHandler.post {
            if (!disposed) {
                eventSinkProvider()?.success(event)
            }
        }
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    private data class SavedState(
        val positionMs: Long,
        val playWhenReady: Boolean,
    )

    private companion object {
        const val PROGRESS_INTERVAL_MS = 250L
        const val MIN_BUFFER_MS = 15_000
        const val MAX_BUFFER_MS = 50_000
        const val BUFFER_FOR_PLAYBACK_MS = 2_500
        const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5_000
    }
}

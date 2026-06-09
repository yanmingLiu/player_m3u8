package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
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
    private val sourceDebugId = M3u8Log.sourceDebugId(url)
    private val videoTrackCompatLimit = videoTrackCompatLimit()
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
            logInfo(
                "init playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                    "headerCount=${headers.size} decoderFallback=true " +
                    "trackCompat=${videoTrackCompatLimit?.name ?: "none"} " +
                    "device=${Build.MANUFACTURER}/${Build.MODEL} sdk=${Build.VERSION.SDK_INT}",
            )
            surfaceProducer.setCallback(this)
            createPlayer()
            diskCachePrefetcher.start()
            mainHandler.post(progressRunnable)
        }
    }

    fun play() {
        runOnMain {
            logInfo("play playerId=${surfaceProducer.id()} source=$sourceDebugId")
            player?.playWhenReady = true
            sendPlaybackEvent("playing")
        }
    }

    fun pause() {
        runOnMain {
            logInfo("pause playerId=${surfaceProducer.id()} source=$sourceDebugId")
            player?.playWhenReady = false
            sendPlaybackEvent("paused")
        }
    }

    fun seekTo(positionMs: Long) {
        runOnMain {
            logInfo(
                "seek playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                    "positionMs=${positionMs.coerceAtLeast(0L)}",
            )
            player?.seekTo(positionMs)
            diskCachePrefetcher.restartFrom(positionMs)
            sendProgress(force = true)
        }
    }

    fun dispose() {
        runOnMain {
            if (disposed) {
                return@runOnMain
            }
            logInfo("dispose playerId=${surfaceProducer.id()} source=$sourceDebugId")
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
            logInfo(
                "surfaceAvailable playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                    "recreate=${!disposed && player == null}",
            )
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
            logInfo(
                "surfaceCleanup playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                    "positionMs=${currentPlayer.currentPosition.coerceAtLeast(0L)} " +
                    "playWhenReady=${currentPlayer.playWhenReady}",
            )
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
        logInfo(
            "state playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "state=${playbackState.name()} positionMs=${player?.currentPosition?.coerceAtLeast(0L) ?: 0L} " +
                "durationMs=${player?.duration?.takeIf { it >= 0L } ?: 0L} " +
                "bufferedMs=${player?.bufferedPosition?.coerceAtLeast(0L) ?: 0L} " +
                "playWhenReady=${player?.playWhenReady}",
        )
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
        logInfo(
            "isPlaying playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "value=$isPlaying positionMs=${player?.currentPosition?.coerceAtLeast(0L) ?: 0L}",
        )
        sendPlaybackEvent(if (isPlaying) "playing" else "paused")
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        logInfo(
            "videoSize playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "width=${videoSize.width} height=${videoSize.height} " +
                "rotation=${videoSize.unappliedRotationDegrees}",
        )
        if (initialized) {
            sendInitialized()
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        val details = playbackErrorDetails(error)
        logPlayerError(error, details)
        sendEvent(
            mapOf(
                "event" to "error",
                "error" to playbackErrorPayload(error, details),
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
        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
        val trackSelector = DefaultTrackSelector(context)
        videoTrackCompatLimit?.let { limit ->
            trackSelector.setParameters(
                trackSelector.buildUponParameters()
                    .setMaxVideoSize(limit.maxWidth, limit.maxHeight)
                    .setExceedVideoConstraintsIfNecessary(true),
            )
        }
        logInfo(
            "createPlayer playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "restore=${state != null} restorePositionMs=${state?.positionMs ?: 0L} " +
                "restorePlayWhenReady=${state?.playWhenReady} decoderFallback=true " +
                "trackCompat=${videoTrackCompatLimit?.description() ?: "none"} " +
                "bufferMs=$MIN_BUFFER_MS-$MAX_BUFFER_MS",
        )
        val newPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
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
        logInfo("prepare playerId=${surfaceProducer.id()} source=$sourceDebugId")
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

    private fun playbackErrorPayload(
        error: PlaybackException,
        details: Map<String, Any?>,
    ): Map<String, Any?> {
        return mapOf(
            "code" to error.errorCodeName,
            "message" to (error.message ?: "Playback failed."),
            "details" to details,
        )
    }

    private fun playbackErrorDetails(error: PlaybackException): Map<String, Any?> {
        val details = linkedMapOf<String, Any?>(
            "platform" to "android",
            "type" to playbackErrorType(error),
            "errorCode" to error.errorCode,
            "errorCodeName" to error.errorCodeName,
            "device" to mapOf(
                "manufacturer" to Build.MANUFACTURER,
                "brand" to Build.BRAND,
                "model" to Build.MODEL,
                "device" to Build.DEVICE,
                "product" to Build.PRODUCT,
                "sdkInt" to Build.VERSION.SDK_INT,
            ),
            "trackCompat" to videoTrackCompatLimit?.description(),
            "cause" to error.cause?.javaClass?.name,
            "causeMessage" to error.cause?.message,
        )
        if (error is ExoPlaybackException) {
            details["rendererName"] = error.rendererName
            details["rendererIndex"] = error.rendererIndex
            details["rendererFormat"] = error.rendererFormat?.toString()
            details["rendererFormatSupport"] = error.rendererFormatSupport
        }
        return details
    }

    private fun playbackErrorType(error: PlaybackException): String {
        return when ((error as? ExoPlaybackException)?.type) {
            ExoPlaybackException.TYPE_SOURCE -> "source"
            ExoPlaybackException.TYPE_RENDERER -> "renderer"
            ExoPlaybackException.TYPE_UNEXPECTED -> "unexpected"
            ExoPlaybackException.TYPE_REMOTE -> "remote"
            else -> "playback"
        }
    }

    private fun logPlayerError(error: PlaybackException, details: Map<String, Any?>) {
        M3u8Log.error(
            "error playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "type=${details["type"]} code=${details["errorCodeName"]} " +
                "message=${error.message} cause=${details["cause"]} " +
                "causeMessage=${details["causeMessage"]} " +
                "rendererName=${details["rendererName"]} " +
                "rendererIndex=${details["rendererIndex"]} " +
                "rendererFormat=${details["rendererFormat"]} " +
                "trackCompat=${details["trackCompat"]} " +
                "device=${Build.MANUFACTURER}/${Build.MODEL} sdk=${Build.VERSION.SDK_INT}",
            error,
        )
    }

    private fun logInfo(message: String) {
        M3u8Log.info(message)
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

    private fun Int.name(): String {
        return when (this) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> "ready"
            Player.STATE_ENDED -> "ended"
            else -> "unknown:$this"
        }
    }

    private fun videoTrackCompatLimit(): VideoTrackCompatLimit? {
        if (!isHuaweiP30Android9()) {
            return null
        }
        return VideoTrackCompatLimit(
            name = "huawei_p30_android9_720p",
            maxWidth = 1280,
            maxHeight = 720,
        )
    }

    private fun isHuaweiP30Android9(): Boolean {
        if (
            !Build.MANUFACTURER.equals("HUAWEI", ignoreCase = true) ||
                Build.VERSION.SDK_INT != Build.VERSION_CODES.P
        ) {
            return false
        }
        val deviceName = listOf(Build.MODEL, Build.DEVICE, Build.PRODUCT)
            .joinToString(separator = " ")
            .uppercase()
        return deviceName.contains("P30") ||
            deviceName.contains("ELE-") ||
            deviceName.contains("HWELE")
    }

    private data class VideoTrackCompatLimit(
        val name: String,
        val maxWidth: Int,
        val maxHeight: Int,
    ) {
        fun description(): String {
            return "$name:${maxWidth}x$maxHeight"
        }
    }

    private companion object {
        const val PROGRESS_INTERVAL_MS = 250L
        const val MIN_BUFFER_MS = 15_000
        const val MAX_BUFFER_MS = 50_000
        const val BUFFER_FOR_PLAYBACK_MS = 2_500
        const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5_000
    }
}

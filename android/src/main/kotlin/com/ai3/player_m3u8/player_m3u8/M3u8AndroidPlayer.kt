package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.ParsingLoadable
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry

class M3u8AndroidPlayer(
    private val context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    sourceType: M3u8SourceType,
    private val initialPositionMs: Long,
    private var playbackSpeed: Float,
    private var volume: Float,
    private var isMuted: Boolean,
    recoveryPolicy: M3u8RecoveryPolicy,
    private val surfaceProducer: TextureRegistry.SurfaceProducer,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
) : TextureRegistry.SurfaceProducer.Callback, Player.Listener, AnalyticsListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var disposed = false
    private var savedState: SavedState? = null
    private var lastProgressSentAt = 0L
    private var initialized = false
    private val createdAtMs = android.os.SystemClock.elapsedRealtime()
    private var startupTimeMs = 0L
    private var rebufferCount = 0
    private var rebufferDurationMs = 0L
    private var rebufferStartedAtMs = 0L
    private var droppedFrames = 0
    private var videoBitrate = 0
    private var observedBitrate = 0
    private var qualitySwitchCount = 0
    private var wasPlayingBeforeBuffering = false
    private var availableQualities = listOf<Map<String, Any?>>()
    private var selectedQuality = autoQuality()
    private var recoveryPolicy = recoveryPolicy.normalized()
    private val resolvedSourceType = sourceType.resolve(url)
    private val isHlsSource = resolvedSourceType == M3u8SourceType.HLS
    private var recoveryCount = 0
    private var lastRecoveryReason = ""
    private var lastRecoveredRebufferCount = 0
    private var lastRecoveryAtMs = 0L
    private val sourceDebugId = M3u8Log.sourceDebugId(url)
    private val videoTrackCompatLimit = videoTrackCompatLimit()
    private val diskCachePrefetcher = if (isHlsSource) {
        M3u8DiskCachePrefetcher(
            context = context,
            url = url,
            headers = headers,
            playerIdProvider = { surfaceProducer.id() },
            eventSinkProvider = eventSinkProvider,
            qualityProvider = { selectedQuality },
        )
    } else {
        null
    }

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
                    "sourceType=$resolvedSourceType headerCount=${headers.size} decoderFallback=true " +
                    "trackCompat=${videoTrackCompatLimit?.name ?: "none"} " +
                    "device=${Build.MANUFACTURER}/${Build.MODEL} sdk=${Build.VERSION.SDK_INT}",
            )
            surfaceProducer.setCallback(this)
            if (isHlsSource) {
                loadAvailableQualities()
            } else {
                availableQualities = emptyList()
            }
            createPlayer()
            diskCachePrefetcher?.restartFrom(initialPositionMs)
            mainHandler.post(progressRunnable)
        }
    }

    fun play() {
        runOnMain {
            logInfo("play playerId=${surfaceProducer.id()} source=$sourceDebugId")
            player?.playbackParameters = PlaybackParameters(playbackSpeed)
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
            diskCachePrefetcher?.restartFrom(positionMs)
            sendProgress(force = true)
        }
    }

    fun setQuality(quality: Map<String, Any?>): Boolean {
        if (!isHlsSource) {
            return false
        }
        runOnMain {
            val isAuto = quality["isAuto"] as? Boolean ?: false
            selectedQuality = if (isAuto) {
                autoQuality()
            } else {
                qualityPayload(
                    width = (quality["width"] as? Number)?.toInt() ?: 0,
                    height = (quality["height"] as? Number)?.toInt() ?: 0,
                    bitrate = (quality["bitrate"] as? Number)?.toInt() ?: 0,
                )
            }
            qualitySwitchCount += 1
            applySelectedQuality()
            diskCachePrefetcher?.restartFrom(player?.currentPosition?.coerceAtLeast(0L) ?: 0L)
            sendProgress(force = true)
        }
        return true
    }

    fun setRecoveryPolicy(policy: M3u8RecoveryPolicy) {
        runOnMain {
            recoveryPolicy = policy.normalized()
            sendProgress(force = true)
        }
    }

    fun setPlaybackSpeed(speed: Float) {
        runOnMain {
            playbackSpeed = speed.coerceIn(0.25f, 2.0f)
            player?.playbackParameters = PlaybackParameters(playbackSpeed)
            sendProgress(force = true)
        }
    }

    fun setVolume(volume: Float) {
        runOnMain {
            this.volume = volume.coerceIn(0f, 1f)
            applyVolume()
            sendProgress(force = true)
        }
    }

    fun setMuted(isMuted: Boolean) {
        runOnMain {
            this.isMuted = isMuted
            applyVolume()
            sendProgress(force = true)
        }
    }

    private fun applyVolume() {
        player?.volume = effectiveVolume()
    }

    private fun effectiveVolume(): Float {
        return if (isMuted) 0f else volume
    }

    fun dispose() {
        runOnMain {
            if (disposed) {
                return@runOnMain
            }
            logInfo("dispose playerId=${surfaceProducer.id()} source=$sourceDebugId")
            disposed = true
            mainHandler.removeCallbacks(progressRunnable)
            diskCachePrefetcher?.cancel()
            player?.removeListener(this)
            player?.removeAnalyticsListener(this)
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
            currentPlayer.removeAnalyticsListener(this)
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
            Player.STATE_BUFFERING -> {
                if (initialized && wasPlayingBeforeBuffering) {
                    rebufferCount += 1
                    if (rebufferStartedAtMs == 0L) {
                        rebufferStartedAtMs = android.os.SystemClock.elapsedRealtime()
                    }
                    if (
                        recoveryPolicy.isEnabled &&
                        rebufferCount - lastRecoveredRebufferCount >= recoveryPolicy.rebufferThreshold
                    ) {
                        attemptRecovery("rebuffer")
                    }
                }
                sendPlaybackEvent("buffering")
            }
            Player.STATE_READY -> {
                finishRebufferTiming()
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
            Player.STATE_ENDED -> {
                finishRebufferTiming()
                sendPlaybackEvent("completed")
            }
            Player.STATE_IDLE -> finishRebufferTiming()
        }
        wasPlayingBeforeBuffering = player?.isPlaying == true ||
            (playbackState == Player.STATE_READY && player?.playWhenReady == true)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        logInfo(
            "isPlaying playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "value=$isPlaying positionMs=${player?.currentPosition?.coerceAtLeast(0L) ?: 0L}",
        )
        sendPlaybackEvent(if (isPlaying) "playing" else "paused")
    }

    override fun onTracksChanged(tracks: Tracks) {
        videoBitrate = tracks.groups
            .flatMap { group ->
                (0 until group.length)
                    .filter { group.isTrackSelected(it) }
                    .map { group.getTrackFormat(it) }
            }
            .firstOrNull { format ->
                format.sampleMimeType?.startsWith("video/") == true ||
                    format.width > 0 ||
                    format.height > 0
            }
            ?.bitrate
            ?.takeIf { it > 0 }
            ?: videoBitrate
        sendProgress(force = true)
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
        finishRebufferTiming()
        if (attemptRecovery("error:${error.errorCodeName}")) {
            return
        }
        sendEvent(
            mapOf(
                "event" to "error",
                "error" to playbackErrorPayload(error, details),
            ),
        )
    }

    override fun onRenderedFirstFrame(
        eventTime: AnalyticsListener.EventTime,
        output: Any,
        renderTimeMs: Long,
    ) {
        if (startupTimeMs == 0L) {
            startupTimeMs = (android.os.SystemClock.elapsedRealtime() - createdAtMs)
                .coerceAtLeast(0L)
            sendProgress(force = true)
        }
    }

    override fun onDroppedVideoFrames(
        eventTime: AnalyticsListener.EventTime,
        droppedFrames: Int,
        elapsedMs: Long,
    ) {
        this.droppedFrames += droppedFrames.coerceAtLeast(0)
        sendProgress(force = true)
    }

    override fun onBandwidthEstimate(
        eventTime: AnalyticsListener.EventTime,
        totalLoadTimeMs: Int,
        totalBytesLoaded: Long,
        bitrateEstimate: Long,
    ) {
        observedBitrate = bitrateEstimate
            .coerceAtMost(Int.MAX_VALUE.toLong())
            .toInt()
            .coerceAtLeast(0)
    }

    private fun createPlayer(state: SavedState? = null) {
        val mediaItemBuilder = MediaItem.Builder().setUri(url)
        if (isHlsSource) {
            mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
        }
        val mediaItem = mediaItemBuilder.build()
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
        this.trackSelector = trackSelector
        applySelectedQuality(trackSelector)
        logInfo(
            "createPlayer playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "sourceType=$resolvedSourceType initialPositionMs=$initialPositionMs restore=${state != null} " +
                "restorePositionMs=${state?.positionMs ?: 0L} " +
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
        newPlayer.addAnalyticsListener(this)
        newPlayer.playbackParameters = PlaybackParameters(playbackSpeed)
        newPlayer.volume = effectiveVolume()
        if (state == null && initialPositionMs > 0L) {
            newPlayer.setMediaItem(mediaItem, initialPositionMs)
        } else {
            newPlayer.setMediaItem(mediaItem)
        }
        newPlayer.setVideoSurface(surfaceProducer.getSurface())
        if (state != null) {
            newPlayer.seekTo(state.positionMs)
            newPlayer.playWhenReady = state.playWhenReady
        }
        newPlayer.prepare()
        player = newPlayer
        logInfo("prepare playerId=${surfaceProducer.id()} source=$sourceDebugId")
    }

    private fun loadAvailableQualities() {
        if (!isHlsSource) {
            availableQualities = emptyList()
            return
        }
        try {
            val dataSource = M3u8CacheManager.mediaDataSourceFactory(context, headers)
                .createDataSource()
            val playlist = ParsingLoadable.load(
                dataSource,
                HlsPlaylistParser(),
                Uri.parse(url),
                C.DATA_TYPE_MANIFEST,
            )
            availableQualities = when (playlist) {
                is HlsMultivariantPlaylist -> playlist.variants
                    .map { it.format }
                    .filter { format ->
                        format.height > 0 || format.width > 0 || format.bitrate > 0
                    }
                    .map { format ->
                        qualityPayload(
                            width = format.width.coerceAtLeast(0),
                            height = format.height.coerceAtLeast(0),
                            bitrate = format.bitrate.coerceAtLeast(0),
                        )
                    }
                    .distinctBy { it["id"] }
                    .sortedWith(
                        compareByDescending<Map<String, Any?>> {
                            it["height"] as? Int ?: 0
                        }.thenByDescending {
                            it["bitrate"] as? Int ?: 0
                        },
                    )
                else -> emptyList()
            }
        } catch (_: Throwable) {
            availableQualities = emptyList()
        }
    }

    private fun applySelectedQuality(selector: DefaultTrackSelector? = trackSelector) {
        val currentSelector = selector ?: return
        val builder = currentSelector.buildUponParameters()
        val isAuto = selectedQuality["isAuto"] == true
        val selectedWidth = if (isAuto) {
            0
        } else {
            selectedQuality["width"] as? Int ?: 0
        }
        val selectedHeight = if (isAuto) {
            0
        } else {
            selectedQuality["height"] as? Int ?: 0
        }
        val limit = videoTrackCompatLimit
        val constrainedWidth = constrainedDimension(selectedWidth, limit?.maxWidth)
        val constrainedHeight = constrainedDimension(selectedHeight, limit?.maxHeight)
        builder.clearVideoSizeConstraints()
        builder.clearViewportSizeConstraints()
        if (constrainedWidth > 0 && constrainedHeight > 0) {
            builder.setMaxVideoSize(constrainedWidth, constrainedHeight)
            builder.setExceedVideoConstraintsIfNecessary(true)
        }
        val bitrate = if (isAuto) {
            Int.MAX_VALUE
        } else {
            selectedQuality["bitrate"] as? Int ?: 0
        }
        builder.setMaxVideoBitrate(if (bitrate > 0) bitrate else Int.MAX_VALUE)
        currentSelector.setParameters(builder)
    }

    private fun constrainedDimension(selected: Int, compatLimit: Int?): Int {
        return when {
            selected > 0 && compatLimit != null -> minOf(selected, compatLimit)
            selected > 0 -> selected
            compatLimit != null -> compatLimit
            else -> 0
        }
    }

    private fun attemptRecovery(reason: String): Boolean {
        if (!recoveryPolicy.isEnabled) {
            return false
        }
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecoveryAtMs < recoveryPolicy.minimumRecoveryIntervalMs) {
            return false
        }
        val lowerQuality = nextLowerQuality() ?: return false
        val currentPlayer = player ?: return false
        val positionMs = currentPlayer.currentPosition.coerceAtLeast(0L)
        val shouldPlay = currentPlayer.playWhenReady
        recoveryCount += 1
        lastRecoveryReason = reason
        lastRecoveredRebufferCount = rebufferCount
        lastRecoveryAtMs = now
        selectedQuality = lowerQuality
        qualitySwitchCount += 1
        logInfo(
            "recover playerId=${surfaceProducer.id()} source=$sourceDebugId " +
                "reason=$reason quality=${lowerQuality["id"]} positionMs=$positionMs",
        )
        applySelectedQuality()
        currentPlayer.seekTo(positionMs)
        diskCachePrefetcher?.restartFrom(positionMs)
        if (currentPlayer.playbackState == Player.STATE_IDLE) {
            currentPlayer.prepare()
        }
        currentPlayer.playWhenReady = shouldPlay
        sendProgress(force = true)
        return true
    }

    private fun nextLowerQuality(): Map<String, Any?>? {
        if (availableQualities.isEmpty()) {
            return null
        }
        val isAuto = selectedQuality["isAuto"] == true
        val currentHeight = if (isAuto) {
            player?.videoSize?.height?.takeIf { it > 0 } ?: Int.MAX_VALUE
        } else {
            selectedQuality["height"] as? Int ?: Int.MAX_VALUE
        }
        val currentBitrate = if (isAuto) {
            videoBitrate.takeIf { it > 0 } ?: Int.MAX_VALUE
        } else {
            selectedQuality["bitrate"] as? Int ?: Int.MAX_VALUE
        }
        return availableQualities
            .filter { quality ->
                val height = quality["height"] as? Int ?: 0
                val bitrate = quality["bitrate"] as? Int ?: 0
                (height > 0 || bitrate > 0) && (
                    isAuto ||
                        height < currentHeight ||
                        (height == currentHeight && bitrate < currentBitrate)
                    ) &&
                    (recoveryPolicy.minimumAutoQualityHeight <= 0 ||
                        height <= 0 ||
                        height >= recoveryPolicy.minimumAutoQualityHeight)
            }
            .maxWithOrNull(
                compareBy<Map<String, Any?>> {
                    it["height"] as? Int ?: 0
                }.thenBy {
                    it["bitrate"] as? Int ?: 0
                },
            )
    }

    private fun autoQuality(): Map<String, Any?> {
        return mapOf(
            "id" to "auto",
            "label" to "Auto",
            "width" to 0,
            "height" to 0,
            "bitrate" to 0,
            "isAuto" to true,
        )
    }

    private fun qualityPayload(width: Int, height: Int, bitrate: Int): Map<String, Any?> {
        val label = when {
            height > 0 -> "${height}p"
            bitrate > 0 -> "${bitrate / 1000} Kbps"
            else -> "Unknown"
        }
        val id = when {
            height > 0 -> "${height}p"
            bitrate > 0 -> "${bitrate}bps"
            else -> "unknown"
        }
        return mapOf(
            "id" to id,
            "label" to label,
            "width" to width,
            "height" to height,
            "bitrate" to bitrate,
            "isAuto" to false,
        )
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
            "startupTime" to startupTimeMs,
            "rebufferCount" to rebufferCount,
            "rebufferDuration" to currentRebufferDurationMs(),
            "droppedFrames" to droppedFrames,
            "videoBitrate" to videoBitrate,
            "observedBitrate" to observedBitrate,
            "qualitySwitchCount" to qualitySwitchCount,
            "availableQualities" to availableQualities,
            "selectedQuality" to selectedQuality,
            "playbackSpeed" to playbackSpeed.toDouble(),
            "volume" to volume.toDouble(),
            "isMuted" to isMuted,
            "recoveryCount" to recoveryCount,
            "lastRecoveryReason" to lastRecoveryReason,
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

    private fun finishRebufferTiming() {
        val startedAtMs = rebufferStartedAtMs
        if (startedAtMs == 0L) {
            return
        }
        rebufferDurationMs += (android.os.SystemClock.elapsedRealtime() - startedAtMs)
            .coerceAtLeast(0L)
        rebufferStartedAtMs = 0L
    }

    private fun currentRebufferDurationMs(): Long {
        val startedAtMs = rebufferStartedAtMs
        if (startedAtMs == 0L) {
            return rebufferDurationMs
        }
        return rebufferDurationMs +
            (android.os.SystemClock.elapsedRealtime() - startedAtMs).coerceAtLeast(0L)
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

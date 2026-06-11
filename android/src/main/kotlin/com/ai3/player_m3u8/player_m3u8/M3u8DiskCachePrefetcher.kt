package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.C
import androidx.media3.common.util.UriUtil
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.CacheWriter
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser
import androidx.media3.exoplayer.upstream.ParsingLoadable
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

internal class M3u8DiskCachePrefetcher(
    context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    private val cacheKey: String? = null,
    private val playerIdProvider: () -> Long,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
    override val taskId: String? = null,
    private val owner: String = if (taskId == null) "player" else "standalone",
    private val sourceType: M3u8SourceType = M3u8SourceType.HLS,
    override val priority: Int = 0,
    private val maxRetries: Int = 2,
    private val metadata: Map<String, Any?> = emptyMap(),
    private val onFinished: (() -> Unit)? = null,
    private val qualityProvider: () -> Map<String, Any?> = { autoQuality() },
    private val audioUrl: String? = null,
    private val audioHeaders: Map<String, String>? = null,
) : M3u8CacheTaskHandle {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sourceDebugId = M3u8Log.sourceDebugId(url)
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "player_m3u8_hls_prefetch").apply { isDaemon = true }
    }
    private val generation = AtomicInteger(0)

    @Volatile
    private var cancelled = false

    @Volatile
    private var status = "queued"

    @Volatile
    private var currentWriter: CacheWriter? = null

    @Volatile
    private var playlist: Playlist? = null

    @Volatile
    private var playlistQualityKey: String? = null

    private var lastProgressSentAt = 0L
    private var bytesCached = 0L
    private var bytesTotal = 0L
    private var cacheHitCount = 0
    private var networkFetchCount = 0
    private var retryCount = 0
    private var currentUrl: String? = null
    private var segmentIndex = 0
    private var segmentCount = 0
    private var lastBytesSample = 0L
    private var lastBytesSampleAt = SystemClock.elapsedRealtime()
    private var downloadSpeedBytesPerSecond = 0L
    private var nextStartPositionMs = 0L

    override val isRunning: Boolean
        get() = status == "running"

    override val isQueued: Boolean
        get() = status == "queued"

    override val isPaused: Boolean
        get() = status == "paused"

    override fun start() {
        restartFrom(positionMs = nextStartPositionMs)
    }

    override fun restartFrom(positionMs: Long) {
        if (cancelled) {
            return
        }
        status = "running"
        val taskGeneration = generation.incrementAndGet()
        currentWriter?.cancel()
        executor.execute {
            cacheVod(startPositionMs = positionMs.coerceAtLeast(0L), taskGeneration)
        }
    }

    override fun markQueued(positionMs: Long?) {
        if (cancelled) {
            return
        }
        if (positionMs != null) {
            nextStartPositionMs = positionMs.coerceAtLeast(0L)
        }
        status = "queued"
        sendDiskCacheProgress(
            diskCacheStartMs = 0L,
            diskCachePositionMs = nextStartPositionMs,
            durationMs = 0L,
            isComplete = false,
            force = true,
            taskGeneration = generation.get(),
            quality = normalizedQuality(qualityProvider()),
        )
    }

    override fun pause() {
        if (cancelled) {
            return
        }
        status = "paused"
        generation.incrementAndGet()
        currentWriter?.cancel()
        sendStatusEvent("progress")
    }

    override fun resume() {
        restartFrom(nextStartPositionMs)
    }

    override fun cancel() {
        cancelled = true
        status = "cancelled"
        generation.incrementAndGet()
        currentWriter?.cancel()
        executor.shutdownNow()
        sendStatusEvent("cancelled")
    }

    override fun snapshot(): Map<String, Any?> {
        return baseEvent(
            eventName = if (status == "completed") "completed" else "progress",
            diskCacheStartMs = 0L,
            diskCachePositionMs = 0L,
            durationMs = 0L,
            percent = 0.0,
            isComplete = status == "completed",
            quality = normalizedQuality(qualityProvider()),
        )
    }

    private fun cacheVod(startPositionMs: Long, taskGeneration: Int) {
        try {
            val selectedQuality = normalizedQuality(qualityProvider())
            val selectedQualityKey = qualityKey(selectedQuality)
            val currentPlaylist = if (playlist != null && playlistQualityKey == selectedQualityKey) {
                playlist!!
            } else {
                loadPlaylist(selectedQuality).also {
                    playlist = it
                    playlistQualityKey = selectedQualityKey
                }
            }
            if (!isCurrent(taskGeneration)) {
                return
            }
            if (currentPlaylist.segments.isEmpty() || currentPlaylist.durationMs <= 0L) {
                sendCacheError(
                    IllegalStateException("No cacheable HLS segments found."),
                    taskGeneration,
                )
                notifyFinished(taskGeneration)
                return
            }

            val startIndex = currentPlaylist.segmentIndexFor(startPositionMs)
            val orderedSegments = currentPlaylist.segments.drop(startIndex) +
                currentPlaylist.segments.take(startIndex)
            val diskCacheStartMs = currentPlaylist.segments[startIndex].startTimeMs
            var diskCachePositionMs = diskCacheStartMs
            nextStartPositionMs = diskCacheStartMs
            segmentCount = currentPlaylist.segments.size
            segmentIndex = startIndex
            bytesTotal = currentPlaylist.segments.size.toLong()
            sendDiskCacheProgress(
                diskCacheStartMs = diskCacheStartMs,
                diskCachePositionMs = diskCachePositionMs,
                durationMs = currentPlaylist.durationMs,
                isComplete = false,
                force = true,
                taskGeneration = taskGeneration,
                quality = currentPlaylist.quality,
            )

            for (resource in currentPlaylist.resources) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                cacheUriWithRetry(resource, taskGeneration, headers)
            }

            for (segment in orderedSegments) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                currentUrl = segment.uri.toString()
                segmentIndex = currentPlaylist.segments.indexOf(segment).coerceAtLeast(0)
                nextStartPositionMs = segment.startTimeMs
                cacheUriWithRetry(segment.uri, taskGeneration, headers)
                bytesCached = (bytesCached + 1L).coerceAtMost(bytesTotal.coerceAtLeast(bytesCached + 1L))
                if (segment.startTimeMs >= diskCacheStartMs) {
                    diskCachePositionMs = segment.endTimeMs.coerceAtMost(currentPlaylist.durationMs)
                    nextStartPositionMs = diskCachePositionMs
                    sendDiskCacheProgress(
                        diskCacheStartMs = diskCacheStartMs,
                        diskCachePositionMs = diskCachePositionMs,
                        durationMs = currentPlaylist.durationMs,
                        isComplete = false,
                        force = false,
                        taskGeneration = taskGeneration,
                        quality = currentPlaylist.quality,
                    )
                }
            }

            if (!audioUrl.isNullOrBlank()) {
                cacheAudioSegments(taskGeneration)
            }

            if (isCurrent(taskGeneration)) {
                status = "completed"
                sendDiskCacheProgress(
                    diskCacheStartMs = 0L,
                    diskCachePositionMs = currentPlaylist.durationMs,
                    durationMs = currentPlaylist.durationMs,
                    isComplete = true,
                    force = true,
                    taskGeneration = taskGeneration,
                    quality = currentPlaylist.quality,
                )
                notifyFinished(taskGeneration)
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Throwable) {
            sendCacheError(error, taskGeneration)
            notifyFinished(taskGeneration)
            // Disk prefetch is optional; playback should continue through ExoPlayer.
        }
    }

    private fun cacheAudioSegments(taskGeneration: Int) {
        val audioUrl = audioUrl ?: return
        val audioHeaders = audioHeaders ?: headers
        try {
            val playlist = loadPlaylist(
                selectedQuality = autoQuality(),
                url = audioUrl,
                headers = audioHeaders,
            )
            for (resource in playlist.resources) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                cacheUriWithRetry(resource, taskGeneration, audioHeaders)
            }
            for (segment in playlist.segments) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                cacheUriWithRetry(segment.uri, taskGeneration, audioHeaders)
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (_: Throwable) {
            // Audio prefetch is optional; playback should continue.
        }
    }

    private fun loadPlaylist(
        selectedQuality: Map<String, Any?>,
        url: String = this.url,
        headers: Map<String, String> = this.headers,
    ): Playlist {
        val rootUri = Uri.parse(url)
        return when (val rootPlaylist = loadHlsPlaylist(rootUri, headers)) {
            is HlsMediaPlaylist -> {
                logMediaPlaylist(rootUri, rootPlaylist, root = true)
                toPlaylist(rootUri, rootPlaylist, selectedQuality)
            }
            is HlsMultivariantPlaylist -> {
                logMultivariantPlaylist(rootUri, rootPlaylist)
                val selectedVariant = selectMediaPlaylistVariant(rootPlaylist, selectedQuality)
                val selectedPlaylistUri = selectedVariant?.url
                    ?: rootPlaylist.mediaPlaylistUrls.firstOrNull()
                    ?: Uri.parse(url)
                val mediaPlaylist = loadHlsPlaylist(selectedPlaylistUri, headers) as? HlsMediaPlaylist
                    ?: return Playlist(emptyList(), emptyList(), durationMs = 0L, quality = selectedQuality)
                logMediaPlaylist(selectedPlaylistUri, mediaPlaylist, root = false)
                toPlaylist(
                    selectedPlaylistUri,
                    mediaPlaylist,
                    selectedVariant?.format?.let {
                        qualityPayload(
                            width = it.width.coerceAtLeast(0),
                            height = it.height.coerceAtLeast(0),
                            bitrate = it.bitrate.coerceAtLeast(0),
                        )
                    } ?: selectedQuality,
                )
            }
            else -> Playlist(emptyList(), emptyList(), durationMs = 0L, quality = selectedQuality)
        }
    }

    private fun loadHlsPlaylist(uri: Uri, headers: Map<String, String> = this.headers): HlsPlaylist {
            val dataSource = M3u8CacheManager.mediaDataSourceFactory(appContext, headers, cacheKey)
                .createDataSource()
        return ParsingLoadable.load(
            dataSource,
            HlsPlaylistParser(),
            uri,
            C.DATA_TYPE_MANIFEST,
        )
    }

    private fun selectMediaPlaylistUri(playlist: HlsMultivariantPlaylist): Uri {
        val selectedQuality = normalizedQuality(qualityProvider())
        return selectMediaPlaylistVariant(playlist, selectedQuality)?.url
            ?: playlist.mediaPlaylistUrls.firstOrNull()
            ?: Uri.parse(url)
    }

    private fun selectMediaPlaylistVariant(
        playlist: HlsMultivariantPlaylist,
        selectedQuality: Map<String, Any?>,
    ): HlsMultivariantPlaylist.Variant? {
        val variants = playlist.variants
        if (variants.isEmpty()) {
            return null
        }
        val isAuto = selectedQuality["isAuto"] == true
        if (isAuto) {
            return variants.first()
        }
        val selectedHeight = selectedQuality["height"] as? Int ?: 0
        val selectedBitrate = selectedQuality["bitrate"] as? Int ?: 0
        val selectedWidth = selectedQuality["width"] as? Int ?: 0
        return variants.minWithOrNull(
            compareBy<HlsMultivariantPlaylist.Variant> { variant ->
                val height = variant.format.height.coerceAtLeast(0)
                if (selectedHeight > 0 && height > 0) {
                    kotlin.math.abs(height - selectedHeight)
                } else {
                    Int.MAX_VALUE / 4
                }
            }.thenBy { variant ->
                val bitrate = variant.format.bitrate.coerceAtLeast(0)
                if (selectedBitrate > 0 && bitrate > 0) {
                    kotlin.math.abs(bitrate - selectedBitrate)
                } else {
                    Int.MAX_VALUE / 4
                }
            }.thenBy { variant ->
                val width = variant.format.width.coerceAtLeast(0)
                if (selectedWidth > 0 && width > 0) {
                    kotlin.math.abs(width - selectedWidth)
                } else {
                    Int.MAX_VALUE / 4
                }
            },
        )
    }

    private fun logMultivariantPlaylist(
        playlistUri: Uri,
        playlist: HlsMultivariantPlaylist,
    ) {
        M3u8Log.info(
            "hlsMaster source=$sourceDebugId uri=${playlistUri.safeLogUri()} " +
                "variants=${playlist.variants.size} mediaPlaylistUrls=${playlist.mediaPlaylistUrls.size} " +
                "audios=${playlist.audios.size} subtitles=${playlist.subtitles.size}",
        )
        playlist.variants.forEachIndexed { index, variant ->
            val format = variant.format
            M3u8Log.info(
                "hlsVariant source=$sourceDebugId index=$index " +
                    "resolution=${format.width.valueOrUnknown()}x${format.height.valueOrUnknown()} " +
                    "bandwidth=${format.bitrate.valueOrUnknown()} " +
                    "averageBitrate=${format.averageBitrate.valueOrUnknown()} " +
                    "peakBitrate=${format.peakBitrate.valueOrUnknown()} " +
                    "codecs=${format.codecs ?: "unknown"} " +
                    "mime=${format.sampleMimeType ?: format.containerMimeType ?: "unknown"} " +
                    "videoGroup=${variant.videoGroupId ?: "none"} " +
                    "audioGroup=${variant.audioGroupId ?: "none"} " +
                    "uri=${variant.url.safeLogUri()}",
            )
        }
        val selectedPlaylistUri = selectMediaPlaylistUri(playlist)
        M3u8Log.info(
            "hlsSelectedVariant source=$sourceDebugId uri=${selectedPlaylistUri.safeLogUri()}",
        )
    }

    private fun logMediaPlaylist(
        playlistUri: Uri,
        playlist: HlsMediaPlaylist,
        root: Boolean,
    ) {
        M3u8Log.info(
            "hlsMedia source=$sourceDebugId root=$root uri=${playlistUri.safeLogUri()} " +
                "type=${playlist.playlistType.name()} segments=${playlist.segments.size} " +
                "durationMs=${usToMs(playlist.durationUs).coerceAtLeast(0L)} " +
                "targetDurationMs=${usToMs(playlist.targetDurationUs).coerceAtLeast(0L)} " +
                "version=${playlist.version} hasEndTag=${playlist.hasEndTag}",
        )
        val firstSegment = playlist.segments.firstOrNull()
        val lastSegment = playlist.segments.lastOrNull()
        if (firstSegment != null && lastSegment != null) {
            val baseUri = playlist.baseUri.takeIf { it.isNotBlank() } ?: playlistUri.toString()
            M3u8Log.info(
                "hlsSegments source=$sourceDebugId " +
                    "first=${resolveUri(baseUri, firstSegment.url).safeLogUri()} " +
                    "last=${resolveUri(baseUri, lastSegment.url).safeLogUri()}",
            )
        }
    }

    private fun toPlaylist(
        playlistUri: Uri,
        mediaPlaylist: HlsMediaPlaylist,
        quality: Map<String, Any?>,
    ): Playlist {
        val resources = linkedSetOf<Uri>()
        val segments = mutableListOf<Segment>()
        val baseUri = mediaPlaylist.baseUri.takeIf { it.isNotBlank() } ?: playlistUri.toString()

        for (segment in mediaPlaylist.segments) {
            segment.initializationSegment?.let {
                resources.add(resolveUri(baseUri, it.url))
            }
            segment.fullSegmentEncryptionKeyUri?.let {
                resources.add(resolveUri(baseUri, it))
            }
            val startTimeMs = usToMs(segment.relativeStartTimeUs).coerceAtLeast(0L)
            val durationMs = usToMs(segment.durationUs).coerceAtLeast(0L)
            segments.add(
                Segment(
                    uri = resolveUri(baseUri, segment.url),
                    startTimeMs = startTimeMs,
                    endTimeMs = (startTimeMs + durationMs).coerceAtLeast(startTimeMs),
                ),
            )
        }

        return Playlist(
            segments = segments,
            resources = resources.toList(),
            durationMs = usToMs(mediaPlaylist.durationUs).coerceAtLeast(0L),
            quality = quality,
        )
    }

    private fun resolveUri(baseUri: String, reference: String): Uri {
        return UriUtil.resolveToUri(baseUri, reference)
    }

    private fun cacheUriWithRetry(uri: Uri, taskGeneration: Int, headers: Map<String, String>) {
        var attempt = 0
        while (isCurrent(taskGeneration)) {
            try {
                cacheUri(uri, taskGeneration, headers)
                return
            } catch (error: Throwable) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                retryCount = attempt
                if (attempt >= maxRetries) {
                    throw error
                }
                attempt += 1
                retryCount = attempt
                Thread.sleep((attempt * 200L).coerceAtMost(1000L))
            }
        }
    }

    private fun cacheUri(uri: Uri, taskGeneration: Int, headers: Map<String, String>) {
        if (!isCurrent(taskGeneration)) {
            return
        }
        val wasCached = M3u8CacheManager.hasCachedData(appContext, uri.toString(), headers, cacheKey)
        if (wasCached) {
            cacheHitCount += 1
        } else {
            networkFetchCount += 1
        }
        val writer = CacheWriter(
            M3u8CacheManager.downloadDataSourceFactory(appContext, headers, cacheKey)
                .createDataSourceForDownloading(),
            DataSpec.Builder()
                .setUri(uri)
                .setHttpRequestHeaders(headers)
                .setKey(M3u8CacheManager.cacheKey(uri.toString(), headers, cacheKey))
                .build(),
            ByteArray(CacheWriter.DEFAULT_BUFFER_SIZE_BYTES),
            null,
        )
        currentWriter = writer
        try {
            writer.cache()
        } finally {
            if (currentWriter === writer) {
                currentWriter = null
            }
        }
    }

    private fun sendDiskCacheProgress(
        diskCacheStartMs: Long,
        diskCachePositionMs: Long,
        durationMs: Long,
        isComplete: Boolean,
        force: Boolean,
        taskGeneration: Int,
        quality: Map<String, Any?>,
    ) {
        if (!force) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastProgressSentAt < PROGRESS_INTERVAL_MS) {
                return
            }
            lastProgressSentAt = now
        } else {
            lastProgressSentAt = SystemClock.elapsedRealtime()
        }
        updateDownloadSpeed()
        val percent = if (durationMs <= 0L) {
            0.0
        } else {
            (diskCachePositionMs.toDouble() / durationMs.toDouble() * 100.0)
                .coerceIn(0.0, 100.0)
        }
        val eventName = when {
            taskId == null -> "diskCache"
            isComplete -> "completed"
            else -> "progress"
        }
        val event = baseEvent(
            eventName = eventName,
            diskCacheStartMs = diskCacheStartMs,
            diskCachePositionMs = diskCachePositionMs,
            durationMs = durationMs,
            percent = percent,
            isComplete = isComplete,
            quality = quality,
        )
        mainHandler.post {
            if (isCurrent(taskGeneration)) {
                eventSinkProvider()?.success(event)
            }
        }
    }

    private fun baseEvent(
        eventName: String,
        diskCacheStartMs: Long,
        diskCachePositionMs: Long,
        durationMs: Long,
        percent: Double,
        isComplete: Boolean,
        quality: Map<String, Any?>,
    ): Map<String, Any?> {
        return mapOf(
            "playerId" to playerIdProvider(),
            "event" to eventName,
            "taskId" to taskId,
            "url" to url,
            "owner" to owner,
            "status" to if (isComplete) "completed" else status,
            "sourceType" to sourceType.platformValue(),
            "priority" to priority,
            "duration" to durationMs,
            "diskCacheStartPosition" to diskCacheStartMs,
            "diskCachePosition" to diskCachePositionMs,
            "diskCachePercent" to percent,
            "isDiskCacheComplete" to isComplete,
            "quality" to quality,
            "bytesCached" to bytesCached,
            "bytesTotal" to bytesTotal,
            "downloadSpeedBytesPerSecond" to downloadSpeedBytesPerSecond,
            "cacheHitCount" to cacheHitCount,
            "networkFetchCount" to networkFetchCount,
            "segmentIndex" to segmentIndex,
            "segmentCount" to segmentCount,
            "currentUrl" to currentUrl,
            "retryCount" to retryCount,
            "updatedAt" to System.currentTimeMillis(),
            "metadata" to metadata,
        ).filterValues { it != null }
    }

    private fun sendCacheError(error: Throwable, taskGeneration: Int) {
        val cacheTaskId = taskId ?: return
        if (!isCurrent(taskGeneration)) {
            return
        }
        status = "error"
        mainHandler.post {
            if (isCurrent(taskGeneration)) {
                eventSinkProvider()?.success(
                    mapOf(
                        "taskId" to cacheTaskId,
                        "url" to url,
                        "event" to "error",
                        "owner" to owner,
                        "status" to "error",
                        "sourceType" to sourceType.platformValue(),
                        "priority" to priority,
                        "bytesCached" to bytesCached,
                        "bytesTotal" to bytesTotal,
                        "downloadSpeedBytesPerSecond" to downloadSpeedBytesPerSecond,
                        "cacheHitCount" to cacheHitCount,
                        "networkFetchCount" to networkFetchCount,
                        "segmentIndex" to segmentIndex,
                        "segmentCount" to segmentCount,
                        "currentUrl" to currentUrl,
                        "retryCount" to retryCount,
                        "updatedAt" to System.currentTimeMillis(),
                        "metadata" to metadata,
                        "error" to mapOf(
                            "code" to "cache_error",
                            "message" to (error.message ?: "Cache task failed."),
                        ),
                    ),
                )
            }
        }
    }

    private fun sendStatusEvent(eventName: String) {
        val event = baseEvent(
            eventName = eventName,
            diskCacheStartMs = 0L,
            diskCachePositionMs = 0L,
            durationMs = 0L,
            percent = 0.0,
            isComplete = status == "completed",
            quality = normalizedQuality(qualityProvider()),
        )
        mainHandler.post {
            eventSinkProvider()?.success(event)
        }
    }

    private fun notifyFinished(taskGeneration: Int) {
        val callback = onFinished ?: return
        mainHandler.post {
            if (generation.get() == taskGeneration) {
                callback()
            }
        }
    }

    private fun isCurrent(taskGeneration: Int): Boolean {
        return !cancelled && generation.get() == taskGeneration
    }

    private fun updateDownloadSpeed() {
        val now = SystemClock.elapsedRealtime()
        val elapsed = now - lastBytesSampleAt
        if (elapsed < PROGRESS_INTERVAL_MS) {
            return
        }
        val delta = bytesCached - lastBytesSample
        downloadSpeedBytesPerSecond = if (elapsed > 0L) {
            (delta * 1000L / elapsed).coerceAtLeast(0L)
        } else {
            0L
        }
        lastBytesSample = bytesCached
        lastBytesSampleAt = now
    }

    private fun normalizedQuality(quality: Map<String, Any?>): Map<String, Any?> {
        return if (quality["isAuto"] == true) {
            autoQuality()
        } else {
            qualityPayload(
                width = (quality["width"] as? Number)?.toInt() ?: 0,
                height = (quality["height"] as? Number)?.toInt() ?: 0,
                bitrate = (quality["bitrate"] as? Number)?.toInt() ?: 0,
            )
        }
    }

    private fun qualityKey(quality: Map<String, Any?>): String {
        return listOf(
            quality["isAuto"] == true,
            quality["width"] as? Int ?: 0,
            quality["height"] as? Int ?: 0,
            quality["bitrate"] as? Int ?: 0,
        ).joinToString(":")
    }

    private fun qualityPayload(width: Int, height: Int, bitrate: Int): Map<String, Any?> {
        val safeHeight = height.coerceAtLeast(0)
        val safeBitrate = bitrate.coerceAtLeast(0)
        val label = when {
            safeHeight > 0 -> "${safeHeight}p"
            safeBitrate > 0 -> "${safeBitrate / 1000} Kbps"
            else -> "Unknown"
        }
        val id = when {
            safeHeight > 0 -> "${safeHeight}p"
            safeBitrate > 0 -> "${safeBitrate}bps"
            else -> "unknown"
        }
        return mapOf(
            "id" to id,
            "label" to label,
            "width" to width.coerceAtLeast(0),
            "height" to safeHeight,
            "bitrate" to safeBitrate,
            "isAuto" to false,
        )
    }

    private fun usToMs(timeUs: Long): Long {
        return timeUs / C.MICROS_PER_SECOND * C.MILLIS_PER_SECOND +
            timeUs % C.MICROS_PER_SECOND / 1_000L
    }

    private fun Int.valueOrUnknown(): String {
        return takeIf { it > 0 }?.toString() ?: "unknown"
    }

    private fun Int.name(): String {
        return when (this) {
            HlsMediaPlaylist.PLAYLIST_TYPE_VOD -> "vod"
            HlsMediaPlaylist.PLAYLIST_TYPE_EVENT -> "event"
            HlsMediaPlaylist.PLAYLIST_TYPE_UNKNOWN -> "unknown"
            else -> "unknown:$this"
        }
    }

    private fun Uri.safeLogUri(): String {
        val lastPath = lastPathSegment ?: return M3u8Log.sourceDebugId(toString())
        return ".../$lastPath"
    }

    private data class Playlist(
        val segments: List<Segment>,
        val resources: List<Uri>,
        val durationMs: Long,
        val quality: Map<String, Any?>,
    ) {
        fun segmentIndexFor(positionMs: Long): Int {
            if (segments.isEmpty()) {
                return 0
            }
            val normalizedPositionMs = positionMs.coerceIn(0L, durationMs)
            val index = segments.indexOfFirst { segment ->
                normalizedPositionMs < segment.endTimeMs
            }
            return if (index >= 0) index else segments.lastIndex
        }
    }

    private data class Segment(
        val uri: Uri,
        val startTimeMs: Long,
        val endTimeMs: Long,
    )

    private companion object {
        const val PROGRESS_INTERVAL_MS = 250L

        fun autoQuality(): Map<String, Any?> {
            return mapOf(
                "id" to "auto",
                "label" to "Auto",
                "width" to 0,
                "height" to 0,
                "bitrate" to 0,
                "isAuto" to true,
            )
        }
    }
}

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
    private val playerIdProvider: () -> Long,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
) {
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
    private var currentWriter: CacheWriter? = null

    @Volatile
    private var playlist: Playlist? = null

    private var lastProgressSentAt = 0L

    fun start() {
        restartFrom(positionMs = 0L)
    }

    fun restartFrom(positionMs: Long) {
        if (cancelled) {
            return
        }
        val taskGeneration = generation.incrementAndGet()
        currentWriter?.cancel()
        executor.execute {
            cacheVod(startPositionMs = positionMs.coerceAtLeast(0L), taskGeneration)
        }
    }

    fun cancel() {
        cancelled = true
        generation.incrementAndGet()
        currentWriter?.cancel()
        executor.shutdownNow()
    }

    private fun cacheVod(startPositionMs: Long, taskGeneration: Int) {
        try {
            val currentPlaylist = playlist ?: loadPlaylist().also { playlist = it }
            if (
                currentPlaylist.segments.isEmpty() ||
                currentPlaylist.durationMs <= 0L ||
                !isCurrent(taskGeneration)
            ) {
                return
            }

            val startIndex = currentPlaylist.segmentIndexFor(startPositionMs)
            val orderedSegments = currentPlaylist.segments.drop(startIndex) +
                currentPlaylist.segments.take(startIndex)
            val diskCacheStartMs = currentPlaylist.segments[startIndex].startTimeMs
            var diskCachePositionMs = diskCacheStartMs
            sendDiskCacheProgress(
                diskCacheStartMs = diskCacheStartMs,
                diskCachePositionMs = diskCachePositionMs,
                durationMs = currentPlaylist.durationMs,
                isComplete = false,
                force = true,
                taskGeneration = taskGeneration,
            )

            for (resource in currentPlaylist.resources) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                cacheUri(resource, taskGeneration)
            }

            for (segment in orderedSegments) {
                if (!isCurrent(taskGeneration)) {
                    return
                }
                cacheUri(segment.uri, taskGeneration)
                if (segment.startTimeMs >= diskCacheStartMs) {
                    diskCachePositionMs = segment.endTimeMs.coerceAtMost(currentPlaylist.durationMs)
                    sendDiskCacheProgress(
                        diskCacheStartMs = diskCacheStartMs,
                        diskCachePositionMs = diskCachePositionMs,
                        durationMs = currentPlaylist.durationMs,
                        isComplete = false,
                        force = false,
                        taskGeneration = taskGeneration,
                    )
                }
            }

            if (isCurrent(taskGeneration)) {
                sendDiskCacheProgress(
                    diskCacheStartMs = 0L,
                    diskCachePositionMs = currentPlaylist.durationMs,
                    durationMs = currentPlaylist.durationMs,
                    isComplete = true,
                    force = true,
                    taskGeneration = taskGeneration,
                )
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (_: Throwable) {
            // Disk prefetch is optional; playback should continue through ExoPlayer.
        }
    }

    private fun loadPlaylist(): Playlist {
        val rootUri = Uri.parse(url)
        return when (val rootPlaylist = loadHlsPlaylist(rootUri)) {
            is HlsMediaPlaylist -> {
                logMediaPlaylist(rootUri, rootPlaylist, root = true)
                toPlaylist(rootUri, rootPlaylist)
            }
            is HlsMultivariantPlaylist -> {
                logMultivariantPlaylist(rootUri, rootPlaylist)
                val selectedPlaylistUri = selectMediaPlaylistUri(rootPlaylist)
                val mediaPlaylist = loadHlsPlaylist(selectedPlaylistUri) as? HlsMediaPlaylist
                    ?: return Playlist(emptyList(), emptyList(), durationMs = 0L)
                logMediaPlaylist(selectedPlaylistUri, mediaPlaylist, root = false)
                toPlaylist(selectedPlaylistUri, mediaPlaylist)
            }
            else -> Playlist(emptyList(), emptyList(), durationMs = 0L)
        }
    }

    private fun loadHlsPlaylist(uri: Uri): HlsPlaylist {
        val dataSource = M3u8CacheManager.mediaDataSourceFactory(appContext, headers)
            .createDataSource()
        return ParsingLoadable.load(
            dataSource,
            HlsPlaylistParser(),
            uri,
            C.DATA_TYPE_MANIFEST,
        )
    }

    private fun selectMediaPlaylistUri(playlist: HlsMultivariantPlaylist): Uri {
        val variant = playlist.variants
            .maxByOrNull { it.format.height.takeIf { height -> height > 0 } ?: 0 }
        return variant?.url
            ?: playlist.mediaPlaylistUrls.firstOrNull()
            ?: Uri.parse(url)
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

    private fun toPlaylist(playlistUri: Uri, mediaPlaylist: HlsMediaPlaylist): Playlist {
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
        )
    }

    private fun resolveUri(baseUri: String, reference: String): Uri {
        return UriUtil.resolveToUri(baseUri, reference)
    }

    private fun cacheUri(uri: Uri, taskGeneration: Int) {
        if (!isCurrent(taskGeneration)) {
            return
        }
        val writer = CacheWriter(
            M3u8CacheManager.downloadDataSourceFactory(appContext, headers)
                .createDataSourceForDownloading(),
            DataSpec.Builder()
                .setUri(uri)
                .setHttpRequestHeaders(headers)
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
        val percent = if (durationMs <= 0L) {
            0.0
        } else {
            (diskCachePositionMs.toDouble() / durationMs.toDouble() * 100.0)
                .coerceIn(0.0, 100.0)
        }
        val event = mapOf(
            "playerId" to playerIdProvider(),
            "event" to "diskCache",
            "duration" to durationMs,
            "diskCacheStartPosition" to diskCacheStartMs,
            "diskCachePosition" to diskCachePositionMs,
            "diskCachePercent" to percent,
            "isDiskCacheComplete" to isComplete,
        )
        mainHandler.post {
            if (isCurrent(taskGeneration)) {
                eventSinkProvider()?.success(event)
            }
        }
    }

    private fun isCurrent(taskGeneration: Int): Boolean {
        return !cancelled && generation.get() == taskGeneration
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
    }
}

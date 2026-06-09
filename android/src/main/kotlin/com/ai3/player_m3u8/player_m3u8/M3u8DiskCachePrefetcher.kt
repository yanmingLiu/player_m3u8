package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.CacheWriter
import io.flutter.plugin.common.EventChannel
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.roundToLong

internal class M3u8DiskCachePrefetcher(
    context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    private val playerIdProvider: () -> Long,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "player_m3u8_disk_cache").apply { isDaemon = true }
    }

    @Volatile
    private var cancelled = false

    @Volatile
    private var currentWriter: CacheWriter? = null

    fun start() {
        executor.execute {
            cacheVod()
        }
    }

    fun cancel() {
        cancelled = true
        currentWriter?.cancel()
        executor.shutdownNow()
    }

    private fun cacheVod() {
        try {
            val playlist = loadPlaylist(url)
            if (playlist.segments.isEmpty() || playlist.durationMs <= 0L) {
                return
            }

            var diskCachePositionMs = 0L
            sendDiskCacheProgress(diskCachePositionMs, playlist.durationMs, isComplete = false)

            for (resourceUrl in playlist.resources) {
                if (cancelled) {
                    return
                }
                try {
                    cacheSegment(resourceUrl)
                } catch (_: Throwable) {
                    // Optional HLS resources should not stop segment prefetch.
                }
            }

            for (segment in playlist.segments) {
                if (cancelled) {
                    return
                }
                cacheSegment(segment.url)
                diskCachePositionMs =
                    (diskCachePositionMs + segment.durationMs).coerceAtMost(playlist.durationMs)
                sendDiskCacheProgress(
                    diskCachePositionMs,
                    playlist.durationMs,
                    isComplete = false,
                )
            }

            if (!cancelled) {
                sendDiskCacheProgress(
                    playlist.durationMs,
                    playlist.durationMs,
                    isComplete = true,
                )
            }
        } catch (_: Throwable) {
            // Playback must not fail just because the optional disk prefetch failed.
        }
    }

    private fun cacheSegment(segmentUrl: String) {
        val dataSpec = DataSpec.Builder()
            .setUri(Uri.parse(segmentUrl))
            .setHttpRequestHeaders(headers)
            .build()
        val writer = CacheWriter(
            M3u8CacheManager.downloadDataSource(appContext, headers),
            dataSpec,
            ByteArray(CacheWriter.DEFAULT_BUFFER_SIZE_BYTES),
            null,
        )
        currentWriter = writer
        try {
            writer.cache()
        } finally {
            currentWriter = null
        }
    }

    private fun loadPlaylist(playlistUrl: String, depth: Int = 0): Playlist {
        if (cancelled || depth > MAX_PLAYLIST_DEPTH) {
            return Playlist(emptyList(), emptyList(), durationMs = 0L)
        }

        val lines = readText(playlistUrl)
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        val segments = mutableListOf<Segment>()
        val resources = linkedSetOf<String>()
        val childPlaylists = mutableListOf<String>()
        var pendingDurationMs: Long? = null

        for (line in lines) {
            when {
                line.startsWith("#EXTINF:") -> {
                    pendingDurationMs = parseExtInfDurationMs(line)
                }
                line.startsWith("#EXT-X-KEY:") || line.startsWith("#EXT-X-MAP:") -> {
                    parseAttributeUri(line)?.let { resources.add(resolveUrl(playlistUrl, it)) }
                }
                line.startsWith("#") -> Unit
                pendingDurationMs != null -> {
                    segments.add(
                        Segment(
                            url = resolveUrl(playlistUrl, line),
                            durationMs = pendingDurationMs ?: 0L,
                        ),
                    )
                    pendingDurationMs = null
                }
                else -> childPlaylists.add(resolveUrl(playlistUrl, line))
            }
        }

        if (segments.isNotEmpty()) {
            return Playlist(
                segments = segments,
                resources = resources.toList(),
                durationMs = segments.sumOf { it.durationMs },
            )
        }

        for (childPlaylist in childPlaylists) {
            val playlist = loadPlaylist(childPlaylist, depth + 1)
            if (playlist.segments.isNotEmpty()) {
                return playlist
            }
        }

        return Playlist(emptyList(), emptyList(), durationMs = 0L)
    }

    private fun readText(playlistUrl: String): String {
        val connection = URL(playlistUrl).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = NETWORK_TIMEOUT_MS
        connection.readTimeout = NETWORK_TIMEOUT_MS
        headers.forEach { (key, value) ->
            connection.setRequestProperty(key, value)
        }
        return try {
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun parseExtInfDurationMs(line: String): Long {
        val seconds = line.substringAfter(':')
            .substringBefore(',')
            .trim()
            .toDoubleOrNull()
            ?: return 0L
        return (seconds * 1000.0).roundToLong().coerceAtLeast(0L)
    }

    private fun parseAttributeUri(line: String): String? {
        val attributes = line.substringAfter(':', missingDelimiterValue = "")
        val match = Regex("""URI="([^"]+)"""").find(attributes)
        return match?.groupValues?.getOrNull(1)
    }

    private fun resolveUrl(baseUrl: String, maybeRelativeUrl: String): String {
        return URI(baseUrl).resolve(maybeRelativeUrl).toString()
    }

    private fun sendDiskCacheProgress(
        diskCachePositionMs: Long,
        durationMs: Long,
        isComplete: Boolean,
    ) {
        val event = mapOf(
            "playerId" to playerIdProvider(),
            "event" to "diskCache",
            "duration" to durationMs,
            "diskCachePosition" to diskCachePositionMs,
            "isDiskCacheComplete" to isComplete,
        )
        mainHandler.post {
            if (!cancelled) {
                eventSinkProvider()?.success(event)
            }
        }
    }

    private data class Playlist(
        val segments: List<Segment>,
        val resources: List<String>,
        val durationMs: Long,
    )

    private data class Segment(
        val url: String,
        val durationMs: Long,
    )

    private companion object {
        const val NETWORK_TIMEOUT_MS = 15_000
        const val MAX_PLAYLIST_DEPTH = 3
    }
}

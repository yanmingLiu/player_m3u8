package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.exoplayer.hls.offline.HlsDownloader
import androidx.media3.exoplayer.offline.Downloader
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors

internal class M3u8DiskCachePrefetcher(
    context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    private val playerIdProvider: () -> Long,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val taskExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "player_m3u8_hls_prefetch").apply { isDaemon = true }
    }
    private val downloadExecutor = Executors.newFixedThreadPool(MAX_PARALLEL_DOWNLOADS) { runnable ->
        Thread(runnable, "player_m3u8_hls_download").apply { isDaemon = true }
    }

    @Volatile
    private var cancelled = false

    @Volatile
    private var downloader: HlsDownloader? = null

    private var lastProgressSentAt = 0L

    fun start() {
        taskExecutor.execute {
            cacheVod()
        }
    }

    fun cancel() {
        cancelled = true
        downloader?.cancel()
        taskExecutor.shutdownNow()
        downloadExecutor.shutdownNow()
    }

    private fun cacheVod() {
        val mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMimeType(MimeTypes.APPLICATION_M3U8)
            .build()
        val currentDownloader = HlsDownloader(
            mediaItem,
            M3u8CacheManager.downloadDataSourceFactory(appContext, headers),
            downloadExecutor,
        )
        downloader = currentDownloader
        sendDiskCacheProgress(percent = 0.0, isComplete = false, force = true)

        try {
            currentDownloader.download(
                Downloader.ProgressListener { _, _, percentDownloaded ->
                    if (!cancelled && percentDownloaded >= 0f) {
                        sendDiskCacheProgress(
                            percent = percentDownloaded.coerceIn(0f, 100f).toDouble(),
                            isComplete = false,
                            force = false,
                        )
                    }
                },
            )
            if (!cancelled) {
                sendDiskCacheProgress(percent = 100.0, isComplete = true, force = true)
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (_: Throwable) {
            // Disk prefetch is optional; playback should continue through ExoPlayer.
        } finally {
            if (downloader === currentDownloader) {
                downloader = null
            }
        }
    }

    private fun sendDiskCacheProgress(percent: Double, isComplete: Boolean, force: Boolean) {
        if (!force) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastProgressSentAt < PROGRESS_INTERVAL_MS) {
                return
            }
            lastProgressSentAt = now
        } else {
            lastProgressSentAt = SystemClock.elapsedRealtime()
        }
        val event = mapOf(
            "playerId" to playerIdProvider(),
            "event" to "diskCache",
            "diskCachePercent" to percent,
            "isDiskCacheComplete" to isComplete,
        )
        mainHandler.post {
            if (!cancelled) {
                eventSinkProvider()?.success(event)
            }
        }
    }

    private companion object {
        const val MAX_PARALLEL_DOWNLOADS = 3
        const val PROGRESS_INTERVAL_MS = 250L
    }
}

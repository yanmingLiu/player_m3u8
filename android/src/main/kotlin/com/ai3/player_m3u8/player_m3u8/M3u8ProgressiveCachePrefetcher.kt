package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.CacheWriter
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

internal class M3u8ProgressiveCachePrefetcher(
    context: Context,
    private val url: String,
    private val headers: Map<String, String>,
    private val cacheKey: String?,
    override val taskId: String,
    override val priority: Int,
    private val maxRetries: Int,
    private val metadata: Map<String, Any?>,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
    private val onFinished: (() -> Unit)?,
) : M3u8CacheTaskHandle {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "player_m3u8_progressive_prefetch").apply { isDaemon = true }
    }
    private val generation = AtomicInteger(0)

    @Volatile
    private var cancelled = false

    @Volatile
    private var currentWriter: CacheWriter? = null

    @Volatile
    private var status = "queued"

    @Volatile
    private var bytesCached = 0L

    @Volatile
    private var bytesTotal = 0L

    @Volatile
    private var speedBytesPerSecond = 0L

    @Volatile
    private var cacheHitCount = 0

    @Volatile
    private var networkFetchCount = 0

    @Volatile
    private var retryCount = 0

    private var lastBytesSample = 0L
    private var lastBytesSampleAt = SystemClock.elapsedRealtime()

    override val isRunning: Boolean
        get() = status == "running"

    override val isQueued: Boolean
        get() = status == "queued"

    override val isPaused: Boolean
        get() = status == "paused"

    override fun start() {
        restartFrom(0L)
    }

    override fun restartFrom(positionMs: Long) {
        if (cancelled) return
        status = "running"
        val taskGeneration = generation.incrementAndGet()
        currentWriter?.cancel()
        executor.execute {
            cache(taskGeneration)
        }
        sendProgress(force = true)
    }

    override fun markQueued(positionMs: Long?) {
        if (cancelled) return
        status = "queued"
        sendProgress(force = true)
    }

    override fun pause() {
        if (cancelled) return
        status = "paused"
        generation.incrementAndGet()
        currentWriter?.cancel()
        sendProgress(force = true)
    }

    override fun resume() {
        restartFrom(0L)
    }

    override fun cancel() {
        cancelled = true
        status = "cancelled"
        generation.incrementAndGet()
        currentWriter?.cancel()
        executor.shutdownNow()
        sendProgress(force = true, eventName = "cancelled")
    }

    override fun snapshot(): Map<String, Any?> {
        return baseEvent(eventName = if (status == "completed") "completed" else "progress")
    }

    private fun cache(taskGeneration: Int) {
        try {
            var attempt = 0
            while (isCurrent(taskGeneration) && isRunning) {
                try {
                    cacheOnce(taskGeneration)
                    if (isCurrent(taskGeneration)) {
                        status = "completed"
                        sendProgress(force = true, eventName = "completed")
                        notifyFinished()
                    }
                    return
                } catch (error: Throwable) {
                    if (!isCurrent(taskGeneration) || !isRunning) return
                    if (attempt >= maxRetries) throw error
                    attempt += 1
                    retryCount = attempt
                    Thread.sleep((attempt * 200L).coerceAtMost(1000L))
                }
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Throwable) {
            status = "error"
            sendError(error)
            notifyFinished()
        }
    }

    private fun cacheOnce(taskGeneration: Int) {
        val wasCached = M3u8CacheManager.hasCachedData(appContext, url, headers, cacheKey)
        if (wasCached) {
            cacheHitCount += 1
        } else {
            networkFetchCount += 1
        }
        val writer = CacheWriter(
            M3u8CacheManager.downloadDataSourceFactory(appContext, headers, cacheKey)
                .createDataSourceForDownloading(),
            DataSpec.Builder()
                .setUri(Uri.parse(url))
                .setHttpRequestHeaders(headers)
                .setKey(M3u8CacheManager.cacheKey(url, headers, cacheKey))
                .build(),
            ByteArray(CacheWriter.DEFAULT_BUFFER_SIZE_BYTES),
            CacheWriter.ProgressListener { requestLength, requestBytesCached, newBytesCached ->
                if (requestLength > 0L) {
                    bytesTotal = requestLength
                }
                bytesCached = requestBytesCached.coerceAtLeast(bytesCached + newBytesCached)
                updateSpeed()
                sendProgress(force = false)
            },
        )
        currentWriter = writer
        try {
            writer.cache()
            if (bytesTotal <= 0L) {
                bytesTotal = bytesCached
            }
        } finally {
            if (currentWriter === writer) {
                currentWriter = null
            }
        }
    }

    private fun sendProgress(force: Boolean, eventName: String = "progress") {
        if (!force) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastProgressSentAt < PROGRESS_INTERVAL_MS) return
            lastProgressSentAt = now
        } else {
            lastProgressSentAt = SystemClock.elapsedRealtime()
        }
        val event = baseEvent(eventName)
        mainHandler.post {
            eventSinkProvider()?.success(event)
        }
    }

    @Volatile
    private var lastProgressSentAt = 0L

    private fun baseEvent(eventName: String): Map<String, Any?> {
        val percent = if (bytesTotal > 0L) {
            (bytesCached.toDouble() / bytesTotal.toDouble() * 100.0).coerceIn(0.0, 100.0)
        } else {
            0.0
        }
        return mapOf(
            "playerId" to -1L,
            "event" to eventName,
            "taskId" to taskId,
            "url" to url,
            "owner" to "standalone",
            "status" to status,
            "sourceType" to M3u8SourceType.PROGRESSIVE.platformValue(),
            "priority" to priority,
            "diskCachePercent" to percent,
            "isDiskCacheComplete" to (status == "completed"),
            "bytesCached" to bytesCached,
            "bytesTotal" to bytesTotal,
            "downloadSpeedBytesPerSecond" to speedBytesPerSecond,
            "cacheHitCount" to cacheHitCount,
            "networkFetchCount" to networkFetchCount,
            "segmentIndex" to 0,
            "segmentCount" to 1,
            "currentUrl" to url,
            "retryCount" to retryCount,
            "updatedAt" to System.currentTimeMillis(),
            "metadata" to metadata,
        )
    }

    private fun sendError(error: Throwable) {
        mainHandler.post {
            eventSinkProvider()?.success(
                baseEvent("error") + mapOf(
                    "error" to mapOf(
                        "code" to "cache_error",
                        "message" to (error.message ?: "Cache task failed."),
                    ),
                ),
            )
        }
    }

    private fun isCurrent(taskGeneration: Int): Boolean {
        return !cancelled && generation.get() == taskGeneration
    }

    private fun updateSpeed() {
        val now = SystemClock.elapsedRealtime()
        val elapsed = now - lastBytesSampleAt
        if (elapsed < PROGRESS_INTERVAL_MS) return
        val delta = bytesCached - lastBytesSample
        speedBytesPerSecond = if (elapsed > 0L) {
            (delta * 1000L / elapsed).coerceAtLeast(0L)
        } else {
            0L
        }
        lastBytesSample = bytesCached
        lastBytesSampleAt = now
    }

    private fun notifyFinished() {
        mainHandler.post { onFinished?.invoke() }
    }

    private companion object {
        const val PROGRESS_INTERVAL_MS = 250L
    }
}

package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

internal object M3u8CacheManager {
    private const val CACHE_DIRECTORY_NAME = "player_m3u8_media_cache"
    private const val DEFAULT_MAX_CACHE_BYTES = 512L * 1024L * 1024L

    @Volatile
    private var simpleCache: SimpleCache? = null

    @Volatile
    private var maxCacheBytes = DEFAULT_MAX_CACHE_BYTES

    fun cache(context: Context): SimpleCache {
        return simpleCache ?: synchronized(this) {
            simpleCache ?: SimpleCache(
                cacheDirectory(context),
                LeastRecentlyUsedCacheEvictor(maxCacheBytes),
                StandaloneDatabaseProvider(context.applicationContext),
            ).also { simpleCache = it }
        }
    }

    fun configure(maxSizeBytes: Long) {
        require(maxSizeBytes > 0L) { "maxSizeBytes must be greater than zero." }
        synchronized(this) {
            if (simpleCache != null && maxCacheBytes != maxSizeBytes) {
                simpleCache?.release()
                simpleCache = null
            }
            maxCacheBytes = maxSizeBytes
        }
    }

    fun clear(context: Context) {
        synchronized(this) {
            simpleCache?.release()
            simpleCache = null
            cacheDirectory(context).deleteRecursively()
        }
    }

    fun info(context: Context): Map<String, Long> {
        val configuredMaxCacheBytes = synchronized(this) { maxCacheBytes }
        return mapOf(
            "maxSizeBytes" to configuredMaxCacheBytes,
            "sizeBytes" to directorySize(cacheDirectory(context)),
        )
    }

    fun mediaDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
    ): DataSource.Factory {
        return cacheDataSourceFactory(context, headers)
    }

    fun downloadDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
    ): CacheDataSource.Factory {
        return cacheDataSourceFactory(context, headers)
    }

    private fun cacheDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
    ): CacheDataSource.Factory {
        return CacheDataSource.Factory()
            .setCache(cache(context))
            .setUpstreamDataSourceFactory(
                DefaultDataSource.Factory(context, httpDataSourceFactory(headers)),
            )
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    private fun httpDataSourceFactory(headers: Map<String, String>): DefaultHttpDataSource.Factory {
        val factory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
        if (headers.isNotEmpty()) {
            factory.setDefaultRequestProperties(headers)
        }
        return factory
    }

    private fun cacheDirectory(context: Context): File {
        return File(context.cacheDir, CACHE_DIRECTORY_NAME)
    }

    private fun directorySize(file: File): Long {
        if (!file.exists()) return 0L
        if (file.isFile) return file.length()
        return file.listFiles()?.sumOf { directorySize(it) } ?: 0L
    }
}

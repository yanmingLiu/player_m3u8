package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheKeyFactory
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File
import java.net.URI

internal object M3u8CacheManager {
    private const val CACHE_DIRECTORY_NAME = "player_m3u8_media_cache"
    private const val DEFAULT_MAX_CACHE_BYTES = 512L * 1024L * 1024L

    @Volatile
    private var simpleCache: SimpleCache? = null

    @Volatile
    private var maxCacheBytes = DEFAULT_MAX_CACHE_BYTES

    @Volatile
    private var maxConcurrentPrecacheTasks = 2

    fun cache(context: Context): SimpleCache {
        return simpleCache ?: synchronized(this) {
            simpleCache ?: SimpleCache(
                cacheDirectory(context),
                LeastRecentlyUsedCacheEvictor(maxCacheBytes),
                StandaloneDatabaseProvider(context.applicationContext),
            ).also { simpleCache = it }
        }
    }

    fun configure(maxSizeBytes: Long, maxConcurrentPrecacheTasks: Int = this.maxConcurrentPrecacheTasks) {
        require(maxSizeBytes > 0L) { "maxSizeBytes must be greater than zero." }
        require(maxConcurrentPrecacheTasks > 0) {
            "maxConcurrentPrecacheTasks must be greater than zero."
        }
        synchronized(this) {
            if (simpleCache != null && maxCacheBytes != maxSizeBytes) {
                simpleCache?.release()
                simpleCache = null
            }
            maxCacheBytes = maxSizeBytes
            this.maxConcurrentPrecacheTasks = maxConcurrentPrecacheTasks
        }
    }

    fun maxConcurrentPrecacheTasks(): Int = synchronized(this) { maxConcurrentPrecacheTasks }

    fun maxSizeBytes(): Long = synchronized(this) { maxCacheBytes }

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

    fun sourceInfo(
        context: Context,
        url: String,
        headers: Map<String, String>,
        cacheKey: String?,
    ): Map<String, Long> {
        val cache = cache(context)
        val keys = matchingKeys(cache, url, headers, cacheKey)
        val size = keys.sumOf { key ->
            cache.getCachedSpans(key).sumOf { it.length }
        }
        return mapOf(
            "maxSizeBytes" to synchronized(this) { maxCacheBytes },
            "sizeBytes" to size.coerceAtLeast(0L),
        )
    }

    fun clearSource(
        context: Context,
        url: String,
        headers: Map<String, String>,
        cacheKey: String?,
    ) {
        val cache = cache(context)
        matchingKeys(cache, url, headers, cacheKey).forEach { key ->
            cache.removeResource(key)
        }
    }

    fun mediaDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
        cacheKey: String? = null,
    ): DataSource.Factory {
        return cacheDataSourceFactory(context, headers, cacheKey)
    }

    fun downloadDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
        cacheKey: String? = null,
    ): CacheDataSource.Factory {
        return cacheDataSourceFactory(context, headers, cacheKey)
    }

    private fun cacheDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
        cacheKey: String?,
    ): CacheDataSource.Factory {
        return CacheDataSource.Factory()
            .setCache(cache(context))
            .setUpstreamDataSourceFactory(
                DefaultDataSource.Factory(context, httpDataSourceFactory(headers)),
            )
            .setCacheKeyFactory(headerAwareCacheKeyFactory(headers, cacheKey))
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    fun cacheKey(uri: String, headers: Map<String, String>, cacheKey: String? = null): String {
        if (!cacheKey.isNullOrBlank()) {
            return "$cacheKey\n${resourceIdentity(uri)}"
        }
        val headerIdentity = headers
            .toSortedMap(String.CASE_INSENSITIVE_ORDER)
            .entries
            .joinToString(separator = "\n") { (key, value) ->
                "${key.lowercase()}=$value"
            }
        return "$uri\n$headerIdentity"
    }

    fun hasCachedData(
        context: Context,
        uri: String,
        headers: Map<String, String>,
        cacheKey: String? = null,
    ): Boolean {
        return cache(context).getCachedSpans(cacheKey(uri, headers, cacheKey)).isNotEmpty()
    }

    private fun headerAwareCacheKeyFactory(
        headers: Map<String, String>,
        cacheKey: String?,
    ): CacheKeyFactory {
        return CacheKeyFactory { dataSpec: DataSpec ->
            cacheKey(dataSpec.uri.toString(), headers, cacheKey)
        }
    }

    private fun matchingKeys(
        cache: SimpleCache,
        url: String,
        headers: Map<String, String>,
        cacheKey: String?,
    ): Set<String> {
        if (!cacheKey.isNullOrBlank()) {
            val prefix = "$cacheKey\n"
            return cache.keys.filter { it.startsWith(prefix) }.toSet()
        }
        return setOf(cacheKey(url, headers, null))
    }

    private fun resourceIdentity(uri: String): String {
        return runCatching {
            val parsed = URI(uri)
            parsed.rawPath?.takeIf { it.isNotBlank() } ?: uri.substringBefore('?').substringBefore('#')
        }.getOrElse {
            uri.substringBefore('?').substringBefore('#')
        }
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

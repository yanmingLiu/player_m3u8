package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

internal object M3u8CacheManager {
    private const val CACHE_DIRECTORY_NAME = "player_m3u8_media_cache"

    @Volatile
    private var simpleCache: SimpleCache? = null

    fun cache(context: Context): SimpleCache {
        return simpleCache ?: synchronized(this) {
            simpleCache ?: SimpleCache(
                File(context.cacheDir, CACHE_DIRECTORY_NAME),
                NoOpCacheEvictor(),
                StandaloneDatabaseProvider(context.applicationContext),
            ).also { simpleCache = it }
        }
    }

    fun mediaDataSourceFactory(
        context: Context,
        headers: Map<String, String>,
    ): DataSource.Factory {
        return cacheDataSourceFactory(context, headers)
    }

    fun downloadDataSource(
        context: Context,
        headers: Map<String, String>,
    ): CacheDataSource {
        return cacheDataSourceFactory(context, headers).createDataSourceForDownloading()
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
}

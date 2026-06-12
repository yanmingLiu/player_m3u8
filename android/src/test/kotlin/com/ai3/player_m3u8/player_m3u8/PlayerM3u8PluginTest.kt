package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.file.Files
import org.mockito.ArgumentCaptor
import org.mockito.Mockito
import kotlin.test.AfterTest
import kotlin.test.assertEquals
import kotlin.test.Test

internal class PlayerM3u8PluginTest {
    private val temporaryDirectories = mutableListOf<File>()

    @AfterTest
    fun tearDown() {
        temporaryDirectories.forEach { it.deleteRecursively() }
        temporaryDirectories.clear()
    }

    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("missingMethod", null), result)

        Mockito.verify(result).notImplemented()
    }

    @Test
    fun onMethodCall_playUnknownPlayer_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("play", mapOf("playerId" to 42)), result)

        Mockito.verify(result).error(
            Mockito.eq("unknown_player"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_precacheInvalidUrl_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("precache", mapOf("videoUrl" to "")), result)

        Mockito.verify(result).error(
            Mockito.eq("invalid_url"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_precacheInvalidInitialPosition_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(
            MethodCall(
                "precache",
                mapOf(
                    "videoUrl" to "https://example.com/index.m3u8",
                    "initialPosition" to -1,
                ),
            ),
            result,
        )

        Mockito.verify(result).error(
            Mockito.eq("invalid_initial_position"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_precacheInvalidMaxRetries_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(
            MethodCall(
                "precache",
                mapOf(
                    "videoUrl" to "https://example.com/index.m3u8",
                    "maxRetries" to -1,
                ),
            ),
            result,
        )

        Mockito.verify(result).error(
            Mockito.eq("invalid_max_retries"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_configureCacheInvalidConcurrency_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(
            MethodCall(
                "configureCache",
                mapOf(
                    "maxSizeBytes" to 4096,
                    "maxConcurrentPrecacheTasks" to 0,
                ),
            ),
            result,
        )

        Mockito.verify(result).error(
            Mockito.eq("invalid_cache_concurrency"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_cacheTasks_returnsEmptyList() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        val captor = ArgumentCaptor.forClass(Any::class.java)

        plugin.onMethodCall(MethodCall("cacheTasks", null), result)

        Mockito.verify(result).success(captor.capture())
        assertEquals(emptyList<Any>(), captor.value)
    }

    @Test
    fun onMethodCall_pauseResumeUnknownPrecache_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val pauseResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        val resumeResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("pausePrecache", mapOf("taskId" to "missing")), pauseResult)
        plugin.onMethodCall(MethodCall("resumePrecache", mapOf("taskId" to "missing")), resumeResult)

        Mockito.verify(pauseResult).error(
            Mockito.eq("unknown_cache_task"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
        Mockito.verify(resumeResult).error(
            Mockito.eq("unknown_cache_task"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun sourceTypeAuto_resolvesByUrlExtension() {
        assertEquals(
            M3u8SourceType.HLS,
            M3u8SourceType.AUTO.resolve("https://example.com/index.m3u8?token=1"),
        )
        assertEquals(
            M3u8SourceType.PROGRESSIVE,
            M3u8SourceType.AUTO.resolve("https://example.com/video.mp4#t=1"),
        )
        assertEquals(
            M3u8SourceType.PROGRESSIVE,
            M3u8SourceType.AUTO.resolve("https://example.com/video.mov"),
        )
        assertEquals(
            M3u8SourceType.HLS,
            M3u8SourceType.HLS.resolve("https://example.com/video.mp4"),
        )
        assertEquals(
            M3u8SourceType.PROGRESSIVE,
            M3u8SourceType.PROGRESSIVE.resolve("https://example.com/index.m3u8"),
        )
    }

    @Test
    fun onMethodCall_cancelPrecacheInvalidTask_returnsError() {
        val plugin = PlayerM3u8Plugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("cancelPrecache", mapOf("taskId" to "")), result)

        Mockito.verify(result).error(
            Mockito.eq("invalid_cache_task"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }

    @Test
    fun onMethodCall_getCacheInfo_returnsConfiguredLimitAndDiskUsage() {
        val cacheDir = temporaryDirectory()
        val mediaCacheDir = File(cacheDir, "player_m3u8_media_cache")
        mediaCacheDir.mkdirs()
        File(mediaCacheDir, "segment.cache").writeBytes(ByteArray(12))
        val context: Context = Mockito.mock(Context::class.java)
        Mockito.`when`(context.cacheDir).thenReturn(cacheDir)
        M3u8CacheManager.configure(4096L)
        val plugin = PlayerM3u8Plugin(context)
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        val captor = ArgumentCaptor.forClass(Any::class.java)

        plugin.onMethodCall(MethodCall("getCacheInfo", null), result)

        Mockito.verify(result).success(captor.capture())
        val info = captor.value as Map<*, *>
        assertEquals(4096L, info["maxSizeBytes"])
        assertEquals(12L, info["sizeBytes"])
        M3u8CacheManager.clear(context)
        M3u8CacheManager.configure(512L * 1024L * 1024L)
    }

    private fun temporaryDirectory(): File {
        return Files.createTempDirectory("player_m3u8_test").toFile().also {
            temporaryDirectories.add(it)
        }
    }
}

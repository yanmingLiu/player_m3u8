package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.util.UUID

class PlayerM3u8Plugin() : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var textures: TextureRegistry
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var cacheEventChannel: EventChannel
    private val players = mutableMapOf<Long, M3u8AndroidPlayer>()
    private val cacheTasks = mutableMapOf<String, M3u8DiskCachePrefetcher>()
    private var eventSink: EventChannel.EventSink? = null
    private var cacheEventSink: EventChannel.EventSink? = null

    internal constructor(context: Context) : this() {
        this.context = context
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textures = binding.textureRegistry
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        cacheEventChannel = EventChannel(binding.binaryMessenger, CACHE_EVENT_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        cacheEventChannel.setStreamHandler(CacheEventStreamHandler())
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "create" -> create(call, result)
            "play" -> withPlayer(call, result) { player ->
                player.play()
                result.success(null)
            }
            "pause" -> withPlayer(call, result) { player ->
                player.pause()
                result.success(null)
            }
            "seekTo" -> withPlayer(call, result) { player ->
                val position = call.argument<Number>("position")?.toLong()
                if (position == null || position < 0L) {
                    result.error("invalid_position", "position must be a non-negative integer.", null)
                    return@withPlayer
                }
                player.seekTo(position)
                result.success(null)
            }
            "setQuality" -> withPlayer(call, result) { player ->
                val quality = call.argument<Map<String, Any?>>("quality")
                if (quality == null) {
                    result.error("invalid_quality", "quality is required.", null)
                    return@withPlayer
                }
                if (!player.setQuality(quality)) {
                    result.error(
                        "unsupported_source_type",
                        "Quality selection is only supported for HLS sources.",
                        null,
                    )
                    return@withPlayer
                }
                result.success(null)
            }
            "setRecoveryPolicy" -> withPlayer(call, result) { player ->
                val policy = call.argument<Map<String, Any?>>("recoveryPolicy")
                player.setRecoveryPolicy(M3u8RecoveryPolicy.fromMap(policy))
                result.success(null)
            }
            "setPlaybackSpeed" -> withPlayer(call, result) { player ->
                val speed = call.argument<Number>("speed")?.toFloat()
                if (speed == null || speed.isNaN() || speed.isInfinite() || speed < 0.25f || speed > 2.0f) {
                    result.error(
                        "invalid_playback_speed",
                        "speed must be finite and between 0.25 and 2.0.",
                        null,
                    )
                    return@withPlayer
                }
                player.setPlaybackSpeed(speed)
                result.success(null)
            }
            "setVolume" -> withPlayer(call, result) { player ->
                val volume = call.argument<Number>("volume")?.toFloat()
                if (volume == null || volume.isNaN() || volume.isInfinite() || volume < 0f || volume > 1f) {
                    result.error(
                        "invalid_volume",
                        "volume must be finite and between 0.0 and 1.0.",
                        null,
                    )
                    return@withPlayer
                }
                player.setVolume(volume)
                result.success(null)
            }
            "setMuted" -> withPlayer(call, result) { player ->
                val isMuted = call.argument<Boolean>("isMuted")
                if (isMuted == null) {
                    result.error("invalid_muted", "isMuted is required.", null)
                    return@withPlayer
                }
                player.setMuted(isMuted)
                result.success(null)
            }
            "setSubtitle" -> withPlayer(call, result) { player ->
                val subtitleId = call.argument<String>("subtitleId")
                player.setSubtitle(subtitleId)
                result.success(null)
            }
            "setAudioTrack" -> withPlayer(call, result) { player ->
                val audioTrackId = call.argument<String>("audioTrackId")
                player.setAudioTrack(audioTrackId)
                result.success(null)
            }
            "dispose" -> {
                val playerId = call.argument<Number>("playerId")?.toLong()
                if (playerId == null) {
                    result.error("invalid_player_id", "playerId is required.", null)
                    return
                }
                players.remove(playerId)?.dispose()
                result.success(null)
            }
            "configureCache" -> configureCache(call, result)
            "clearCache" -> clearCache(result)
            "getCacheInfo" -> getCacheInfo(result)
            "precache" -> precache(call, result)
            "cancelPrecache" -> cancelPrecache(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        cacheEventChannel.setStreamHandler(null)
        players.values.forEach { it.dispose() }
        players.clear()
        cacheTasks.values.forEach { it.cancel() }
        cacheTasks.clear()
        eventSink = null
        cacheEventSink = null
    }

    private fun create(call: MethodCall, result: Result) {
        val videoUrl = call.argument<String>("videoUrl")
        if (videoUrl.isNullOrBlank()) {
            result.error("invalid_url", "videoUrl is required.", null)
            return
        }
        val audioUrl = call.argument<String>("audioUrl")
        val videoHeaders = call.argument<Map<String, String>>("videoHeaders") ?: emptyMap()
        val audioHeaders = call.argument<Map<String, String>>("audioHeaders")
        val initialPositionMs = call.argument<Number>("initialPosition")?.toLong() ?: 0L
        if (initialPositionMs < 0L) {
            result.error(
                "invalid_initial_position",
                "initialPosition must be a non-negative integer.",
                null,
            )
            return
        }
        val recoveryPolicy = M3u8RecoveryPolicy.fromMap(
            call.argument<Map<String, Any?>>("recoveryPolicy"),
        )
        val playbackSpeed = call.argument<Number>("playbackSpeed")?.toFloat() ?: 1.0f
        if (
            playbackSpeed.isNaN() ||
                playbackSpeed.isInfinite() ||
                playbackSpeed < 0.25f ||
                playbackSpeed > 2.0f
        ) {
            result.error(
                "invalid_playback_speed",
                "playbackSpeed must be finite and between 0.25 and 2.0.",
                null,
            )
            return
        }
        val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
        if (volume.isNaN() || volume.isInfinite() || volume < 0f || volume > 1f) {
            result.error(
                "invalid_volume",
                "volume must be finite and between 0.0 and 1.0.",
                null,
            )
            return
        }
        val isMuted = call.argument<Boolean>("isMuted") ?: false
        val subtitles = call.argument<List<Map<String, Any?>>>("subtitles") ?: emptyList()
        val selectedSubtitleId = call.argument<String>("selectedSubtitleId")
        val selectedAudioTrackId = call.argument<String>("selectedAudioTrackId")
        val sourceType = M3u8SourceType.from(call.argument<String>("sourceType"))
        val surfaceProducer = textures.createSurfaceProducer()
        val player = M3u8AndroidPlayer(
            context = context,
            videoUrl = videoUrl,
            audioUrl = audioUrl,
            videoHeaders = videoHeaders,
            audioHeaders = audioHeaders,
            sourceType = sourceType,
            initialPositionMs = initialPositionMs,
            playbackSpeed = playbackSpeed,
            volume = volume,
            isMuted = isMuted,
            externalSubtitles = subtitles,
            selectedSubtitleId = selectedSubtitleId,
            selectedAudioTrackId = selectedAudioTrackId,
            recoveryPolicy = recoveryPolicy,
            surfaceProducer = surfaceProducer,
            eventSinkProvider = { eventSink },
        )
        players[surfaceProducer.id()] = player
        result.success(surfaceProducer.id())
    }

    private fun configureCache(call: MethodCall, result: Result) {
        val maxSizeBytes = call.argument<Number>("maxSizeBytes")?.toLong()
        if (maxSizeBytes == null || maxSizeBytes <= 0L) {
            result.error(
                "invalid_cache_size",
                "maxSizeBytes must be greater than zero.",
                null,
            )
            return
        }
        if (players.isNotEmpty()) {
            result.error(
                "active_players",
                "Cache cannot be configured while players are active.",
                null,
            )
            return
        }
        if (cacheTasks.isNotEmpty()) {
            result.error(
                "active_cache_tasks",
                "Cache cannot be configured while cache tasks are active.",
                null,
            )
            return
        }
        try {
            M3u8CacheManager.configure(maxSizeBytes)
            result.success(null)
        } catch (error: IllegalStateException) {
            result.error("cache_in_use", error.message, null)
        }
    }

    private fun clearCache(result: Result) {
        if (players.isNotEmpty()) {
            result.error(
                "active_players",
                "Cache cannot be cleared while players are active.",
                null,
            )
            return
        }
        if (cacheTasks.isNotEmpty()) {
            result.error(
                "active_cache_tasks",
                "Cache cannot be cleared while cache tasks are active.",
                null,
            )
            return
        }
        M3u8CacheManager.clear(context)
        result.success(null)
    }

    private fun getCacheInfo(result: Result) {
        result.success(M3u8CacheManager.info(context))
    }

    private fun precache(call: MethodCall, result: Result) {
        val videoUrl = call.argument<String>("videoUrl")
        if (videoUrl.isNullOrBlank()) {
            result.error("invalid_url", "videoUrl is required.", null)
            return
        }
        val audioUrl = call.argument<String>("audioUrl")
        val initialPositionMs = call.argument<Number>("initialPosition")?.toLong() ?: 0L
        if (initialPositionMs < 0L) {
            result.error(
                "invalid_initial_position",
                "initialPosition must be a non-negative integer.",
                null,
            )
            return
        }
        val videoHeaders = call.argument<Map<String, String>>("videoHeaders") ?: emptyMap()
        val audioHeaders = call.argument<Map<String, String>>("audioHeaders")
        val sourceType = M3u8SourceType.from(call.argument<String>("sourceType")).resolve(videoUrl)
        if (sourceType != M3u8SourceType.HLS) {
            result.error(
                "unsupported_source_type",
                "Precache is only supported for HLS sources.",
                null,
            )
            return
        }
        val quality = call.argument<Map<String, Any?>>("quality") ?: autoQuality()
        val taskId = UUID.randomUUID().toString()
        val prefetcher = M3u8DiskCachePrefetcher(
            context = context,
            url = videoUrl,
            headers = videoHeaders,
            playerIdProvider = { -1L },
            eventSinkProvider = { cacheEventSink },
            taskId = taskId,
            onFinished = { cacheTasks.remove(taskId) },
            qualityProvider = { quality },
            audioUrl = audioUrl,
            audioHeaders = audioHeaders,
        )
        cacheTasks[taskId] = prefetcher
        prefetcher.restartFrom(initialPositionMs)
        result.success(taskId)
    }

    private fun cancelPrecache(call: MethodCall, result: Result) {
        val taskId = call.argument<String>("taskId")
        if (taskId.isNullOrBlank()) {
            result.error("invalid_cache_task", "taskId is required.", null)
            return
        }
        cacheTasks.remove(taskId)?.cancel()
        cacheEventSink?.success(
            mapOf(
                "taskId" to taskId,
                "event" to "cancelled",
            ),
        )
        result.success(null)
    }

    private fun withPlayer(
        call: MethodCall,
        result: Result,
        action: (M3u8AndroidPlayer) -> Unit,
    ) {
        val playerId = call.argument<Number>("playerId")?.toLong()
        val player = playerId?.let { players[it] }
        if (playerId == null || player == null) {
            result.error("unknown_player", "No player exists for playerId $playerId.", null)
            return
        }
        action(player)
    }

    private companion object {
        const val METHOD_CHANNEL_NAME = "player_m3u8/methods"
        const val EVENT_CHANNEL_NAME = "player_m3u8/events"
        const val CACHE_EVENT_CHANNEL_NAME = "player_m3u8/cache_events"
    }

    private inner class CacheEventStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            cacheEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            cacheEventSink = null
        }
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
}

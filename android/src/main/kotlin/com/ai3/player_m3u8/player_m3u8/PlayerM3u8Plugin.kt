package com.ai3.player_m3u8.player_m3u8

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

class PlayerM3u8Plugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var textures: TextureRegistry
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val players = mutableMapOf<Long, M3u8AndroidPlayer>()
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textures = binding.textureRegistry
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
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
        players.values.forEach { it.dispose() }
        players.clear()
        eventSink = null
    }

    private fun create(call: MethodCall, result: Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("invalid_url", "url is required.", null)
            return
        }
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val surfaceProducer = textures.createSurfaceProducer()
        val player = M3u8AndroidPlayer(
            context = context,
            url = url,
            headers = headers,
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
        M3u8CacheManager.clear(context)
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
    }
}

package com.ai3.player_m3u8.player_m3u8

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class PlayerM3u8PluginTest {
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
}

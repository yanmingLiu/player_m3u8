package com.ai3.player_m3u8.player_m3u8

import android.util.Log
import java.security.MessageDigest

internal object M3u8Log {
    const val TAG = "M3u8Player"
    const val PREFIX = "[player_m3u8]"

    fun info(message: String) {
        Log.i(TAG, "$PREFIX $message")
    }

    fun error(message: String, throwable: Throwable? = null) {
        Log.e(TAG, "$PREFIX $message", throwable)
    }

    fun sourceDebugId(url: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(url.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
            .take(SOURCE_HASH_LENGTH)
    }

    private const val SOURCE_HASH_LENGTH = 12
}

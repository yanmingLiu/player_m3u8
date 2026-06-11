package com.ai3.player_m3u8.player_m3u8

internal interface M3u8CacheTaskHandle {
    val taskId: String?
    val priority: Int
    val isRunning: Boolean
    val isQueued: Boolean
    val isPaused: Boolean

    fun start()
    fun restartFrom(positionMs: Long)
    fun markQueued(positionMs: Long? = null)
    fun pause()
    fun resume()
    fun cancel()
    fun snapshot(): Map<String, Any?>
}

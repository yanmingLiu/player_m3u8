package com.ai3.player_m3u8.player_m3u8

enum class M3u8SourceType {
    AUTO,
    HLS,
    PROGRESSIVE;

    fun resolve(url: String): M3u8SourceType {
        if (this != AUTO) {
            return this
        }
        val path = url.substringBefore('?').substringBefore('#').lowercase()
        return when {
            path.endsWith(".m3u8") -> HLS
            path.endsWith(".mp4") || path.endsWith(".mov") -> PROGRESSIVE
            else -> HLS
        }
    }

    fun platformValue(): String {
        return when (this) {
            AUTO -> "auto"
            HLS -> "hls"
            PROGRESSIVE -> "progressive"
        }
    }

    companion object {
        fun from(value: String?): M3u8SourceType {
            return when (value?.lowercase()) {
                "hls" -> HLS
                "progressive" -> PROGRESSIVE
                else -> AUTO
            }
        }
    }
}

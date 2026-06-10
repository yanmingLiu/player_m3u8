package com.ai3.player_m3u8.player_m3u8

data class M3u8RecoveryPolicy(
    val isEnabled: Boolean = true,
    val rebufferThreshold: Int = DEFAULT_REBUFFER_THRESHOLD,
    val minimumRecoveryIntervalMs: Long = DEFAULT_MINIMUM_RECOVERY_INTERVAL_MS,
    val minimumAutoQualityHeight: Int = 0,
) {
    fun normalized(): M3u8RecoveryPolicy {
        return copy(
            rebufferThreshold = rebufferThreshold.coerceAtLeast(1),
            minimumRecoveryIntervalMs = minimumRecoveryIntervalMs.coerceAtLeast(0L),
            minimumAutoQualityHeight = minimumAutoQualityHeight.coerceAtLeast(0),
        )
    }

    companion object {
        const val DEFAULT_REBUFFER_THRESHOLD = 3
        const val DEFAULT_MINIMUM_RECOVERY_INTERVAL_MS = 10_000L

        fun fromMap(map: Map<String, Any?>?): M3u8RecoveryPolicy {
            if (map == null) {
                return M3u8RecoveryPolicy()
            }
            return M3u8RecoveryPolicy(
                isEnabled = map["isEnabled"] as? Boolean ?: true,
                rebufferThreshold = (map["rebufferThreshold"] as? Number)?.toInt()
                    ?: DEFAULT_REBUFFER_THRESHOLD,
                minimumRecoveryIntervalMs =
                    (map["minimumRecoveryIntervalMs"] as? Number)?.toLong()
                        ?: DEFAULT_MINIMUM_RECOVERY_INTERVAL_MS,
                minimumAutoQualityHeight =
                    (map["minimumAutoQualityHeight"] as? Number)?.toInt() ?: 0,
            ).normalized()
        }
    }
}

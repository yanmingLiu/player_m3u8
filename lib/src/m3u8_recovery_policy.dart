import 'package:flutter/foundation.dart';

@immutable
class M3u8RecoveryPolicy {
  const M3u8RecoveryPolicy({
    this.isEnabled = true,
    this.rebufferThreshold = 3,
    this.minimumRecoveryInterval = const Duration(seconds: 10),
    this.minimumAutoQualityHeight = 0,
  });

  static const M3u8RecoveryPolicy defaults = M3u8RecoveryPolicy();
  static const M3u8RecoveryPolicy disabled = M3u8RecoveryPolicy(
    isEnabled: false,
  );

  final bool isEnabled;
  final int rebufferThreshold;
  final Duration minimumRecoveryInterval;
  final int minimumAutoQualityHeight;

  M3u8RecoveryPolicy copyWith({
    bool? isEnabled,
    int? rebufferThreshold,
    Duration? minimumRecoveryInterval,
    int? minimumAutoQualityHeight,
  }) {
    return M3u8RecoveryPolicy(
      isEnabled: isEnabled ?? this.isEnabled,
      rebufferThreshold: rebufferThreshold ?? this.rebufferThreshold,
      minimumRecoveryInterval:
          minimumRecoveryInterval ?? this.minimumRecoveryInterval,
      minimumAutoQualityHeight:
          minimumAutoQualityHeight ?? this.minimumAutoQualityHeight,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'isEnabled': isEnabled,
      'rebufferThreshold': rebufferThreshold,
      'minimumRecoveryIntervalMs': minimumRecoveryInterval.inMilliseconds,
      'minimumAutoQualityHeight': minimumAutoQualityHeight,
    };
  }

  void debugAssertValid() {
    assert(
      rebufferThreshold > 0,
      'rebufferThreshold must be greater than zero.',
    );
    assert(
      !minimumRecoveryInterval.isNegative,
      'minimumRecoveryInterval must not be negative.',
    );
    assert(
      minimumAutoQualityHeight >= 0,
      'minimumAutoQualityHeight must not be negative.',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is M3u8RecoveryPolicy &&
        other.isEnabled == isEnabled &&
        other.rebufferThreshold == rebufferThreshold &&
        other.minimumRecoveryInterval == minimumRecoveryInterval &&
        other.minimumAutoQualityHeight == minimumAutoQualityHeight;
  }

  @override
  int get hashCode {
    return Object.hash(
      isEnabled,
      rebufferThreshold,
      minimumRecoveryInterval,
      minimumAutoQualityHeight,
    );
  }

  @override
  String toString() {
    return 'M3u8RecoveryPolicy('
        'isEnabled: $isEnabled, '
        'rebufferThreshold: $rebufferThreshold, '
        'minimumRecoveryInterval: $minimumRecoveryInterval, '
        'minimumAutoQualityHeight: $minimumAutoQualityHeight'
        ')';
  }
}

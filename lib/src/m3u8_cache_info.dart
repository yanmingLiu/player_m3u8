class M3u8CacheInfo {
  const M3u8CacheInfo({required this.maxSizeBytes, required this.sizeBytes})
    : assert(maxSizeBytes > 0),
      assert(sizeBytes >= 0);

  factory M3u8CacheInfo.fromMap(Map<Object?, Object?> map) {
    return M3u8CacheInfo(
      maxSizeBytes: _readPositiveInt(map['maxSizeBytes'], 'maxSizeBytes'),
      sizeBytes: _readNonNegativeInt(map['sizeBytes'], 'sizeBytes'),
    );
  }

  final int maxSizeBytes;
  final int sizeBytes;

  double get usageRatio {
    return (sizeBytes / maxSizeBytes).clamp(0, 1).toDouble();
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'maxSizeBytes': maxSizeBytes,
      'sizeBytes': sizeBytes,
    };
  }

  static int _readPositiveInt(Object? value, String key) {
    final intValue = _readInt(value, key);
    if (intValue <= 0) {
      throw ArgumentError.value(value, key, 'Must be greater than zero.');
    }
    return intValue;
  }

  static int _readNonNegativeInt(Object? value, String key) {
    final intValue = _readInt(value, key);
    if (intValue < 0) {
      throw ArgumentError.value(
        value,
        key,
        'Must be greater than or equal to zero.',
      );
    }
    return intValue;
  }

  static int _readInt(Object? value, String key) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.toInt();
    }
    throw ArgumentError.value(value, key, 'Expected an integer.');
  }

  @override
  String toString() {
    return 'M3u8CacheInfo(maxSizeBytes: $maxSizeBytes, '
        'sizeBytes: $sizeBytes)';
  }
}

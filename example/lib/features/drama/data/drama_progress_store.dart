import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last position for each drama series without coupling the page
/// lifecycle to `SharedPreferences`.
/// Writes are O(1) per position and serialized per key prefix to prevent an
/// older periodic snapshot from overwriting a newer one.
class DramaProgressStore {
  const DramaProgressStore({this.keyPrefix = defaultKeyPrefix});

  static const String defaultKeyPrefix = 'drama_progress_';
  static final Map<String, Future<void>> _writeQueues =
      <String, Future<void>>{};

  final String keyPrefix;

  Future<void> get _writeQueue =>
      _writeQueues[keyPrefix] ??= Future<void>.value();

  set _writeQueue(Future<void> operation) {
    _writeQueues[keyPrefix] = operation;
  }

  Future<void> save({
    required String seriesId,
    required int episodeNumber,
    required Duration position,
  }) async {
    final value = '$episodeNumber:${position.inMilliseconds}';
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$keyPrefix$seriesId', value);
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}

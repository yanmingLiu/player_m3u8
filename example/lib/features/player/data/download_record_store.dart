import 'dart:convert';

import 'package:player_m3u8/player_m3u8.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists standalone cache task metadata between example app launches.
///
/// Native cache bytes remain owned by `M3u8PlayerCache`; this store only keeps
/// the small amount of UI metadata needed to render and replay downloads.
/// Restore and save are O(n) in the number of records and use O(n) temporary
/// memory for JSON strings. Writes are serialized per preference key so rapid
/// cache events cannot commit an older snapshot after a newer one.
class DownloadRecordStore {
  const DownloadRecordStore({this.preferenceKey = defaultPreferenceKey});

  static const String defaultPreferenceKey =
      'player_m3u8_example_download_records';
  static final Map<String, Future<void>> _writeQueues =
      <String, Future<void>>{};

  final String preferenceKey;

  Future<void> get _writeQueue =>
      _writeQueues[preferenceKey] ??= Future<void>.value();

  set _writeQueue(Future<void> operation) {
    _writeQueues[preferenceKey] = operation;
  }

  Future<List<M3u8CacheTask>> restore() async {
    await _writeQueue;
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(preferenceKey);
    if (values == null || values.isEmpty) {
      return const <M3u8CacheTask>[];
    }

    final tasks = <M3u8CacheTask>[];
    for (final value in values) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) {
          continue;
        }
        final task = M3u8CacheTask.fromMap(Map<Object?, Object?>.from(decoded));
        if (task.taskId.isNotEmpty) {
          tasks.add(task);
        }
      } on FormatException {
        // Ignore a single corrupt record and keep the remaining history.
      } on TypeError {
        // Ignore records written by an older/incompatible example version.
      }
    }
    return tasks;
  }

  Future<void> save(Iterable<M3u8CacheTask> tasks) async {
    final values = tasks.map(_encode).toList(growable: false);
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(preferenceKey, values);
    });
    // Keep later writes usable even when an earlier best-effort write fails.
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  String _encode(M3u8CacheTask task) {
    return jsonEncode({
      'taskId': task.taskId,
      'url': task.url,
      'owner': task.owner.name,
      'status': task.status.name,
      'sourceType': task.sourceType.platformValue,
      'priority': task.priority,
      'bytesCached': task.bytesCached,
      'bytesTotal': task.bytesTotal,
      'downloadSpeedBytesPerSecond': task.downloadSpeedBytesPerSecond,
      'cacheHitCount': task.cacheHitCount,
      'networkFetchCount': task.networkFetchCount,
      'segmentIndex': task.segmentIndex,
      'segmentCount': task.segmentCount,
      'currentUrl': task.currentUrl,
      'retryCount': task.retryCount,
      'updatedAt': task.updatedAt?.millisecondsSinceEpoch,
      'metadata': task.metadata,
    });
  }
}

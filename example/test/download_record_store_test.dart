import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8_example/features/player/data/download_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ignores malformed persisted records', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DownloadRecordStore.defaultPreferenceKey: <String>['{not-json', '[]'],
    });

    final tasks = await const DownloadRecordStore().restore();

    expect(tasks, isEmpty);
  });

  test('round-trips cache task metadata', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final task = M3u8CacheTask(
      taskId: 'task-1',
      url: 'https://example.com/video.m3u8',
      owner: M3u8CacheTaskOwner.standalone,
      status: M3u8CacheTaskStatus.completed,
      sourceType: M3u8SourceType.hls,
      bytesCached: 128,
      bytesTotal: 256,
      metadata: const <String, Object?>{'title': 'Demo'},
    );

    const store = DownloadRecordStore();
    await store.save([task]);
    final restored = await store.restore();

    expect(restored, hasLength(1));
    expect(restored.single.taskId, task.taskId);
    expect(restored.single.metadata['title'], 'Demo');
    expect(restored.single.bytesCached, 128);
  });
}

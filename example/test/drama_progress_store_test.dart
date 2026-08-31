import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8_example/features/drama/data/drama_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('serializes progress writes and keeps the latest position', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const store = DramaProgressStore();

    await Future.wait([
      store.save(
        seriesId: 'series-1',
        episodeNumber: 1,
        position: const Duration(seconds: 10),
      ),
      store.save(
        seriesId: 'series-1',
        episodeNumber: 1,
        position: const Duration(seconds: 20),
      ),
    ]);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('drama_progress_series-1'), '1:20000');
  });
}

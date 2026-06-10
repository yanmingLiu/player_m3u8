import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('player_m3u8/methods');
  final log = <MethodCall>[];
  final platform = MethodChannelPlayerM3u8();

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'create') {
            return 3;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('create sends url and headers', () async {
    final playerId = await platform.create(
      url: 'https://example.com/index.m3u8',
      headers: const {'User-Agent': 'test'},
    );

    expect(playerId, 3);
    expect(log.single.method, 'create');
    expect(log.single.arguments, {
      'url': 'https://example.com/index.m3u8',
      'headers': {'User-Agent': 'test'},
      'recoveryPolicy': {
        'isEnabled': true,
        'rebufferThreshold': 3,
        'minimumRecoveryIntervalMs': 10000,
        'minimumAutoQualityHeight': 0,
      },
    });
  });

  test('seekTo sends player id and position milliseconds', () async {
    await platform.seekTo(3, const Duration(seconds: 8));

    expect(log.single.method, 'seekTo');
    expect(log.single.arguments, {'playerId': 3, 'position': 8000});
  });

  test('setQuality sends player id and quality payload', () async {
    await platform.setQuality(
      3,
      const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
    );

    expect(log.single.method, 'setQuality');
    expect(log.single.arguments, {
      'playerId': 3,
      'quality': {
        'id': '720p',
        'label': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 1500000,
        'isAuto': false,
      },
    });
  });

  test('setRecoveryPolicy sends player id and policy payload', () async {
    await platform.setRecoveryPolicy(
      3,
      const M3u8RecoveryPolicy(
        isEnabled: false,
        rebufferThreshold: 2,
        minimumRecoveryInterval: Duration(seconds: 5),
        minimumAutoQualityHeight: 480,
      ),
    );

    expect(log.single.method, 'setRecoveryPolicy');
    expect(log.single.arguments, {
      'playerId': 3,
      'recoveryPolicy': {
        'isEnabled': false,
        'rebufferThreshold': 2,
        'minimumRecoveryIntervalMs': 5000,
        'minimumAutoQualityHeight': 480,
      },
    });
  });

  test('dispose sends player id', () async {
    await platform.disposePlayer(3);

    expect(log.single.method, 'dispose');
    expect(log.single.arguments, {'playerId': 3});
  });

  test('configureCache sends maximum cache size', () async {
    await platform.configureCache(maxSizeBytes: 64 * 1024 * 1024);

    expect(log.single.method, 'configureCache');
    expect(log.single.arguments, {'maxSizeBytes': 64 * 1024 * 1024});
  });

  test('clearCache sends cache clear command', () async {
    await platform.clearCache();

    expect(log.single.method, 'clearCache');
    expect(log.single.arguments, isNull);
  });
}

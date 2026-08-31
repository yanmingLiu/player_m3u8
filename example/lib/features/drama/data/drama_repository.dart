import 'dart:convert';
import 'package:flutter/services.dart';
import 'drama_models.dart';

/// 本地 drama.json 数据仓储入口，隔离资源加载细节。
///
/// 解析时间和额外空间均为 O(s + e)，其中 s 是剧集数量，e 是总集数。
class DramaRepository {
  const DramaRepository({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/drama.json';

  final String assetPath;

  Future<List<DramaSeries>> load() async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    if (decoded is! Map || decoded['series'] is! List) return const [];
    return (decoded['series'] as List)
        .whereType<Map>()
        .map((e) => DramaSeries.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

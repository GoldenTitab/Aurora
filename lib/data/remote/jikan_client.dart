import 'dart:convert';

import 'api_gateway.dart';

class JikanClient {
  JikanClient(this._gw);
  final ApiGateway _gw;

  Future<Map<String, dynamic>?> fetchAnime(int malId) async {
    try {
      final res = await _gw.get(
        ApiHost.jikan,
        Uri.parse('https://api.jikan.moe/v4/anime/$malId/full'),
        cacheTtl: const Duration(hours: 12),
        maxAttempts: 2,
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'];
      if (data == null) return null;
      return (data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<double?> fetchScore(int malId) async {
    try {
      final res = await _gw.get(
        ApiHost.jikan,
        Uri.parse('https://api.jikan.moe/v4/anime/$malId'),
        cacheTtl: const Duration(hours: 12),
        maxAttempts: 1,
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final score = (json['data'] as Map?)?['score'];
      return (score as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
  }) async {
    try {
      final res = await _gw.get(
        ApiHost.jikan,
        Uri.parse(
          'https://api.jikan.moe/v4/anime'
          '?q=${Uri.encodeQueryComponent(query)}'
          '&limit=$limit&order_by=members&sort=desc&sfw=true',
        ),
        cacheTtl: const Duration(minutes: 15),
        maxAttempts: 2,
      );
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['data'] as List?) ?? const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>?> fetchUserList(
    String username,
    String status,
    int page,
  ) async {
    try {
      final res = await _gw.get(
        ApiHost.jikan,
        Uri.parse(
          'https://api.jikan.moe/v4/users/${Uri.encodeComponent(username)}'
          '/animelist?status=$status&page=$page&limit=100',
        ),
        cacheTtl: const Duration(minutes: 10),
        maxAttempts: 2,
      );
      if (res.statusCode == 404 || res.statusCode == 400) return null;
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['data'] as List?) ?? const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<({String relation, int malId})>> relations(int malId) async {
    try {
      final res = await _gw.get(
        ApiHost.jikan,
        Uri.parse('https://api.jikan.moe/v4/anime/$malId/full'),
        cacheTtl: const Duration(hours: 12),
        maxAttempts: 2,
      );
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = ((json['data'] as Map?)?['relations'] as List?) ?? const [];
      final out = <({String relation, int malId})>[];
      for (final r in list) {
        final m = (r as Map).cast<String, dynamic>();
        final rel = (m['relation'] as String?) ?? 'Other';
        final entries = (m['entry'] as List?) ?? const [];
        for (final e in entries) {
          final em = (e as Map).cast<String, dynamic>();
          if ((em['type'] as String?) != 'anime') continue;
          final id = (em['mal_id'] as num?)?.toInt();
          if (id != null) out.add((relation: rel, malId: id));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

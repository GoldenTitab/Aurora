import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import 'api_gateway.dart';
import '../../core/i18n/lang.dart';

class MalClient {
  MalClient(this._gw, {String? clientId})
    : _clientId = (clientId ?? malClientId).trim();

  final ApiGateway _gw;
  final String _clientId;

  static const String _base = 'https://api.myanimelist.net/v2';

  bool get isConfigured => _clientId.isNotEmpty;

  Map<String, String> get _authHeaders => {'X-MAL-CLIENT-ID': _clientId};

  /// جست‌وجوی انیمه در MAL. خروجی: لیستی از nodeهای خام MAL.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
  }) async {
    if (!isConfigured) return const [];
    try {
      final uri = Uri.parse(
        '$_base/anime?q=${Uri.encodeQueryComponent(query)}'
        '&limit=$limit'
        '&fields=id,title,main_picture,media_type,status,num_episodes,start_date',
      );
      final res = await _gw.get(
        ApiHost.mal,
        uri,
        headers: _authHeaders,
        cacheTtl: const Duration(minutes: 15),
        maxAttempts: 2,
      );
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['data'] as List?) ?? const [];
      return list
          .map((e) => ((e as Map)['node'] as Map).cast<String, dynamic>())
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MAL search error: $e');
      return const [];
    }
  }

  /// روابط یک انیمه در MAL (برای تکمیل گراف فرنچایز).
  /// خروجی: لیست (relationType, node).
  Future<List<({String relation, Map<String, dynamic> node})>> related(
    int malId,
  ) async {
    if (!isConfigured) return const [];
    try {
      final res = await _gw.get(
        ApiHost.mal,
        Uri.parse(
          '$_base/anime/$malId?fields=related_anime{relation_type}',
        ),
        headers: _authHeaders,
        cacheTtl: const Duration(hours: 12),
        maxAttempts: 2,
      );
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['related_anime'] as List?) ?? const [];
      return list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return (
          relation: (m['relation_type'] as String?) ?? 'other',
          node: (m['node'] as Map).cast<String, dynamic>(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MAL related error: $e');
      return const [];
    }
  }

  Future<double?> fetchScore(int malId) async {
    if (!isConfigured) return null;
    try {
      final res = await _gw.get(
        ApiHost.mal,
        Uri.parse('$_base/anime/$malId?fields=mean'),
        headers: {'X-MAL-CLIENT-ID': _clientId},
        cacheTtl: const Duration(hours: 12),
        maxAttempts: 1,
      );

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'MAL API: status ${res.statusCode} for anime $malId ${tr('if_it_s_a_401_403_check_your_client_id')}',
          );
        }
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['mean'] as num?)?.toDouble();
    } catch (e) {
      if (kDebugMode) debugPrint('MAL API error: $e');
      return null;
    }
  }
}

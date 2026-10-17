import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_exception.dart';
import '../../core/i18n/lang.dart';

enum ApiHost { anilist, mal, jikan }

class HostPolicy {
  const HostPolicy({
    required this.label,
    required this.minGap,
    required this.rateLimitKey,
    this.attemptTimeout = const Duration(seconds: 8),
    this.maxAttempts = 4,
  });

  final String label;

  final Duration minGap;

  final Duration attemptTimeout;

  final int maxAttempts;

  final String rateLimitKey;

  String get rateLimitMessage => tr(rateLimitKey);
}

class ApiResponse {
  const ApiResponse(
    this.statusCode,
    this.body,
    this.headers, {
    this.fromCache = false,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final bool fromCache;
}

class ApiGateway {
  ApiGateway({http.Client? client, Box<String>? cacheBox})
    : _http =
          client ??
          IOClient(
            HttpClient()
              ..connectionTimeout = const Duration(seconds: 6)
              ..idleTimeout = const Duration(seconds: 90),
          ),
      _cache = cacheBox;

  static final Map<ApiHost, HostPolicy> policies = {
    ApiHost.anilist: HostPolicy(
      label: 'AniList',
      minGap: Duration(milliseconds: 750),
      rateLimitKey: 'too_many_requests_to_anilist_try_again_in_a_few_',
    ),
    ApiHost.mal: HostPolicy(
      label: 'MAL',
      minGap: Duration(milliseconds: 400),
      maxAttempts: 3,
      rateLimitKey: 'too_many_requests_to_myanimelist_try_again_in_a_',
    ),
    ApiHost.jikan: HostPolicy(
      label: 'Jikan',
      minGap: Duration(milliseconds: 1100),
      maxAttempts: 3,
      rateLimitKey: 'too_many_requests_to_jikan_try_again_in_a_few_mi',
    ),
  };

  final http.Client _http;
  final Box<String>? _cache;
  final Map<ApiHost, Future<void>> _tails = {};
  final Map<ApiHost, DateTime> _last = {};
  final Random _rng = Random();

  Future<ApiResponse> get(
    ApiHost host,
    Uri url, {
    Map<String, String>? headers,
    Duration? cacheTtl,
    int? maxAttempts,
  }) => _request(
    host,
    'GET',
    url,
    headers: headers,
    cacheTtl: cacheTtl,
    maxAttempts: maxAttempts,
  );

  Future<ApiResponse> post(
    ApiHost host,
    Uri url, {
    Map<String, String>? headers,
    String? body,
    Duration? cacheTtl,
    int? maxAttempts,
  }) => _request(
    host,
    'POST',
    url,
    headers: headers,
    body: body,
    cacheTtl: cacheTtl,
    maxAttempts: maxAttempts,
  );

  Future<ApiResponse> _request(
    ApiHost host,
    String method,
    Uri url, {
    Map<String, String>? headers,
    String? body,
    Duration? cacheTtl,
    int? maxAttempts,
  }) async {
    String? key;
    if (cacheTtl != null) {
      key = _cacheKey(host, method, url, body);
      final hit = _readCache(key, cacheTtl);
      if (hit != null) return hit;
    }

    final res = await _enqueue(
      host,
      () => _execute(host, method, url, headers, body, maxAttempts),
    );

    if (key != null &&
        res.statusCode == 200 &&
        !res.body.contains('"errors"')) {
      await _writeCache(key, res);
    }
    return res;
  }

  Future<T> _enqueue<T>(ApiHost host, Future<T> Function() task) {
    final completer = Completer<T>();
    final previous = _tails[host] ?? Future<void>.value();
    _tails[host] = previous.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<ApiResponse> _execute(
    ApiHost host,
    String method,
    Uri url,
    Map<String, String>? headers,
    String? body,
    int? maxAttemptsOverride,
  ) async {
    final p = policies[host]!;
    final attempts = maxAttemptsOverride ?? p.maxAttempts;
    final sw = Stopwatch()..start();

    for (var attempt = 1; attempt <= attempts; attempt++) {
      final isLast = attempt == attempts;

      await _respectGap(host, p);
      _last[host] = DateTime.now();

      final http.Response res;
      try {
        final future = method == 'POST'
            ? _http.post(url, headers: headers, body: body)
            : _http.get(url, headers: headers);
        res = await future.timeout(p.attemptTimeout);
      } catch (e) {
        final retryable =
            e is TimeoutException ||
            e is IOException ||
            e is http.ClientException;
        if (!retryable || isLast) {
          _log(
            '${p.label} FAILED (${e.runtimeType}) after ${sw.elapsedMilliseconds}ms',
          );
          rethrow;
        }
        _log(
          '${p.label} attempt $attempt/$attempts failed (${e.runtimeType}), retrying',
        );
        await Future.delayed(_backoff(attempt));
        continue;
      }
      _last[host] = DateTime.now();

      if (res.statusCode == 429 || res.statusCode >= 500) {
        if (isLast) {
          if (res.statusCode == 429) throw ApiException(p.rateLimitMessage);
          return _toResponse(res);
        }
        final Duration delay;
        if (res.statusCode == 429) {
          final retryAfter =
              int.tryParse(res.headers['retry-after'] ?? '') ?? 20;
          // Capped at 12s so the UI never hangs for a minute on a 429.
          delay = Duration(seconds: retryAfter.clamp(1, 12).toInt());
        } else {
          delay = _backoff(attempt);
        }
        _log(
          '${p.label} HTTP ${res.statusCode}, waiting ${delay.inSeconds}s (attempt $attempt/$attempts)',
        );
        await Future.delayed(delay);
        continue;
      }

      _log(
        '${p.label} HTTP ${res.statusCode} in ${sw.elapsedMilliseconds}ms (attempt $attempt)',
      );
      return _toResponse(res);
    }
    throw ApiException(tr('couldn_t_fetch_data_from', [p.label]));
  }

  ApiResponse _toResponse(http.Response res) => ApiResponse(
    res.statusCode,
    utf8.decode(res.bodyBytes, allowMalformed: true),
    res.headers,
  );

  Future<void> _respectGap(ApiHost host, HostPolicy p) async {
    final last = _last[host];
    if (last == null) return;
    final wait = p.minGap - DateTime.now().difference(last);
    if (wait > Duration.zero) await Future.delayed(wait);
  }

  Duration _backoff(int attempt) {
    final ms = 400 * (1 << (attempt - 1)) + _rng.nextInt(250);
    return Duration(milliseconds: ms > 4000 ? 4000 : ms);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[API] $message');
  }

  static const Duration _cacheMaxAge = Duration(days: 14);
  static const int _cacheMaxEntries = 400;

  String _cacheKey(ApiHost host, String method, Uri url, String? body) {
    final s = '$url|${body ?? ''}';
    return '${host.name}:$method:${_fnv(s, 0x811C9DC5)}${_fnv(s, 0x9747B28C)}';
  }

  static String _fnv(String s, int seed) {
    var h = seed;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  ApiResponse? _readCache(String key, Duration ttl) {
    final box = _cache;
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      final t = DateTime.fromMillisecondsSinceEpoch(m['t'] as int);
      if (DateTime.now().difference(t) > ttl) return null;
      return ApiResponse(
        m['s'] as int,
        m['b'] as String,
        const {},
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, ApiResponse res) async {
    final box = _cache;
    if (box == null) return;
    try {
      await box.put(
        key,
        jsonEncode({
          't': DateTime.now().millisecondsSinceEpoch,
          's': res.statusCode,
          'b': res.body,
        }),
      );
    } catch (_) {}
  }

  static Future<void> pruneCache(Box<String> box) async {
    try {
      final now = DateTime.now();
      final entries = <MapEntry<dynamic, int>>[];
      final remove = <dynamic>[];
      for (final key in box.keys) {
        try {
          final m = jsonDecode(box.get(key)!) as Map;
          final t = m['t'] as int;
          if (now.difference(DateTime.fromMillisecondsSinceEpoch(t)) >
              _cacheMaxAge) {
            remove.add(key);
          } else {
            entries.add(MapEntry(key, t));
          }
        } catch (_) {
          remove.add(key);
        }
      }
      if (entries.length > _cacheMaxEntries) {
        entries.sort((a, b) => a.value.compareTo(b.value));
        final extra = entries.length - _cacheMaxEntries;
        remove.addAll(entries.take(extra).map((e) => e.key));
      }
      if (remove.isNotEmpty) await box.deleteAll(remove);
    } catch (_) {}
  }
}

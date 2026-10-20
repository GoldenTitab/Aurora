import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

import '../remote/anilist_client.dart';
import '../remote/api_gateway.dart';
import '../remote/jikan_client.dart';
import '../remote/mal_client.dart';
import '../repository/franchise_repository.dart';
import '../storage/migrations.dart' show Boxes;
import '../storage/user_extras.dart';
import '../storage/watch_storage.dart';

final apiGatewayProvider = Provider<ApiGateway>((ref) {
  return ApiGateway(
    cacheBox: Hive.isBoxOpen(Boxes.apiCache)
        ? Hive.box<String>(Boxes.apiCache)
        : null,
  );
});

final anilistClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(ref.watch(apiGatewayProvider)),
);
final jikanClientProvider = Provider<JikanClient>(
  (ref) => JikanClient(ref.watch(apiGatewayProvider)),
);
final malClientProvider = Provider<MalClient>(
  (ref) => MalClient(ref.watch(apiGatewayProvider)),
);

final franchiseCacheVersionProvider = StateProvider<int>((ref) => 0);

class DataSaverNotifier extends Notifier<bool> {
  static const _key = 'data_saver';

  @override
  bool build() => Hive.box<String>(Boxes.meta).get(_key) == '1';

  Future<void> set(bool v) async {
    await Hive.box<String>(Boxes.meta).put(_key, v ? '1' : '0');
    state = v;
  }
}

final dataSaverProvider = NotifierProvider<DataSaverNotifier, bool>(
  DataSaverNotifier.new,
);

class SearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'search_history';
  static const _max = 10;

  @override
  List<String> build() {
    final raw = Hive.box<String>(Boxes.meta).get(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.take(_max).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> push(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    final next = <String>[q];
    for (final e in state) {
      if (e != q) next.add(e);
    }
    state = next.take(_max).toList();
    try {
      await Hive.box<String>(Boxes.meta).put(_key, jsonEncode(state));
    } catch (_) {}
  }

  Future<void> clear() async {
    state = const [];
    try {
      await Hive.box<String>(Boxes.meta).delete(_key);
    } catch (_) {}
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );

final franchiseRepositoryProvider = Provider<FranchiseRepository>((ref) {
  return FranchiseRepository(
    ref.watch(anilistClientProvider),
    ref.watch(jikanClientProvider),
    ref.watch(malClientProvider),
    Hive.box<String>('franchise_cache'),
    onChanged: () {
      try {
        ref.read(franchiseCacheVersionProvider.notifier).state++;
      } catch (_) {}
    },
  );
});

final watchStorageProvider = Provider<WatchStorage>((ref) {
  return WatchStorage(Hive.box<String>('watch_status'));
});

final userExtrasProvider = Provider<UserExtras>((ref) {
  return UserExtras(Hive.box<String>(Boxes.meta));
});

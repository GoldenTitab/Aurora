import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

final franchiseRepositoryProvider = Provider<FranchiseRepository>((ref) {
  return FranchiseRepository(
    ref.watch(anilistClientProvider),
    ref.watch(jikanClientProvider),
    ref.watch(malClientProvider),
    Hive.box<String>('franchise_cache'),
  );
});

final watchStorageProvider = Provider<WatchStorage>((ref) {
  return WatchStorage(Hive.box<String>('watch_status'));
});

final userExtrasProvider = Provider<UserExtras>((ref) {
  return UserExtras(Hive.box<String>(Boxes.meta));
});

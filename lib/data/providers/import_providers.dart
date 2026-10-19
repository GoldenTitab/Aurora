import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/lang.dart';
import '../repository/library_import.dart';
import 'gamification_providers.dart';
import 'mylist_providers.dart';
import 'watch_providers.dart';

class ImportState {
  final bool running;
  final String status;
  final LibraryImportResult? result;

  const ImportState({this.running = false, this.status = '', this.result});

  ImportState copyWith({
    bool? running,
    String? status,
    LibraryImportResult? result,
  }) => ImportState(
    running: running ?? this.running,
    status: status ?? this.status,
    result: result ?? this.result,
  );
}

final importProvider = NotifierProvider<ImportNotifier, ImportState>(
  ImportNotifier.new,
);

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  bool _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
  }

  Future<void> run({required bool useAnilist, required String username}) async {
    if (state.running) return;
    _cancelRequested = false;
    state = ImportState(running: true, status: tr('starting'));
    LibraryImportResult r;
    try {
      r = useAnilist
          ? await importFromAniList(
              ref,
              username,
              (s) => state = state.copyWith(status: s),
              isCancelled: () => _cancelRequested,
            )
          : await importFromMal(
              ref,
              username,
              (s) => state = state.copyWith(status: s),
              isCancelled: () => _cancelRequested,
            );
    } catch (e) {
      r = LibraryImportResult(ok: false, message: tr('error', [e]));
    }
    state = ImportState(result: r);
    if (r.ok) {
      ref.invalidate(watchStatusProvider);
      ref.invalidate(episodeProgressProvider);
      ref.invalidate(myListFranchisesProvider);
      unawaited(ref.read(achievementsProvider.notifier).evaluate());
    }
  }

  void reset() => state = const ImportState();
}

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/data/database/app_database.dart';
import 'package:text_to_voice/data/providers.dart' show documentRepositoryProvider;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/presentation/settings/theme_mode_provider.dart';

/// The picker used to be session-only, so choosing "Tối" and reopening the app
/// silently put the user back on "Theo hệ thống". These tests pin the promise
/// the tile now makes: the choice is on disk, and a fresh launch reads it.
void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DocumentRepository(db);
  });

  tearDown(() async => db.close());

  /// A container over the same database — the app being reopened.
  ProviderContainer container() => ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(repo)],
      );

  /// Lets the one-shot restore read finish.
  ///
  /// Several turns rather than one: the restore chains a provider read and a
  /// database query, and a single turn would make this test pass or fail on how
  /// many microtasks drift happens to need today.
  Future<void> settleRestore() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Creates the provider (which is what schedules the restore read) and waits
  /// for the restored value to land.
  Future<ThemeMode> launch(ProviderContainer scope) async {
    scope.read(themeModeProvider);
    await settleRestore();
    return scope.read(themeModeProvider);
  }

  test('a cold start defaults to the system theme', () async {
    final scope = container();
    addTearDown(scope.dispose);

    expect(await launch(scope), ThemeMode.system);
  });

  test('the choice is written to the settings table', () async {
    final scope = container();
    addTearDown(scope.dispose);

    scope.read(themeModeProvider.notifier).select(ThemeMode.dark);
    await settleRestore();

    expect(scope.read(themeModeProvider), ThemeMode.dark);
    expect(await repo.getSetting(ThemeModeNotifier.settingKey), 'dark');
  });

  test('the next launch restores the stored choice', () async {
    final first = container();
    first.read(themeModeProvider.notifier).select(ThemeMode.light);
    await settleRestore();
    first.dispose();

    // A new container over the same database: the app was restarted.
    final second = container();
    addTearDown(second.dispose);

    expect(await launch(second), ThemeMode.light);
  });

  test('an unknown stored value falls back instead of throwing', () async {
    await repo.setSetting(ThemeModeNotifier.settingKey, 'sepia');

    final scope = container();
    addTearDown(scope.dispose);

    expect(await launch(scope), ThemeMode.system);
  });
}

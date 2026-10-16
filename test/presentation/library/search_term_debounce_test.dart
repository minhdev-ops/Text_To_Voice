import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/presentation/library/library_providers.dart';

/// The debounce is the point: `onChanged` fires per keystroke and each firing
/// used to run a full-text scan, so what matters is that a burst of typing
/// produces one committed term rather than one per letter.
void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  tearDown(() {});

  test('a burst of keystrokes commits only the last one', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final term = container.read(librarySearchTermProvider.notifier);

    term.update('m');
    term.update('ma');
    term.update('má');
    term.update('máy');

    // Nothing yet: the term has not settled.
    expect(container.read(librarySearchTermProvider), '');

    // Longer than the debounce window, so the timer has fired.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(container.read(librarySearchTermProvider), 'máy');
  });

  test('a pause longer than the window commits mid-word', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final term = container.read(librarySearchTermProvider.notifier);

    term.update('máy');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(container.read(librarySearchTermProvider), 'máy');
  });

  test('commit applies at once, for the keyboard search action', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final term = container.read(librarySearchTermProvider.notifier);

    term.update('máy học');
    term.commit('máy học');

    // No wait: the user pressed the search key.
    expect(container.read(librarySearchTermProvider), 'máy học');

    // And a pending timer from `update` must not overwrite it afterwards.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(librarySearchTermProvider), 'máy học');
  });

  test('commit with an empty term clears the search', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final term = container.read(librarySearchTermProvider.notifier);

    term.commit('bảo mật');
    expect(container.read(librarySearchTermProvider), 'bảo mật');

    term.commit('');
    expect(container.read(librarySearchTermProvider), '');
  });

  test('the timer does not fire after the container is disposed', () async {
    final container = makeContainer();
    container.read(librarySearchTermProvider.notifier).update('máy');
    container.dispose();

    // A Timer firing into a disposed provider throws. Waiting past the window is
    // the assertion: reaching here without an unhandled error is the pass.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
}

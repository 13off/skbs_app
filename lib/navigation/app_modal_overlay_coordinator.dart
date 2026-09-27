import 'dart:async';

class AppModalOverlayCoordinator {
  AppModalOverlayCoordinator._();

  static final Set<Object> _blockers = <Object>{};
  static final List<Completer<void>> _waiters = <Completer<void>>[];

  static bool get hasBlockingOverlay => _blockers.isNotEmpty;

  static void begin(Object token) {
    _blockers.add(token);
  }

  static void end(Object token) {
    _blockers.remove(token);
    if (_blockers.isNotEmpty || _waiters.isEmpty) return;

    final pending = List<Completer<void>>.from(_waiters);
    _waiters.clear();
    for (final waiter in pending) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  static Future<void> waitUntilUnblocked() async {
    if (!hasBlockingOverlay) return;
    final completer = Completer<void>();
    _waiters.add(completer);
    if (!hasBlockingOverlay && !completer.isCompleted) {
      _waiters.remove(completer);
      completer.complete();
    }
    await completer.future;
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRM stages are always normalized to ascending sort order', () {
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(repository, contains(".order('sort_order', ascending: true)"));
    expect(repository, contains('first.sortOrder.compareTo(second.sortOrder)'));
    expect(board, contains('final base = List<RecruitmentPipelineStage>.from'));
    expect(board, contains('first.sortOrder.compareTo(second.sortOrder)'));
  });

  test('candidate movement has one final refresh without realtime races', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(board, contains('movingIds.isEmpty'));
    expect(board, contains('archiveBusyIds.isEmpty'));
    expect(board, contains('var saved = false;'));
    expect(board, contains('if (saved) await refresh();'));

    final moveStart = board.indexOf('  Future<void> moveToStage(');
    final moveEnd = board.indexOf('  Widget filterChip(', moveStart);
    final moveBlock = board.substring(moveStart, moveEnd);
    expect(
      moveBlock.indexOf('await runAutomations('),
      lessThan(moveBlock.indexOf('if (saved) await refresh();')),
    );
  });
}

from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def replace_between(
    text: str,
    start: str,
    end: str,
    replacement: str,
    label: str,
) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"{label}: start marker not found")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f"{label}: end marker not found")
    return text[:start_index] + replacement + text[end_index:]


repository_path = Path("lib/features/recruitment/data/recruitment_repository.dart")
repository = repository_path.read_text(encoding="utf-8")
repository = repository.replace(
    ".order('sort_order')\n          .order('created_at')",
    ".order('sort_order', ascending: true)\n"
    "          .order('created_at', ascending: true)",
)
if repository.count(".order('sort_order', ascending: true)") < 2:
    raise SystemExit("explicit ascending order was not applied to both CRM queries")

old_stage_block = """    final stages = (results[0] as List<dynamic>)
        .map((value) => RecruitmentPipelineStage.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList();
"""
new_stage_block = """    final stages = (results[0] as List<dynamic>)
        .map((value) => RecruitmentPipelineStage.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList()
      ..sort((first, second) {
        final byOrder = first.sortOrder.compareTo(second.sortOrder);
        if (byOrder != 0) return byOrder;
        return first.id.compareTo(second.id);
      });
"""
repository = replace_once(repository, old_stage_block, new_stage_block, "stage sorting")

old_field_block = """    final fields = (results[1] as List<dynamic>)
        .map((value) => RecruitmentCustomField.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList();
"""
new_field_block = """    final fields = (results[1] as List<dynamic>)
        .map((value) => RecruitmentCustomField.fromMap(_map(value)))
        .where((item) => item.id.isNotEmpty)
        .where((item) => includeInactive || item.isActive)
        .toList()
      ..sort((first, second) {
        final byOrder = first.sortOrder.compareTo(second.sortOrder);
        if (byOrder != 0) return byOrder;
        return first.id.compareTo(second.id);
      });
"""
repository = replace_once(repository, old_field_block, new_field_block, "field sorting")
repository_path.write_text(repository, encoding="utf-8")

board_path = Path(
    "lib/features/recruitment/presentation/recruitment_applications_screen.dart"
)
board = board_path.read_text(encoding="utf-8")

old_listener = """    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) &&
mounted &&
!stageMutationBusy) {
        refresh();
      }
    });
"""
new_listener = """    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) &&
          mounted &&
          !stageMutationBusy &&
          movingIds.isEmpty &&
          archiveBusyIds.isEmpty) {
        refresh();
      }
    });
"""
board = replace_once(board, old_listener, new_listener, "realtime listener")

new_ordered_stages = """  List<RecruitmentPipelineStage> orderedStages(
    RecruitmentCrmConfiguration configuration,
  ) {
    final base = List<RecruitmentPipelineStage>.from(configuration.stages)
      ..sort((first, second) {
        final byOrder = first.sortOrder.compareTo(second.sortOrder);
        if (byOrder != 0) return byOrder;
        return first.id.compareTo(second.id);
      });
    final order = pendingStageOrder;
    if (order == null ||
        order.length != base.length ||
        order.toSet().length != base.length) {
      return base;
    }
    final byId = <String, RecruitmentPipelineStage>{
      for (final stage in base) stage.id: stage,
    };
    if (order.any((id) => !byId.containsKey(id))) return base;
    return order.map((id) => byId[id]!).toList(growable: false);
  }

"""
board = replace_between(
    board,
    "  List<RecruitmentPipelineStage> orderedStages(",
    "  String formatDate(",
    new_ordered_stages,
    "orderedStages",
)

new_move_to_stage = """  Future<void> moveToStage(
    RecruitmentApplication application,
    RecruitmentPipelineStage stage,
  ) async {
    final currentStageId =
        pendingStageIds[application.id] ?? application.stageId;
    if (currentStageId == stage.id || movingIds.contains(application.id)) {
      return;
    }
    setState(() {
      movingIds.add(application.id);
      pendingStageIds[application.id] = stage.id;
      draggingApplicationId = null;
    });
    var saved = false;
    try {
      await RecruitmentRepository.moveApplicationStage(
        applicationId: application.id,
        stageId: stage.id,
      );
      saved = true;
      await runAutomations(<String>[application.id]);
    } catch (error) {
      if (!mounted) return;
      setState(() => pendingStageIds.remove(application.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить этап: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          movingIds.remove(application.id);
          pendingStageIds.remove(application.id);
        });
        if (saved) await refresh();
      }
    }
  }

"""
board = replace_between(
    board,
    "  Future<void> moveToStage(",
    "  Widget filterChip(",
    new_move_to_stage,
    "moveToStage",
)
board_path.write_text(board, encoding="utf-8")

test_path = Path("test/recruitment_board_stability_contract_test.dart")
test_path.write_text(
    """import 'dart:io';

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
""",
    encoding="utf-8",
)

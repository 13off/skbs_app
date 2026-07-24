from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, got {count}')
    return text.replace(old, new, 1)


screen_path = Path(
    'lib/features/recruitment/presentation/recruitment_applications_screen.dart'
)
text = screen_path.read_text(encoding='utf-8')

text = replace_once(
    text,
    "  final Set<String> selectedIds = <String>{};\n"
    "  String? draggingApplicationId;\n"
    "  String? draggingStageId;\n"
    "  List<String>? pendingStageOrder;",
    "  final Set<String> selectedIds = <String>{};\n"
    "  final ScrollController boardScrollController = ScrollController();\n"
    "  String? draggingApplicationId;\n"
    "  List<String>? pendingStageOrder;",
    'state fields',
)
text = replace_once(
    text,
    "    changesSubscription?.cancel();\n    searchController",
    "    changesSubscription?.cancel();\n"
    "    boardScrollController.dispose();\n"
    "    searchController",
    'dispose board controller',
)

create_start = text.index('  Future<void> createStage(')
create_end = text.index('  Future<void> renameStage(', create_start)
create_block = '''  Future<void> createStage(RecruitmentCrmConfiguration configuration) async {
    if (stageMutationBusy) return;
    final title = await requestStageTitle(
      dialogTitle: 'Новая колонка',
      actionLabel: 'Добавить',
    );
    if (title == null || !mounted) return;
    setState(() => stageMutationBusy = true);
    try {
      final created = await RecruitmentRepository.createPipelineStageAtEnd(
        companyId: widget.profile.activeCompanyId,
        title: title,
        description: '',
        colorHex: defaultStageColor(configuration.stages.length),
        legacyStatus: 'new',
        isFinal: false,
      );
      final liveConfiguration = await RecruitmentRepository.fetchConfiguration(
        companyId: widget.profile.activeCompanyId,
      );
      final requestedIds = <String>[
        ...liveConfiguration.stages
            .where((stage) => stage.id != created.id)
            .map((stage) => stage.id),
        created.id,
      ];
      final confirmedIds = await RecruitmentRepository.reorderPipelineStages(
        companyId: widget.profile.activeCompanyId,
        orderedIds: requestedIds,
      );
      if (confirmedIds.join('|') != requestedIds.join('|')) {
        throw Exception('Сервер не поставил новую колонку последней');
      }
      if (mounted) setState(() => pendingStageOrder = confirmedIds);
      await refresh();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !boardScrollController.hasClients) return;
        boardScrollController.animateTo(
          boardScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Колонка «$title» добавлена справа')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить колонку: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          stageMutationBusy = false;
          pendingStageOrder = null;
        });
      }
    }
  }

'''
text = text[:create_start] + create_block + text[create_end:]

reorder_start = text.index('  Future<void> reorderStageOnBoard(')
reorder_end = text.index('  Future<void> moveToStage(', reorder_start)
reorder_block = '''  Future<void> showStageOrderDialog(
    RecruitmentCrmConfiguration configuration,
  ) async {
    if (stageMutationBusy) return;
    final initial = orderedStages(configuration);
    if (initial.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для изменения порядка нужно две колонки')),
      );
      return;
    }
    final draft = List<RecruitmentPipelineStage>.from(initial);
    final orderedIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Порядок колонок'),
          content: SizedBox(
            width: 460,
            height: 420,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: draft.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                if (newIndex == oldIndex) return;
                setDialogState(() {
                  final item = draft.removeAt(oldIndex);
                  draft.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final stage = draft[index];
                return Card(
                  key: ValueKey<String>(stage.id),
                  margin: const EdgeInsets.only(bottom: AppUi.gap8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: stageColor(stage),
                      ),
                    ),
                    title: Text(
                      stage.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('Позиция ${index + 1}'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                draft.map((stage) => stage.id).toList(growable: false),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (orderedIds == null || !mounted) return;
    final initialIds = initial.map((stage) => stage.id).toList(growable: false);
    if (orderedIds.join('|') == initialIds.join('|')) return;

    setState(() {
      stageMutationBusy = true;
      pendingStageOrder = orderedIds;
    });
    try {
      final confirmedIds = await RecruitmentRepository.reorderPipelineStages(
        companyId: widget.profile.activeCompanyId,
        orderedIds: orderedIds,
      );
      if (confirmedIds.join('|') != orderedIds.join('|')) {
        throw Exception('Сервер сохранил другой порядок колонок');
      }
      if (mounted) setState(() => pendingStageOrder = confirmedIds);
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Порядок колонок сохранён')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить порядок колонок: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          stageMutationBusy = false;
          pendingStageOrder = null;
        });
      }
    }
  }

'''
text = text[:reorder_start] + reorder_block + text[reorder_end:]

handle_start = text.index('  Widget stageDragHandle(')
handle_end = text.index('  Widget kanbanColumn(', handle_start)
handle_block = '''  Widget stageOrderButton(RecruitmentCrmConfiguration configuration) {
    return IconButton(
      tooltip: 'Изменить порядок колонок',
      onPressed: stageMutationBusy
          ? null
          : () => showStageOrderDialog(configuration),
      icon: Icon(Icons.drag_indicator_rounded, size: 20, color: _muted),
    );
  }

'''
text = text[:handle_start] + handle_block + text[handle_end:]

text = replace_once(
    text,
    "    return DragTarget<RecruitmentPipelineStage>(\n"
    "      onWillAcceptWithDetails: (details) =>\n"
    "          canConfigureCrm && !stageMutationBusy && details.data.id != stage.id,\n"
    "      onAcceptWithDetails: (details) =>\n"
    "          reorderStageOnBoard(configuration, details.data, stage),\n"
    "      builder: (context, stageCandidates, rejectedStages) {\n"
    "        final stageHighlighted = stageCandidates.isNotEmpty;",
    "    return Builder(\n"
    "      builder: (context) {\n"
    "        const stageHighlighted = false;",
    'separate column and candidate drag targets',
)
text = replace_once(
    text,
    'if (canConfigureCrm) stageDragHandle(stage)',
    'if (canConfigureCrm) stageOrderButton(configuration)',
    'stage order button call',
)
text = replace_once(
    text,
    "    return SingleChildScrollView(\n"
    "      scrollDirection: Axis.horizontal,\n"
    "      padding: const EdgeInsets.only(bottom: AppUi.gap8),\n"
    "      child: Row(\n"
    "        crossAxisAlignment: CrossAxisAlignment.start,",
    "    return SingleChildScrollView(\n"
    "      controller: boardScrollController,\n"
    "      scrollDirection: Axis.horizontal,\n"
    "      reverse: false,\n"
    "      padding: const EdgeInsets.only(bottom: AppUi.gap8),\n"
    "      child: Row(\n"
    "        textDirection: TextDirection.ltr,\n"
    "        crossAxisAlignment: CrossAxisAlignment.start,",
    'explicit board direction',
)

screen_path.write_text(text, encoding='utf-8')

contract_path = Path('test/recruitment_column_management_contract_test.dart')
contract = contract_path.read_text(encoding='utf-8')
contract = replace_once(
    contract,
    "    expect(board, contains('createPipelineStageAtEnd('));\n"
    "    expect(board, contains('добавлена справа'));",
    "    expect(board, contains('createPipelineStageAtEnd('));\n"
    "    expect(board, contains('final liveConfiguration = await'));\n"
    "    expect(board, contains('orderedIds: requestedIds'));\n"
    "    expect(board, contains('добавлена справа'));",
    'creation contract',
)
test_start = contract.index("  test('column drag persists the exact server-confirmed order'")
test_end = contract.index("  test('column deletion safely moves candidates", test_start)
new_test = '''  test('column order changes only in an explicit reorder dialog', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724180000_fix_recruitment_column_order.sql',
    ).readAsStringSync();

    expect(board, contains('Future<void> showStageOrderDialog('));
    expect(board, contains('ReorderableListView.builder'));
    expect(board, contains('buildDefaultDragHandles: false'));
    expect(board, contains('stageOrderButton(configuration)'));
    expect(board, contains('controller: boardScrollController'));
    expect(board, contains('textDirection: TextDirection.ltr'));
    expect(board, contains('DragTarget<RecruitmentApplication>'));
    expect(board, isNot(contains('DragTarget<RecruitmentPipelineStage>')));
    expect(board, isNot(contains('Draggable<RecruitmentPipelineStage>')));
    expect(settings, contains('ReorderableListView.builder'));
    expect(repository, contains("'reorder_recruitment_pipeline_stages_v2'"));
    expect(migration, contains('reorder_recruitment_pipeline_stages_v2'));
    expect(migration, contains('revoke all on function'));
  });

'''
contract = contract[:test_start] + new_test + contract[test_end:]
contract_path.write_text(contract, encoding='utf-8')

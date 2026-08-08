// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../home_screen.dart';

extension _HomeActions on _HomeScreenState {
  Future<void> openVoiceTaskFromHome() async {
    final objectName = cleanObjectName(widget.selectedObjectName);
    if (objectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите конкретный объект на Главной'),
        ),
      );
      return;
    }

    if (!TaskEditPolicy.canCreateForDate(widget.profile, AppState.today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('По правилам объекта сейчас нельзя создать задачу'),
        ),
      );
      return;
    }

    final draft = await Navigator.push<TaskCreateDraft>(
      context,
      CupertinoPageRoute<TaskCreateDraft>(
        builder: (_) => AddTaskScreen(
          initialDate: AppState.today,
          objectName: objectName,
          allowAnyDate:
              widget.profile.isAdmin ||
              TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,
          allowDraft: widget.profile.isForeman,
          startVoiceImmediately: true,
        ),
      ),
    );
    if (draft == null) return;

    try {
      if (draft.saveAsDraft) {
        await TaskRepository.saveTaskDraftWithDetails(
          draft.task,
          objectName: objectName,
          assigneeIds: draft.assigneeIds,
          sourceDraftId: draft.sourceDraftId,
        );
      } else {
        await TaskRepository.addTaskWithDetails(
          draft.task,
          objectName: objectName,
          assigneeIds: draft.assigneeIds,
          photos: draft.photos,
        );
      }
      if (!mounted) return;
      setState(() {
        dashboardFuture = loadDashboardData(forceRefresh: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.saveAsDraft
                ? 'Черновик задачи сохранён'
                : 'Задача сохранена',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить задачу: $error')),
      );
    }
  }

  Future<void> showFinancePeriodPicker(BuildContext context) async {
    if (!widget.profile.isAdmin) return;

    final periods = <FinancePeriod>[
      const FinancePeriod.allTime(),
      ...FinancePeriod.recentMonths(AppState.today, count: 18),
    ];

    final picked = await showModalBottomSheet<FinancePeriod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Период выплат',
                        style: TextStyle(
                          color: _text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: periods.length,
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final isSelected = isSameFinancePeriod(
                        period,
                        financePeriod,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(sheetContext, period),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? _softCard : _card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? _accent : _line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  period.isAllTime
                                      ? Icons.all_inclusive
                                      : Icons.calendar_month_outlined,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    period.pickerTitle(),
                                    style: TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: _accent),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || isSameFinancePeriod(picked, financePeriod)) return;
    setState(() {
      financePeriod = picked;
      dashboardFuture = loadDashboardData();
    });
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_cache_coordinator.dart';
import '../../../data/app_data_sync.dart';
import '../../../data/object_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/executive_panel_repository.dart';
import '../data/executive_payment_summary_exporter.dart';

class ExecutiveMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ExecutiveMainScreen({super.key, required this.profile});

  @override
  State<ExecutiveMainScreen> createState() => _ExecutiveMainScreenState();
}

class _ExecutiveMainScreenState extends State<ExecutiveMainScreen>
    with WidgetsBindingObserver {
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabs = PersistentTabController(pageCount: 2);
    _startDataSync();
  }

  @override
  void didUpdateWidget(covariant ExecutiveMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);
      _startDataSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppDataSync.refreshAll();
  }

  void _startDataSync() {
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: AppCacheCoordinator.invalidate,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'executive',
      returnToFirstTabOnBack: true,
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Чат',
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Оплата',
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments_rounded,
        ),
      ],
      tabBuilder: (context, index) {
        return switch (index) {
          0 => _ExecutiveChatScreen(
            companyId: widget.profile.activeCompanyId,
          ),
          1 => const _ExecutivePaymentsScreen(),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _ExecutiveChatScreen extends StatefulWidget {
  final String companyId;

  const _ExecutiveChatScreen({required this.companyId});

  @override
  State<_ExecutiveChatScreen> createState() => _ExecutiveChatScreenState();
}

class _ExecutiveChatScreenState extends State<_ExecutiveChatScreen> {
  late DateTimeRange period;
  StreamSubscription<AppDataChange>? dataChanges;
  String? selectedObjectName;
  List<String> objectNames = const <String>[];
  Set<String> archivedObjectNames = const <String>{};
  List<ExecutiveTaskMessage> messages = const <ExecutiveTaskMessage>[];
  bool onlyUnfinished = false;
  bool isLoading = false;
  String? errorText;
  int loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    period = DateTimeRange(start: today, end: today);
    dataChanges = AppDataSync.changes.listen(_handleDataChange);
    unawaited(_load());
  }

  @override
  void dispose() {
    dataChanges?.cancel();
    super.dispose();
  }

  void _handleDataChange(AppDataChange change) {
    if (!mounted ||
        !change.affectsAny(const <AppDataDomain>{
          AppDataDomain.tasks,
          AppDataDomain.objects,
        })) {
      return;
    }
    unawaited(_load(forceObjects: change.affects(AppDataDomain.objects)));
  }

  Future<void> _load({bool forceObjects = false}) async {
    final generation = ++loadGeneration;
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await Future.wait<dynamic>([
        ObjectRepository.fetchObjectNames(forceRefresh: forceObjects),
        ObjectRepository.fetchArchivedObjectNames(
          forceRefresh: forceObjects,
        ),
        ExecutivePanelRepository.fetchTaskMessages(
          companyId: widget.companyId,
          startDate: period.start,
          endDate: period.end,
          objectName: selectedObjectName,
        ),
      ]);
      if (!mounted || generation != loadGeneration) return;
      final nextArchivedObjectNames =
          (result[1] as List<String>).toSet();
      final nextObjectNames = <String>{
        ...(result[0] as List<String>),
        ...nextArchivedObjectNames,
      }.toList()
        ..sort();
      final nextMessages = result[2] as List<ExecutiveTaskMessage>;
      final objectSelectionBecameInvalid =
          selectedObjectName != null &&
          !nextObjectNames.contains(selectedObjectName);
      setState(() {
        objectNames = nextObjectNames;
        archivedObjectNames = nextArchivedObjectNames;
        if (objectSelectionBecameInvalid) selectedObjectName = null;
        messages = nextMessages;
      });
      if (objectSelectionBecameInvalid) unawaited(_load());
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        errorText = 'Не удалось загрузить задачи: $error';
      });
    } finally {
      if (mounted && generation == loadGeneration) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isCompleted(ExecutiveTaskMessage message) =>
      message.status.trim().toLowerCase() == 'выполнено';

  List<ExecutiveTaskMessage> get _visibleMessages {
    if (!onlyUnfinished) return messages;
    return messages
        .where((message) => !_isCompleted(message))
        .toList(growable: false);
  }

  Future<void> _copyAllMessages(
    List<ExecutiveTaskMessage> visibleMessages,
  ) async {
    if (visibleMessages.isEmpty) return;
    final lines = <String>[
      'Задачи · ${selectedObjectName ?? 'Все объекты'} · ${_formatRange(period)}',
      '',
    ];
    for (var index = 0; index < visibleMessages.length; index++) {
      final message = visibleMessages[index];
      final metadata = <String>[
        _formatDate(message.date),
        _formatTime(message.createdAt),
        if (selectedObjectName == null && message.objectName.trim().isNotEmpty)
          message.objectName.trim(),
        if (message.creatorName.trim().isNotEmpty) message.creatorName.trim(),
      ].join(' · ');
      lines
        ..add(metadata)
        ..add(
          message.text.trim().isEmpty
              ? 'Задача без описания'
              : message.text.trim(),
        );
      if (message.mediaCount > 0) {
        lines.add('Фото/видео: ${message.mediaCount}');
      }
      if (index != visibleMessages.length - 1) lines.add('');
    }

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Все задачи скопированы')),
    );
  }

  bool _periodMatches(DateTime start, DateTime end) {
    return _dateOnly(period.start) == _dateOnly(start) &&
        _dateOnly(period.end) == _dateOnly(end);
  }

  Future<void> _applyQuickPeriod(DateTime start, DateTime end) async {
    final nextStart = _dateOnly(start);
    final nextEnd = _dateOnly(end);
    if (_periodMatches(nextStart, nextEnd)) return;
    setState(() {
      period = DateTimeRange(start: nextStart, end: nextEnd);
    });
    await _load();
  }

  Widget _quickPeriods() {
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Сегодня'),
          selected: _periodMatches(today, today),
          onSelected: (_) => _applyQuickPeriod(today, today),
        ),
        ChoiceChip(
          label: const Text('Вчера'),
          selected: _periodMatches(yesterday, yesterday),
          onSelected: (_) => _applyQuickPeriod(yesterday, yesterday),
        ),
        ChoiceChip(
          label: const Text('7 дней'),
          selected: _periodMatches(weekStart, today),
          onSelected: (_) => _applyQuickPeriod(weekStart, today),
        ),
        FilterChip(
          label: const Text('Незавершённые'),
          selected: onlyUnfinished,
          onSelected: (value) => setState(() => onlyUnfinished = value),
        ),
      ],
    );
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: period,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Период задач',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    setState(() {
      period = DateTimeRange(
        start: _dateOnly(picked.start),
        end: _dateOnly(picked.end),
      );
    });
    await _load();
  }

  Future<void> _changeObject(String? value) async {
    final next = value?.trim();
    final normalized = next == null || next.isEmpty ? null : next;
    if (normalized == selectedObjectName) return;
    setState(() {
      selectedObjectName = normalized;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _visibleMessages;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        title: const Text('Чат'),
        actions: [
          IconButton(
            tooltip: 'Скопировать все задачи',
            onPressed: visibleMessages.isEmpty
                ? null
                : () => _copyAllMessages(visibleMessages),
            icon: const Icon(Icons.copy_all_rounded),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: RefreshIndicator(
          onRefresh: () => _load(forceObjects: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _ExecutiveFilterBar(
                objectNames: objectNames,
                archivedObjectNames: archivedObjectNames,
                selectedObjectName: selectedObjectName,
                periodText: _formatRange(period),
                onObjectChanged: _changeObject,
                onPickPeriod: _pickPeriod,
              ),
              const SizedBox(height: 10),
              _quickPeriods(),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 14),
                _ExecutiveMessageState(
                  icon: Icons.error_outline_rounded,
                  text: errorText!,
                ),
              ] else if (!isLoading && visibleMessages.isEmpty) ...[
                const SizedBox(height: 14),
                _ExecutiveMessageState(
                  icon: Icons.forum_outlined,
                  text: onlyUnfinished && messages.isNotEmpty
                      ? 'Незавершённых задач нет'
                      : 'За выбранный период задач нет',
                ),
              ] else ...[
                const SizedBox(height: 14),
                for (final message in visibleMessages) ...[
                  _ExecutiveTaskMessageCard(
                    key: ValueKey<String>(message.id),
                    message: message,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _ExecutiveEmploymentFilter { all, active, fired }

class _ExecutivePaymentsScreen extends StatefulWidget {
  const _ExecutivePaymentsScreen();

  @override
  State<_ExecutivePaymentsScreen> createState() =>
      _ExecutivePaymentsScreenState();
}

class _ExecutivePaymentsScreenState extends State<_ExecutivePaymentsScreen> {
  final TextEditingController searchController = TextEditingController();
  final Map<String, TextEditingController> shareAmountControllers =
      <String, TextEditingController>{};

  late DateTimeRange period;
  StreamSubscription<AppDataChange>? dataChanges;
  String? selectedObjectName;
  List<String> objectNames = const <String>[];
  Set<String> archivedObjectNames = const <String>{};
  ExecutivePaymentSummary? summary;
  _ExecutiveEmploymentFilter employmentFilter =
      _ExecutiveEmploymentFilter.all;
  bool onlyDue = true;
  bool editingForShare = false;
  bool isLoading = false;
  String? errorText;
  int loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    period = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    dataChanges = AppDataSync.changes.listen(_handleDataChange);
    unawaited(_load());
  }

  @override
  void dispose() {
    dataChanges?.cancel();
    searchController.dispose();
    _disposeShareControllers();
    super.dispose();
  }

  void _disposeShareControllers() {
    for (final controller in shareAmountControllers.values) {
      controller.dispose();
    }
    shareAmountControllers.clear();
  }

  void _resetShareDraft() {
    final staleControllers = shareAmountControllers.values.toList();
    shareAmountControllers.clear();
    editingForShare = false;
    if (staleControllers.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in staleControllers) {
        controller.dispose();
      }
    });
  }

  String _rowKey(ExecutivePaymentBalance row) {
    if (row.employeeIds.isNotEmpty) return row.employeeIds.join('|');
    return row.employeeName.trim().toLowerCase();
  }

  List<ExecutivePaymentBalance> _visibleRows(ExecutivePaymentSummary? current) {
    if (current == null) return const <ExecutivePaymentBalance>[];
    final query = searchController.text.trim().toLowerCase();
    final rows = current.rows.where((row) {
      final employmentMatches = switch (employmentFilter) {
        _ExecutiveEmploymentFilter.all => true,
        _ExecutiveEmploymentFilter.active => row.isActive,
        _ExecutiveEmploymentFilter.fired => !row.isActive,
      };
      if (!employmentMatches) return false;
      if (onlyDue && row.balance <= 0.005) return false;
      if (query.isEmpty) return true;
      return row.employeeName.toLowerCase().contains(query) ||
          row.objectTitle.toLowerCase().contains(query);
    }).toList();
    rows.sort((first, second) {
      final balanceCompare = second.balance.compareTo(first.balance);
      if (balanceCompare != 0) return balanceCompare;
      return first.employeeName.compareTo(second.employeeName);
    });
    return rows;
  }

  double _actualTotal(Iterable<ExecutivePaymentBalance> rows) {
    return rows.fold<double>(
      0,
      (sum, row) => sum + (row.balance > 0 ? row.balance : 0.0),
    );
  }

  double _parseShareAmount(String value) {
    final clean = value
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(clean) ?? 0;
  }

  double _shareAmountFor(ExecutivePaymentBalance row) {
    final controller = shareAmountControllers[_rowKey(row)];
    if (controller == null) return row.balance > 0 ? row.balance : 0.0;
    return _parseShareAmount(controller.text);
  }

  double _shareTotal(Iterable<ExecutivePaymentBalance> rows) {
    return rows.fold<double>(0, (sum, row) {
      final amount = _shareAmountFor(row);
      return sum + (amount > 0 ? amount : 0.0);
    });
  }

  void _beginShareEdit() {
    final current = summary;
    if (current == null || current.rows.isEmpty) return;
    _disposeShareControllers();
    for (final row in current.rows) {
      final initial = row.balance > 0 ? row.balance.round() : 0;
      shareAmountControllers[_rowKey(row)] = TextEditingController(
        text: initial.toString(),
      );
    }
    setState(() => editingForShare = true);
  }

  void _cancelShareEdit() {
    setState(_resetShareDraft);
  }

  String get _employmentTitle => switch (employmentFilter) {
    _ExecutiveEmploymentFilter.all => 'Все сотрудники',
    _ExecutiveEmploymentFilter.active => 'Действующие',
    _ExecutiveEmploymentFilter.fired => 'Уволенные',
  };

  Future<void> _copyForShare(
    List<ExecutivePaymentBalance> rows, {
    bool groupByObject = false,
  }) async {
    final entries = <({ExecutivePaymentBalance row, double amount})>[];
    var total = 0.0;
    for (final row in rows) {
      final amount = editingForShare
          ? _shareAmountFor(row)
          : (row.balance > 0 ? row.balance : 0.0);
      if (amount <= 0.005) continue;
      total += amount;
      entries.add((row: row, amount: amount));
    }
    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет сумм для отправки')),
      );
      return;
    }

    final header =
        'Остатки · ${selectedObjectName ?? 'Все объекты'} · '
        '$_employmentTitle · ${_formatRange(period)}';
    final lines = <String>[header, ''];

    if (groupByObject && selectedObjectName == null) {
      final groups =
          <String, List<({ExecutivePaymentBalance row, double amount})>>{};
      for (final entry in entries) {
        final objectTitle = entry.row.objectTitle.trim().isEmpty
            ? 'Без объекта'
            : entry.row.objectTitle.trim();
        groups.putIfAbsent(objectTitle, () => []).add(entry);
      }
      final objectTitles = groups.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (var index = 0; index < objectTitles.length; index++) {
        final objectTitle = objectTitles[index];
        final group = groups[objectTitle]!;
        final objectTotal = group.fold<double>(
          0,
          (sum, entry) => sum + entry.amount,
        );
        lines.add(objectTitle);
        for (final entry in group) {
          lines.add(
            '${_formatMoney(entry.amount)} — ${entry.row.employeeName}',
          );
        }
        lines.add('Итого по объекту: ${_formatMoney(objectTotal)}');
        if (index != objectTitles.length - 1) lines.add('');
      }
    } else {
      for (final entry in entries) {
        final objectSuffix = selectedObjectName == null
            ? ' — ${entry.row.objectTitle}'
            : '';
        lines.add(
          '${_formatMoney(entry.amount)} — '
          '${entry.row.employeeName}$objectSuffix',
        );
      }
    }

    lines
      ..add('')
      ..add('Итого: ${_formatMoney(total)}');

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          groupByObject && selectedObjectName == null
              ? 'Список по объектам скопирован'
              : 'Список скопирован',
        ),
      ),
    );
  }

  Future<Map<String, ExecutivePaymentRequisites>>
  _loadPaymentRequisites(List<ExecutivePaymentBalance> rows) async {
    final employeeIds = rows
        .expand((row) => row.employeeIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (employeeIds.isEmpty) {
      return const <String, ExecutivePaymentRequisites>{};
    }
    return ExecutivePanelRepository.fetchPaymentRequisites(employeeIds);
  }

  Future<void> _copyPaymentRequisites(
    ExecutivePaymentBalance row,
  ) async {
    try {
      final byEmployeeId = await _loadPaymentRequisites([row]);
      final requisites = ExecutivePanelRepository.requisitesForBalance(
        row,
        byEmployeeId,
      );
      if (!requisites.hasAny) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Реквизиты не заполнены')),
        );
        return;
      }

      final lines = <String>[row.employeeName];
      if (requisites.transferPhone.trim().isNotEmpty) {
        lines.add('Телефон: ${requisites.transferPhone.trim()}');
      }
      if (requisites.bankName.trim().isNotEmpty) {
        lines.add('Банк: ${requisites.bankName.trim()}');
      }
      if (requisites.recipientName.trim().isNotEmpty) {
        lines.add('Получатель: ${requisites.recipientName.trim()}');
      }
      if (requisites.bankCard.trim().isNotEmpty) {
        lines.add('Карта: ${requisites.bankCard.trim()}');
      }

      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Реквизиты скопированы')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить реквизиты: $error')),
      );
    }
  }

  Future<List<ExecutiveExpressSummaryRow>> _buildExpressSummaryRows(
    List<ExecutivePaymentBalance> rows,
  ) async {
    final requisitesByEmployeeId = await _loadPaymentRequisites(rows);
    return rows.map((row) {
      final requisites = ExecutivePanelRepository.requisitesForBalance(
        row,
        requisitesByEmployeeId,
      );
      final amount = editingForShare
          ? _shareAmountFor(row)
          : (row.balance > 0 ? row.balance : 0.0);
      return ExecutiveExpressSummaryRow(
        employeeName: row.employeeName,
        objectTitle: row.objectTitle,
        status: row.isActive ? 'Действующий' : 'Уволен',
        shifts: row.shifts,
        accrued: row.accrued,
        paid: row.paid,
        systemBalance: row.balance,
        amountToPay: amount > 0 ? amount : 0.0,
        transferPhone: requisites.transferPhone,
        bankName: requisites.bankName,
        recipientName: requisites.recipientName,
        bankCard: requisites.bankCard,
      );
    }).toList(growable: false);
  }

  Future<void> _exportExpressSummary(
    String action,
    List<ExecutivePaymentBalance> rows,
  ) async {
    if (rows.isEmpty) return;
    try {
      final exportRows = await _buildExpressSummaryRows(rows);
      final objectTitle = selectedObjectName ?? 'Все объекты';
      final periodTitle = _formatRange(period);

      if (action == 'copy') {
        final text = ExecutivePaymentSummaryExporter.buildText(
          objectTitle: objectTitle,
          periodTitle: periodTitle,
          employeeFilterTitle: _employmentTitle,
          rows: exportRows,
        );
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Экспресс-сводка скопирована')),
        );
        return;
      }

      if (action == 'txt') {
        await ExecutivePaymentSummaryExporter.saveText(
          objectTitle: objectTitle,
          periodTitle: periodTitle,
          employeeFilterTitle: _employmentTitle,
          rows: exportRows,
        );
      } else if (action == 'xlsx') {
        await ExecutivePaymentSummaryExporter.saveXlsx(
          objectTitle: objectTitle,
          periodTitle: periodTitle,
          employeeFilterTitle: _employmentTitle,
          rows: exportRows,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'xlsx'
                ? 'Таблица экспресс-сводки сохранена'
                : 'Текст экспресс-сводки сохранён',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сформировать сводку: $error')),
      );
    }
  }

  Future<void> _showExpressSummaryActions(
    List<ExecutivePaymentBalance> rows,
  ) async {
    if (rows.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppAdaptivePalette.background,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Скопировать текст'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Скачать TXT'),
              onTap: () => Navigator.pop(sheetContext, 'txt'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Скачать XLSX'),
              onTap: () => Navigator.pop(sheetContext, 'xlsx'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _exportExpressSummary(action, rows);
  }

  Future<void> _openDetails(ExecutivePaymentBalance row) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppAdaptivePalette.background,
      builder: (_) => _ExecutiveEmployeeDetailsSheet(
        row: row,
        period: period,
      ),
    );
  }

  void _handleDataChange(AppDataChange change) {
    if (!mounted ||
        !change.affectsAny(const <AppDataDomain>{
          AppDataDomain.attendance,
          AppDataDomain.payments,
          AppDataDomain.employees,
          AppDataDomain.objects,
        })) {
      return;
    }
    unawaited(
      _load(
        forceRefresh: true,
        forceObjects: change.affects(AppDataDomain.objects),
      ),
    );
  }

  Future<void> _load({
    bool forceRefresh = false,
    bool forceObjects = false,
  }) async {
    final generation = ++loadGeneration;
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await Future.wait<dynamic>([
        ObjectRepository.fetchObjectNames(forceRefresh: forceObjects),
        ObjectRepository.fetchArchivedObjectNames(
          forceRefresh: forceObjects,
        ),
        ExecutivePanelRepository.fetchPaymentSummary(
          startDate: period.start,
          endDate: period.end,
          objectName: selectedObjectName,
          forceRefresh: forceRefresh,
        ),
      ]);
      if (!mounted || generation != loadGeneration) return;
      final nextArchivedObjectNames =
          (result[1] as List<String>).toSet();
      final nextObjectNames = <String>{
        ...(result[0] as List<String>),
        ...nextArchivedObjectNames,
      }.toList()
        ..sort();
      final nextSummary = result[2] as ExecutivePaymentSummary;
      final objectSelectionBecameInvalid =
          selectedObjectName != null &&
          !nextObjectNames.contains(selectedObjectName);
      setState(() {
        objectNames = nextObjectNames;
        archivedObjectNames = nextArchivedObjectNames;
        if (objectSelectionBecameInvalid) selectedObjectName = null;
        summary = nextSummary;
        _resetShareDraft();
      });
      if (objectSelectionBecameInvalid) {
        unawaited(_load(forceRefresh: true));
      }
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        errorText = 'Не удалось загрузить выплаты: $error';
      });
    } finally {
      if (mounted && generation == loadGeneration) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _applyPeriodPreset(int monthsBack) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1, 0);
    final start = DateTime(now.year, now.month - monthsBack, 1);
    setState(() {
      period = DateTimeRange(start: start, end: end);
      _resetShareDraft();
    });
    await _load(forceRefresh: true);
  }

  Future<void> _applyPreviousMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 0);
    setState(() {
      period = DateTimeRange(start: start, end: end);
      _resetShareDraft();
    });
    await _load(forceRefresh: true);
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: period,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Расчётный период',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    setState(() {
      period = DateTimeRange(
        start: _dateOnly(picked.start),
        end: _dateOnly(picked.end),
      );
      _resetShareDraft();
    });
    await _load(forceRefresh: true);
  }

  Future<void> _changeObject(String? value) async {
    final next = value?.trim();
    final normalized = next == null || next.isEmpty ? null : next;
    if (normalized == selectedObjectName) return;
    setState(() {
      selectedObjectName = normalized;
      _resetShareDraft();
    });
    await _load(forceRefresh: true);
  }

  void _changeEmploymentFilter(_ExecutiveEmploymentFilter value) {
    if (value == employmentFilter) return;
    setState(() {
      employmentFilter = value;
      _resetShareDraft();
    });
  }

  Widget _paymentFilters() {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ФИО сотрудника',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppAdaptivePalette.inputSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppAdaptivePalette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppAdaptivePalette.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Быстрый период',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Этот месяц'),
                onPressed: () => _applyPeriodPreset(0),
              ),
              ActionChip(
                label: const Text('Прошлый месяц'),
                onPressed: _applyPreviousMonth,
              ),
              ActionChip(
                label: const Text('3 месяца'),
                onPressed: () => _applyPeriodPreset(2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Остаток считается по табелю и выплатам. '
            'Служебные исключения без табеля рассчитываются автоматически.',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Сотрудники',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: employmentFilter == _ExecutiveEmploymentFilter.all,
                onSelected: (_) =>
                    _changeEmploymentFilter(_ExecutiveEmploymentFilter.all),
              ),
              ChoiceChip(
                label: const Text('Действующие'),
                selected:
                    employmentFilter == _ExecutiveEmploymentFilter.active,
                onSelected: (_) =>
                    _changeEmploymentFilter(_ExecutiveEmploymentFilter.active),
              ),
              ChoiceChip(
                label: const Text('Уволенные'),
                selected:
                    employmentFilter == _ExecutiveEmploymentFilter.fired,
                onSelected: (_) =>
                    _changeEmploymentFilter(_ExecutiveEmploymentFilter.fired),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Только к выплате'),
              selected: onlyDue,
              onSelected: (value) {
                setState(() {
                  onlyDue = value;
                  _resetShareDraft();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareActions(List<ExecutivePaymentBalance> rows) {
    if (!editingForShare) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: rows.isEmpty ? null : _beginShareEdit,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Редактировать для отправки'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Скопировать как есть',
            onPressed: rows.isEmpty ? null : () => _copyForShare(rows),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: rows.isEmpty ? null : () => _copyForShare(rows),
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Скопировать'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: _cancelShareEdit,
          child: const Text('Отмена'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = summary;
    final rows = _visibleRows(current);
    final total = editingForShare ? _shareTotal(rows) : _actualTotal(rows);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        title: const Text('Оплата'),
      ),
      body: PremiumWorkBackdrop(
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true, forceObjects: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _ExecutiveFilterBar(
                objectNames: objectNames,
                archivedObjectNames: archivedObjectNames,
                selectedObjectName: selectedObjectName,
                periodText: _formatRange(period),
                onObjectChanged: _changeObject,
                onPickPeriod: _pickPeriod,
              ),
              const SizedBox(height: 12),
              _paymentFilters(),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 14),
                _ExecutiveMessageState(
                  icon: Icons.error_outline_rounded,
                  text: errorText!,
                ),
              ] else if (current != null) ...[
                const SizedBox(height: 14),
                _shareActions(rows),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showExpressSummaryActions(rows),
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('Экспресс-сводка'),
                      ),
                      if (selectedObjectName == null)
                        TextButton.icon(
                          onPressed: () =>
                              _copyForShare(rows, groupByObject: true),
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('Скопировать по объектам'),
                        ),
                    ],
                  ),
                ],
                if (editingForShare) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Изменения ниже нужны только для сообщения. '
                    'Выплаты и начисления в системе не меняются.',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _ExecutivePaymentTotal(
                  total: total,
                  count: rows.length,
                  edited: editingForShare,
                ),
                const SizedBox(height: 14),
                if (!isLoading && rows.isEmpty)
                  const _ExecutiveMessageState(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'По выбранным фильтрам остатка нет',
                  )
                else
                  for (final row in rows) ...[
                    _ExecutivePaymentCard(
                      row: row,
                      period: period,
                      onInfo: () => _openDetails(row),
                      onCopyRequisites: () => _copyPaymentRequisites(row),
                      shareAmountController: editingForShare
                          ? shareAmountControllers[_rowKey(row)]
                          : null,
                      onShareAmountChanged: editingForShare
                          ? () => setState(() {})
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveFilterBar extends StatelessWidget {
  final List<String> objectNames;
  final Set<String> archivedObjectNames;
  final String? selectedObjectName;
  final String periodText;
  final ValueChanged<String?> onObjectChanged;
  final VoidCallback onPickPeriod;

  const _ExecutiveFilterBar({
    required this.objectNames,
    this.archivedObjectNames = const <String>{},
    required this.selectedObjectName,
    required this.periodText,
    required this.onObjectChanged,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final objectButton = _ExecutiveObjectSelector(
            objectNames: objectNames,
            archivedObjectNames: archivedObjectNames,
            selectedObjectName: selectedObjectName,
            onChanged: onObjectChanged,
          );
          final periodButton = _ExecutiveFilterButton(
            icon: Icons.date_range_outlined,
            label: 'Период',
            value: periodText,
            onTap: onPickPeriod,
          );
          if (compact) {
            return Column(
              children: [
                objectButton,
                const SizedBox(height: 10),
                periodButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: objectButton),
              const SizedBox(width: 10),
              Expanded(child: periodButton),
            ],
          );
        },
      ),
    );
  }
}

class _ExecutiveObjectSelector extends StatelessWidget {
  static const String allObjectsValue = '__all__';

  final List<String> objectNames;
  final Set<String> archivedObjectNames;
  final String? selectedObjectName;
  final ValueChanged<String?> onChanged;

  const _ExecutiveObjectSelector({
    required this.objectNames,
    this.archivedObjectNames = const <String>{},
    required this.selectedObjectName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Выбрать объект',
      onSelected: (value) {
        onChanged(value == allObjectsValue ? null : value);
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: allObjectsValue,
          child: Text('Все объекты'),
        ),
        for (final name in objectNames)
          PopupMenuItem<String>(
            value: name,
            child: Text(
              archivedObjectNames.contains(name) ? '$name (архив)' : name,
            ),
          ),
      ],
      child: _ExecutiveFilterButton(
        icon: Icons.apartment_rounded,
        label: 'Объект',
        value: selectedObjectName == null
            ? 'Все объекты'
            : archivedObjectNames.contains(selectedObjectName)
            ? '$selectedObjectName (архив)'
            : selectedObjectName!,
      ),
    );
  }
}

class _ExecutiveFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ExecutiveFilterButton({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.expand_more_rounded,
            color: AppAdaptivePalette.textMuted,
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _ExecutiveTaskMessageCard extends StatelessWidget {
  final ExecutiveTaskMessage message;

  const _ExecutiveTaskMessageCard({super.key, required this.message});

  Future<void> _copyMessage(BuildContext context) async {
    final lines = <String>[
      if (message.objectName.trim().isNotEmpty) message.objectName.trim(),
      '${_formatDate(message.date)} · ${_formatTime(message.createdAt)}',
      if (message.creatorName.trim().isNotEmpty) message.creatorName.trim(),
      '',
      message.text.trim().isEmpty ? 'Задача без описания' : message.text.trim(),
      if (message.mediaCount > 0) '',
      if (message.mediaCount > 0) 'Фото/видео: ${message.mediaCount}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Задача скопирована')),
    );
  }

  Future<void> _openMedia(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppAdaptivePalette.background,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: FutureBuilder<List<ExecutiveTaskPhoto>>(
            future: ExecutivePanelRepository.fetchTaskMedia(message.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Не удалось загрузить фото/видео: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final media =
                  snapshot.data ?? const <ExecutiveTaskPhoto>[];
              if (media.isEmpty) {
                return const Center(
                  child: Text('Фото/видео для этой задачи не найдены'),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Фото/видео · ${media.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ExecutivePhotoGrid(photos: media),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      _formatDate(message.date),
      _formatTime(message.createdAt),
      if (message.objectName.trim().isNotEmpty) message.objectName.trim(),
      message.creatorName,
    ].join(' · ');

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                message.text.trim().isEmpty
                    ? 'Задача без описания'
                    : message.text.trim(),
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  fontSize: 15,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message.mediaCount > 0) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openMedia(context),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('Фото/видео: ${message.mediaCount}'),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metadata,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Скопировать задачу',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyMessage(context),
                    icon: const Icon(Icons.copy_rounded, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutivePhotoGrid extends StatelessWidget {
  final List<ExecutiveTaskPhoto> photos;

  const _ExecutivePhotoGrid({required this.photos});

  Future<void> _openPhoto(
    BuildContext context,
    int initialIndex,
  ) async {
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (_) => _ExecutivePhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = photos.length > 4 ? 4 : photos.length;
    final onePhoto = visibleCount == 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: onePhoto ? 1 : 2,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: onePhoto ? 1.65 : 1.15,
        ),
        itemBuilder: (context, index) {
          final photo = photos[index];
          final hiddenCount = photos.length - visibleCount;
          final showMore = hiddenCount > 0 && index == visibleCount - 1;
          return InkWell(
            onTap: () => _openPhoto(context, index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo.signedUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppAdaptivePalette.surfaceSoft,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppAdaptivePalette.textMuted,
                    ),
                  ),
                ),
                if (showMore)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: Text(
                      '+$hiddenCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExecutivePhotoViewer extends StatefulWidget {
  final List<ExecutiveTaskPhoto> photos;
  final int initialIndex;

  const _ExecutivePhotoViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_ExecutivePhotoViewer> createState() => _ExecutivePhotoViewerState();
}

class _ExecutivePhotoViewerState extends State<_ExecutivePhotoViewer> {
  late final PageController controller;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, pageIndex) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.network(
                      widget.photos[pageIndex].signedUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 44,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${index + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExecutivePaymentTotal extends StatelessWidget {
  final double total;
  final int count;
  final bool edited;

  const _ExecutivePaymentTotal({
    required this.total,
    required this.count,
    required this.edited,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            edited ? 'Итого для отправки' : 'Всего к выплате',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatMoney(total),
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Сотрудников в списке: $count',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutivePaymentCard extends StatelessWidget {
  final ExecutivePaymentBalance row;
  final DateTimeRange period;
  final VoidCallback onInfo;
  final VoidCallback onCopyRequisites;
  final TextEditingController? shareAmountController;
  final VoidCallback? onShareAmountChanged;

  const _ExecutivePaymentCard({
    required this.row,
    required this.period,
    required this.onInfo,
    required this.onCopyRequisites,
    this.shareAmountController,
    this.onShareAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final balanceIsOverpayment = row.balance < 0;
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employeeName,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.isActive ? 'Действующий' : 'Уволен'} · '
                      '${_formatRange(period)} · ${row.objectTitle}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Скопировать реквизиты',
                onPressed: onCopyRequisites,
                icon: const Icon(Icons.content_copy_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Информация о сотруднике',
                onPressed: onInfo,
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ExecutiveMoneyCell(
                  label: 'Смены',
                  textValue: row.automaticSalary ? '—' : _formatShifts(row.shifts),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveMoneyCell(
                  label: 'Начислено',
                  value: row.accrued,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExecutiveMoneyCell(
                  label: 'Выплачено',
                  value: row.paid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (shareAmountController != null)
            TextField(
              controller: shareAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => onShareAmountChanged?.call(),
              decoration: InputDecoration(
                labelText: 'Сумма для отправки',
                helperText: 'Только копия. 0 = убрать из отправки',
                suffixText: '₽',
                filled: true,
                fillColor: AppAdaptivePalette.inputSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppAdaptivePalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balanceIsOverpayment ? 'Переплата' : 'Остаток к выплате',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatMoney(row.balance.abs()),
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExecutiveEmployeeDetailsSheet extends StatefulWidget {
  final ExecutivePaymentBalance row;
  final DateTimeRange period;

  const _ExecutiveEmployeeDetailsSheet({
    required this.row,
    required this.period,
  });

  @override
  State<_ExecutiveEmployeeDetailsSheet> createState() =>
      _ExecutiveEmployeeDetailsSheetState();
}

class _ExecutiveEmployeeDetailsSheetState
    extends State<_ExecutiveEmployeeDetailsSheet> {
  late final Future<ExecutiveEmployeePaymentDetails> detailsFuture;

  @override
  void initState() {
    super.initState();
    detailsFuture = ExecutivePanelRepository.fetchEmployeePaymentDetails(
      balance: widget.row,
      startDate: widget.period.start,
      endDate: widget.period.end,
    );
  }

  Future<void> _copyEmployeeCalculation(
    ExecutiveEmployeePaymentDetails details,
  ) async {
    final status = details.isActive ? 'Действующий' : 'Уволен';
    final objectTitle = details.objectNames.isEmpty
        ? 'Все объекты'
        : details.objectNames.join(', ');
    final balanceLabel = details.balance >= 0 ? 'Остаток' : 'Переплата';
    final text = <String>[
      details.employeeName,
      '$status · $objectTitle',
      'Период: ${_formatRange(widget.period)}',
      if (details.automaticSalary)
        'Расчёт: без табеля'
      else
        'Смены: ${_formatShifts(details.shifts)}',
      'Начислено: ${_formatMoney(details.accrued)}',
      'Выплачено: ${_formatMoney(details.paid)}',
      '$balanceLabel: ${_formatMoney(details.balance.abs())}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Расчёт сотрудника скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return SizedBox(
      height: height,
      child: FutureBuilder<ExecutiveEmployeePaymentDetails>(
        future: detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ExecutiveMessageState(
              icon: Icons.error_outline_rounded,
              text: 'Не удалось загрузить подробности: ${snapshot.error}',
            );
          }
          final details = snapshot.data!;
          final attendance = details.attendance
              .where((item) => item.shifts.abs() > 0.0001)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      details.employeeName,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${details.isActive ? 'Действующий' : 'Уволен'} · '
                '${details.objectNames.isEmpty ? 'Все объекты' : details.objectNames.join(', ')}',
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ExecutiveDetailMetric(
                      label: details.automaticSalary
                          ? 'Расчёт'
                          : 'Первая смена в системе',
                      value: details.automaticSalary
                          ? 'Без табеля'
                          : details.firstShiftDate == null
                              ? 'Нет данных'
                              : _formatDate(details.firstShiftDate!),
                    ),
                    _ExecutiveDetailMetric(
                      label: 'Период',
                      value: _formatRange(widget.period),
                    ),
                    _ExecutiveDetailMetric(
                      label: 'Смены',
                      value: details.automaticSalary
                          ? '—'
                          : _formatShifts(details.shifts),
                    ),
                    _ExecutiveDetailMetric(
                      label: 'Начислено',
                      value: _formatMoney(details.accrued),
                    ),
                    _ExecutiveDetailMetric(
                      label: 'Выплачено',
                      value: _formatMoney(details.paid),
                    ),
                    _ExecutiveDetailMetric(
                      label: details.balance >= 0 ? 'Остаток' : 'Переплата',
                      value: _formatMoney(details.balance.abs()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copyEmployeeCalculation(details),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Скопировать расчёт сотрудника'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Табель за период',
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (attendance.isEmpty)
                _ExecutiveMessageState(
                  icon: Icons.event_busy_outlined,
                  text: details.automaticSalary
                      ? 'Для сотрудника табель не ведётся. Начисление рассчитывается автоматически.'
                      : 'В выбранном периоде смен нет',
                )
              else
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < attendance.length; index++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_available_outlined),
                          title: Text(_formatDate(attendance[index].date)),
                          trailing: Text(
                            '${_formatShifts(attendance[index].shifts)} смен.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (index != attendance.length - 1)
                          Divider(color: AppAdaptivePalette.border),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Выплаты расчётного периода',
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (details.payments.isEmpty)
                const _ExecutiveMessageState(
                  icon: Icons.payments_outlined,
                  text: 'Выплат за выбранный расчётный период нет',
                )
              else
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < details.payments.length;
                        index++
                      ) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            _paymentTypeTitle(
                              details.payments[index].paymentType,
                            ),
                          ),
                          subtitle: Text(
                            <String>[
                              'Расчёт: ${_formatYearMonth(
                                details.payments[index].periodYear,
                                details.payments[index].periodMonth,
                              )}',
                              'Выплачено: ${_formatDate(
                                details.payments[index].paymentDate,
                              )}',
                              if (details.payments[index].comment.trim().isNotEmpty)
                                details.payments[index].comment.trim(),
                            ].join(' · '),
                          ),
                          trailing: Text(
                            _formatMoney(details.payments[index].amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (index != details.payments.length - 1)
                          Divider(color: AppAdaptivePalette.border),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExecutiveDetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ExecutiveDetailMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMoneyCell extends StatelessWidget {
  final String label;
  final double? value;
  final String? textValue;

  const _ExecutiveMoneyCell({
    required this.label,
    this.value,
    this.textValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          textValue ?? _formatMoney(value ?? 0),
          style: TextStyle(
            color: AppAdaptivePalette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ExecutiveMessageState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExecutiveMessageState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppAdaptivePalette.textMuted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _formatYearMonth(int year, int month) {
  if (year <= 0 || month < 1 || month > 12) return 'не указан';
  return '${month.toString().padLeft(2, '0')}.$year';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatRange(DateTimeRange value) {
  if (_dateOnly(value.start) == _dateOnly(value.end)) {
    return _formatDate(value.start);
  }
  return '${_formatDate(value.start)} — ${_formatDate(value.end)}';
}

String _formatShifts(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.round().toString();
  var text = number.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text.replaceAll('.', ',');
}

String _paymentTypeTitle(String value) {
  switch (value) {
    case 'advance':
      return 'Аванс';
    case 'salary':
      return 'Зарплата';
    case 'final':
      return 'Окончательный расчёт';
    case 'cash':
      return 'Наличные';
    default:
      return value.trim().isEmpty ? 'Выплата' : value;
  }
}

String _formatMoney(num value) {
  final rounded = value.round().toString();
  return rounded.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}

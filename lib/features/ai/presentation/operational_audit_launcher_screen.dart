import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/object_repository.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/object_employee_scope.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/ai_assistant_repository.dart';
import 'ai_operational_audit_screen.dart';

class OperationalAuditLauncherScreen extends StatefulWidget {
  final DateTime? initialMonth;
  final String? initialObjectName;

  const OperationalAuditLauncherScreen({
    super.key,
    this.initialMonth,
    this.initialObjectName,
  });

  @override
  State<OperationalAuditLauncherScreen> createState() =>
      _OperationalAuditLauncherScreenState();
}

class _OperationalAuditLauncherScreenState
    extends State<OperationalAuditLauncherScreen> {
  final SupabaseClient client = Supabase.instance.client;
  late DateTime selectedMonth;
  List<String> objectNames = const <String>[];
  String? selectedObjectScope;
  bool loadingObjects = true;
  bool running = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final source = widget.initialMonth ?? DateTime.now();
    selectedMonth = DateTime(source.year, source.month, 1);
    final object = widget.initialObjectName?.trim() ?? '';
    selectedObjectScope = object.isEmpty ? allObjectsScopeValue : object;
    loadObjects();
  }

  Future<void> loadObjects() async {
    try {
      final names = await ObjectRepository.fetchObjectNames();
      if (!mounted) return;
      setState(() {
        objectNames = names;
        if (selectedObjectScope != null &&
            selectedObjectScope != allObjectsScopeValue &&
            !names.contains(selectedObjectScope)) {
          selectedObjectScope = allObjectsScopeValue;
        }
        loadingObjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingObjects = false;
        errorText = 'Не удалось загрузить объекты: $error';
      });
    }
  }

  String monthTitle(DateTime value) {
    const months = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
        1,
      );
      errorText = null;
    });
  }

  String text(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List && value.isNotEmpty) return text(value.first);
    if (value is Map && value.isNotEmpty) return text(value.values.first);
    return value.toString().trim();
  }

  Future<void> runAudit() async {
    if (running || selectedObjectScope == null) return;
    setState(() {
      running = true;
      errorText = null;
    });
    try {
      final rawCompany = await client.rpc('current_user_company_id');
      final companyId = text(rawCompany);
      if (companyId.isEmpty) throw Exception('Активная компания не выбрана');
      final objectName = selectedObjectNameFromScope(selectedObjectScope);
      final result = await AiAssistantRepository.request(
        mode: 'chat',
        companyId: companyId,
        objectName: objectName,
        date: selectedMonth,
        prompt: 'Проверь табель и выплаты за ${monthTitle(selectedMonth)}',
      );
      final action = result.action;
      if (action == null || action.type != 'find_operational_anomalies') {
        throw Exception('Сервер не вернул единый операционный аудит');
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => AiOperationalAuditScreen(action: action),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Контроль табеля и выплат',
      showBackButton: true,
      subtitle: 'Прямой read-only аудит без команды в чате',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 26,
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Период и объект',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Предыдущий месяц',
                      onPressed: running ? null : () => changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        monthTitle(selectedMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Следующий месяц',
                      onPressed: running ? null : () => changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                if (loadingObjects)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedObjectScope,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Объект',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: allObjectsScopeValue,
                        child: Text('Все доступные объекты'),
                      ),
                      ...objectNames.map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: running
                        ? null
                        : (value) =>
                              setState(() => selectedObjectScope = value),
                  ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loadingObjects || running ? null : runAudit,
                    icon: running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(
                      running ? 'Проверяем…' : 'Запустить единый контроль',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(16),
            child: Text(
              'Проверяются противоречия табеля, выплаты без чеков, дубли, выплаты без начисления, превышение начисления и несовпадения объектов. Отчёт ничего не исправляет и не удаляет.',
              style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';

class DeveloperDemoCenterScreen extends StatefulWidget {
  const DeveloperDemoCenterScreen({super.key});

  @override
  State<DeveloperDemoCenterScreen> createState() =>
      _DeveloperDemoCenterScreenState();
}

class _DeveloperDemoCenterScreenState extends State<DeveloperDemoCenterScreen> {
  int selectedIndex = 0;

  static const scenarios = <_DemoScenario>[
    _DemoScenario(
      title: 'Управление объектом',
      promise: 'От людей и задач до ежедневного контроля объекта за 3 минуты.',
      icon: Icons.apartment_outlined,
      metrics: <_DemoMetric>[
        _DemoMetric('Объекты', '2'),
        _DemoMetric('Сотрудники', '43'),
        _DemoMetric('Задачи сегодня', '8'),
        _DemoMetric('Явка', '92%'),
      ],
      steps: <String>[
        'Показать сводку по объектам и текущим работам.',
        'Открыть сотрудников объекта и дневной табель.',
        'Показать задачу с фото до/после и ограничениями прораба.',
        'Завершить демонстрацию отчётом руководителя.',
      ],
      proof: 'Руководитель видит одну систему вместо чатов, бумажного табеля и разрозненных таблиц.',
    ),
    _DemoScenario(
      title: 'Кандидат → сотрудник',
      promise: 'Оформление человека без повторного ввода и потери документов.',
      icon: Icons.badge_outlined,
      metrics: <_DemoMetric>[
        _DemoMetric('Кандидат', '1 тестовый'),
        _DemoMetric('Формы', '4'),
        _DemoMetric('Подписано', '3/4'),
        _DemoMetric('Выход', '8/8'),
      ],
      steps: <String>[
        'Открыть тестового кандидата «Тестов Алексей Сергеевич».',
        'Показать блокеры, следующий шаг и полный кадровый ZIP.',
        'Создать карточку сотрудника через проверяемый черновик.',
        'Закрыть маршрут выхода на объект и показать уведомления ролям.',
      ],
      proof: 'HR один раз вводит данные и видит, чего не хватает до полного оформления и выхода.',
    ),
    _DemoScenario(
      title: 'Табель и выплаты',
      promise: 'Единая проверка начислений, выплат, чеков и объектов.',
      icon: Icons.fact_check_outlined,
      metrics: <_DemoMetric>[
        _DemoMetric('Проверено', '43 чел.'),
        _DemoMetric('Критичные', '1'),
        _DemoMetric('Внимание', '3'),
        _DemoMetric('Автоисправления', '0'),
      ],
      steps: <String>[
        'Выбрать месяц и объект без команды в ИИ-чате.',
        'Показать смены без выплаты и выплаты без начисления.',
        'Открыть выплату без чека и несовпадение объекта.',
        'Подчеркнуть, что система только выявляет проблемы, а решение подтверждает человек.',
      ],
      proof: 'Бухгалтер и руководитель быстрее находят ошибки до расчёта и спорных выплат.',
    ),
  ];

  Widget banner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5C27D)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Color(0xFF8A5A12)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ДЕМО · все данные вымышлены · экран не подключается к Supabase и не показывает рабочую компанию',
              style: TextStyle(
                color: Color(0xFF7A4D0C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget scenarioSelector(_DemoScenario scenario, int index) {
    final selected = selectedIndex == index;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: index == scenarios.length - 1 ? 0 : 8),
        child: PremiumPressable(
          onTap: () => setState(() => selectedIndex = index),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Icon(scenario.icon, size: 26),
                const SizedBox(height: 7),
                Text(
                  scenario.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget metric(_DemoMetric item) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget scenarioBody(_DemoScenario scenario) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(scenario.icon, size: 28),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.promise,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w650,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: scenario.metrics.map(metric).toList(growable: false),
          ),
          const SizedBox(height: 20),
          const Text(
            'Сценарий показа',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...scenario.steps.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${entry.$1 + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.$2,
                      style: const TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4EC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Что доказали: ${scenario.proof}',
              style: const TextStyle(
                color: Color(0xFF215C3D),
                height: 1.4,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenario = scenarios[selectedIndex];
    return AppPage(
      title: 'Демонстрационный центр',
      subtitle: 'Безопасный сценарий показа AppСтрой потенциальному клиенту',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: scenarios.indexed
                .map((entry) => scenarioSelector(entry.$2, entry.$1))
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          scenarioBody(scenario),
          const SizedBox(height: 14),
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(16),
            child: Text(
              'Правило демо: не открывай рабочие паспорта, реальные выплаты и персональные телефоны. Для живого показа используй только отдельную тестовую компанию и маркированные тестовые записи.',
              style: TextStyle(height: 1.45, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoScenario {
  final String title;
  final String promise;
  final IconData icon;
  final List<_DemoMetric> metrics;
  final List<String> steps;
  final String proof;

  const _DemoScenario({
    required this.title,
    required this.promise,
    required this.icon,
    required this.metrics,
    required this.steps,
    required this.proof,
  });
}

class _DemoMetric {
  final String label;
  final String value;

  const _DemoMetric(this.label, this.value);
}

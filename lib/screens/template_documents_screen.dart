import 'package:flutter/material.dart';

class TemplateDocumentsScreen extends StatelessWidget {
  const TemplateDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = [
      'Трудовой договор',
      'КС-2',
      'КС-3',
      'Акт выполненных работ',
      'Заявление на работу',
      'Завявление на получение ЗП',
      'Согласие на обработку данных',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Документы')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Шаблоны документов',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Позже сюда загрузим шаблоны: трудовой договор, КС-2, КС-3 и другие формы.',
          ),
          const SizedBox(height: 18),
          ...templates.map((title) {
            return Card(
              elevation: 0,
              color: const Color(0xFFFFEEE7),
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(title),
                subtitle: const Text('Шаблон будет добавлен позже'),
                trailing: const Icon(Icons.lock_clock_outlined),
              ),
            );
          }),
        ],
      ),
    );
  }
}

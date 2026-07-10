import 'package:flutter/material.dart';

import '../data/employee_private_data_importer.dart';
import '../models/app_user_profile.dart';

class PrivateDataImportScreen extends StatefulWidget {
  final AppUserProfile profile;

  const PrivateDataImportScreen({super.key, required this.profile});

  @override
  State<PrivateDataImportScreen> createState() =>
      _PrivateDataImportScreenState();
}

class _PrivateDataImportScreenState extends State<PrivateDataImportScreen> {
  bool isImporting = false;
  String? resultText;
  String? errorText;

  Future<void> importData() async {
    if (isImporting || !widget.profile.isAdmin) return;

    setState(() {
      isImporting = true;
      resultText = null;
      errorText = null;
    });

    try {
      final result = await EmployeePrivateDataImporter.pickAndImport(
        objectName: 'Мурманск',
      );

      if (!mounted || result == null) return;

      final missingText = result.notFoundNames.isEmpty
          ? ''
          : '\nНе найдены карточки: ${result.notFoundNames.join(', ')}';

      setState(() {
        resultText =
            'Готово. Обновлено карточек: ${result.updatedEmployees} из ${result.sourceRows}.$missingText';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка импорта: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isImporting = false;
        });
      }
    }
  }

  void returnToApp() {
    final baseUri = Uri.base.replace(queryParameters: const <String, String>{});
    Uri.base.resolveUri(baseUri);
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Импорт доступен только администратору')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Импорт личных данных')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.badge_outlined, size: 42),
                    const SizedBox(height: 14),
                    const Text(
                      'Личные данные сотрудников Мурманска',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Выбери подготовленный JSON-файл. Заполнятся паспорт, дата рождения, прописка, СНИЛС, ИНН и найденные банковские реквизиты. Пустые значения не затрут уже заполненные данные.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                    if (resultText != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          resultText!,
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isImporting ? null : importData,
                        icon: isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(
                          isImporting ? 'Загрузка...' : 'Выбрать файл и загрузить',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: isImporting
                            ? null
                            : () {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                  (_) => false,
                                );
                              },
                        child: const Text('Вернуться в приложение'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

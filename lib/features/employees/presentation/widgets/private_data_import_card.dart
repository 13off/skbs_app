import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/widgets/app_status_message.dart';

class PrivateDataImportCard extends StatelessWidget {
  final bool isLoadingObjects;
  final bool isImporting;
  final List<String> objectNames;
  final String? selectedObjectName;
  final String? resultText;
  final String? errorText;
  final ValueChanged<String?> onObjectChanged;
  final VoidCallback onImport;
  final VoidCallback onRetryObjects;
  final VoidCallback onReturn;

  const PrivateDataImportCard({
    super.key,
    required this.isLoadingObjects,
    required this.isImporting,
    required this.objectNames,
    required this.selectedObjectName,
    required this.resultText,
    required this.errorText,
    required this.onObjectChanged,
    required this.onImport,
    required this.onRetryObjects,
    required this.onReturn,
  });

  bool get canImport {
    return !isLoadingObjects &&
        !isImporting &&
        selectedObjectName != null &&
        selectedObjectName!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
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
            'Личные данные сотрудников',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Выбери объект и подготовленный JSON-файл. Заполнятся паспорт, дата рождения, прописка, СНИЛС, ИНН и найденные банковские реквизиты. Пустые значения не затрут уже заполненные данные.',
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
          if (isLoadingObjects)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (objectNames.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppStatusMessage.error(
                  text: 'Не найдено ни одного активного объекта.',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRetryObjects,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить загрузку'),
                ),
              ],
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedObjectName,
              decoration: const InputDecoration(
                labelText: 'Объект для импорта',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              items: objectNames.map((objectName) {
                return DropdownMenuItem<String>(
                  value: objectName,
                  child: Text(objectName),
                );
              }).toList(),
              onChanged: isImporting ? null : onObjectChanged,
            ),
          if (resultText != null) ...[
            const SizedBox(height: 18),
            AppStatusMessage.success(text: resultText!),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 18),
            AppStatusMessage.error(text: errorText!),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canImport ? onImport : null,
            icon: isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(
              isImporting ? 'Загрузка...' : 'Выбрать файл и загрузить',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: isImporting ? null : onReturn,
            child: const Text('Вернуться в приложение'),
          ),
        ],
      ),
    );
  }
}

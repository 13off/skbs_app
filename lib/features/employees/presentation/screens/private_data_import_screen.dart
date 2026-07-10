import 'package:flutter/material.dart';

import '../../../../core/errors/error_text.dart';
import '../../../../data/employee_private_data_importer.dart';
import '../../../../data/object_repository.dart';
import '../../../auth/models/app_user_profile.dart';
import '../widgets/private_data_import_card.dart';

class PrivateDataImportScreen extends StatefulWidget {
  final AppUserProfile profile;

  const PrivateDataImportScreen({super.key, required this.profile});

  @override
  State<PrivateDataImportScreen> createState() =>
      _PrivateDataImportScreenState();
}

class _PrivateDataImportScreenState extends State<PrivateDataImportScreen> {
  bool _isLoadingObjects = true;
  bool _isImporting = false;
  List<String> _objectNames = const [];
  String? _selectedObjectName;
  String? _resultText;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    setState(() {
      _isLoadingObjects = true;
      _errorText = null;
    });

    try {
      final objectNames = await ObjectRepository.fetchObjectNames();
      final profileObject = widget.profile.objectName.trim();
      final selectedObject = objectNames.contains(profileObject)
          ? profileObject
          : objectNames.isEmpty
          ? null
          : objectNames.first;

      if (!mounted) return;

      setState(() {
        _objectNames = objectNames;
        _selectedObjectName = selectedObject;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _objectNames = const [];
        _selectedObjectName = null;
        _errorText = ErrorText.from(
          error,
          prefix: 'Не удалось загрузить объекты',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingObjects = false;
        });
      }
    }
  }

  Future<void> _importData() async {
    final objectName = _selectedObjectName?.trim();

    if (_isImporting || !widget.profile.isAdmin) return;

    if (objectName == null || objectName.isEmpty) {
      setState(() {
        _errorText = 'Сначала выбери объект для импорта.';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _resultText = null;
      _errorText = null;
    });

    try {
      final result = await EmployeePrivateDataImporter.pickAndImport(
        objectName: objectName,
      );

      if (!mounted || result == null) return;

      final missingText = result.notFoundNames.isEmpty
          ? ''
          : '\nНе найдены карточки: ${result.notFoundNames.join(', ')}';

      setState(() {
        _resultText =
            'Готово. Объект: $objectName. Обновлено карточек: ${result.updatedEmployees} из ${result.sourceRows}.$missingText';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorText = ErrorText.from(error, prefix: 'Ошибка импорта');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _returnToApp() {
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
              child: PrivateDataImportCard(
                isLoadingObjects: _isLoadingObjects,
                isImporting: _isImporting,
                objectNames: _objectNames,
                selectedObjectName: _selectedObjectName,
                resultText: _resultText,
                errorText: _errorText,
                onObjectChanged: (value) {
                  setState(() {
                    _selectedObjectName = value;
                    _resultText = null;
                    _errorText = null;
                  });
                },
                onImport: _importData,
                onRetryObjects: _loadObjects,
                onReturn: _returnToApp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

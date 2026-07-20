import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/app_data_sync.dart';
import '../../data/employee_private_data_repository.dart';
import '../../data/employee_private_summary_exporter.dart';
import '../../data/employee_repository.dart';
import '../../models/employee.dart';
import '../../models/employee_private_data.dart';

class EmployeeDirectoryController extends ChangeNotifier {
  EmployeeDirectoryController({
    required String? selectedObjectName,
    required this.loadPrivateData,
  }) : _selectedObjectName = selectedObjectName;

  final bool loadPrivateData;
  String? _selectedObjectName;
  StreamSubscription<AppDataChange>? _dataChangeSubscription;
  int _requestId = 0;
  bool _disposed = false;

  List<Employee> employees = const <Employee>[];
  Map<String, EmployeePrivateData> privateDataByEmployeeId =
      const <String, EmployeePrivateData>{};
  bool loading = true;
  String? error;

  String? get selectedObjectName => _selectedObjectName;

  String? get objectName =>
      EmployeeDirectoryLogic.cleanObjectName(_selectedObjectName);

  void start() {
    _dataChangeSubscription ??= AppDataSync.changes.listen(_handleDataChange);
    load(showLoading: true);
  }

  Future<void> updateObjectName(String? selectedObjectName) async {
    if (_selectedObjectName == selectedObjectName) return;
    _selectedObjectName = selectedObjectName;
    await load(showLoading: true, forceRefresh: true);
  }

  void _handleDataChange(AppDataChange change) {
    if (_disposed) return;
    if (!change.affectsAny(const <AppDataDomain>{
      AppDataDomain.employees,
      AppDataDomain.objects,
    })) {
      return;
    }
    load(forceRefresh: true);
  }

  Future<void> load({
    bool showLoading = false,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_requestId;
    final requestedObjectName = _selectedObjectName;

    if (showLoading && employees.isEmpty) {
      loading = true;
      error = null;
      _notify();
    }

    try {
      final loaded = await EmployeeRepository.fetchEmployees(
        objectName: requestedObjectName,
        includeFired: true,
        forceRefresh: forceRefresh,
      );

      var privateMap = <String, EmployeePrivateData>{};
      if (loadPrivateData) {
        final employeeIds = loaded
            .map((employee) => employee.id?.trim() ?? '')
            .where((employeeId) => employeeId.isNotEmpty)
            .toSet()
            .toList(growable: false);
        try {
          privateMap =
              await EmployeePrivateDataRepository.fetchMapByEmployeeIds(
                employeeIds,
              );
        } catch (_) {
          // Список остаётся доступным, если закрытые данные временно недоступны.
        }
      }

      if (_disposed || requestId != _requestId) return;
      employees = loaded;
      privateDataByEmployeeId = privateMap;
      loading = false;
      error = null;
      _notify();
    } catch (loadError) {
      if (_disposed || requestId != _requestId) return;
      loading = false;
      error = loadError.toString();
      _notify();
    }
  }

  List<Employee> preparedEmployees({
    String query = '',
    required bool sortSelectedObject,
    required bool sortDuplicateGroupsByObject,
    required bool caseInsensitiveNameSort,
  }) {
    return EmployeeDirectoryLogic.prepareEmployees(
      employees,
      query: query,
      collapseAcrossObjects: objectName == null,
      sortSelectedObject: sortSelectedObject,
      sortDuplicateGroupsByObject: sortDuplicateGroupsByObject,
      caseInsensitiveNameSort: caseInsensitiveNameSort,
    );
  }

  Future<void> downloadSummary() async {
    final source = employees.isNotEmpty
        ? List<Employee>.from(employees)
        : await EmployeeRepository.fetchEmployees(
            objectName: _selectedObjectName,
            includeFired: true,
          );
    final ids = source
        .map((employee) => employee.id ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    final privateData =
        await EmployeePrivateDataRepository.fetchMapByEmployeeIds(ids);

    await EmployeePrivateSummaryExporter.downloadSummary(
      employees: source,
      privateDataByEmployeeId: privateData,
      objectName: _selectedObjectName,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dataChangeSubscription?.cancel();
    super.dispose();
  }
}

class EmployeeDirectoryLogic {
  EmployeeDirectoryLogic._();

  static String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String duplicateKey(Employee employee) {
    final name = employee.name.trim().toLowerCase();
    final phone = employee.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return phone.isNotEmpty
        ? '$name::$phone'
        : '$name::${employee.position.trim().toLowerCase()}';
  }

  static List<Employee> prepareEmployees(
    List<Employee> employees, {
    required String query,
    required bool collapseAcrossObjects,
    required bool sortSelectedObject,
    required bool sortDuplicateGroupsByObject,
    required bool caseInsensitiveNameSort,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    var source = normalizedQuery.isEmpty
        ? List<Employee>.from(employees)
        : employees.where((employee) {
            return employee.name.toLowerCase().contains(normalizedQuery) ||
                employee.position.toLowerCase().contains(normalizedQuery) ||
                employee.phone.toLowerCase().contains(normalizedQuery) ||
                employee.objectName.toLowerCase().contains(normalizedQuery);
          }).toList();

    if (!collapseAcrossObjects) {
      if (sortSelectedObject) {
        source.sort(
          (first, second) => compareEmployees(
            first,
            second,
            caseInsensitiveNameSort: caseInsensitiveNameSort,
          ),
        );
      }
      return source;
    }

    final groups = <String, List<Employee>>{};
    for (final employee in source) {
      groups.putIfAbsent(duplicateKey(employee), () => <Employee>[]).add(
            employee,
          );
    }

    source = groups.values.map((group) {
      group.sort((first, second) {
        if (first.isActive != second.isActive) return first.isActive ? -1 : 1;
        if (sortDuplicateGroupsByObject) {
          return first.objectName.compareTo(second.objectName);
        }
        return compareEmployees(
          first,
          second,
          caseInsensitiveNameSort: caseInsensitiveNameSort,
        );
      });
      final main = group.first;
      final objects = group
          .map((employee) => employee.objectName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return Employee(
        main.name,
        main.position,
        main.status,
        id: main.id,
        phone: main.phone,
        objectName: objects.isEmpty ? main.objectName : objects.join(', '),
        dailyRate: main.dailyRate,
        isActive: group.any((employee) => employee.isActive),
        comment: main.comment,
      );
    }).toList();

    source.sort(
      (first, second) => compareEmployees(
        first,
        second,
        caseInsensitiveNameSort: caseInsensitiveNameSort,
      ),
    );
    return source;
  }

  static int compareEmployees(
    Employee first,
    Employee second, {
    required bool caseInsensitiveNameSort,
  }) {
    if (first.isActive != second.isActive) return first.isActive ? -1 : 1;
    final firstName = caseInsensitiveNameSort
        ? first.name.toLowerCase()
        : first.name;
    final secondName = caseInsensitiveNameSort
        ? second.name.toLowerCase()
        : second.name;
    return firstName.compareTo(secondName);
  }

  static void restoreScrollOffset(
    ScrollController scrollController,
    double savedOffset,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final position = scrollController.position;
      final target = savedOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > .5) {
        scrollController.jumpTo(target);
      }
    });
  }

  static String money(int value) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$formatted ₽';
  }
}

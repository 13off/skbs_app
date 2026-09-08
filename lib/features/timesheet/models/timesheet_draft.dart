import 'timesheet_absence_reason.dart';

class TimesheetDraft {
  final Map<String, double> _originalValues;
  final Map<String, double> _values;
  final Map<String, String> _originalAbsenceReasons;
  final Map<String, String> _absenceReasons;

  TimesheetDraft._({
    required Map<String, double> originalValues,
    required Map<String, double> values,
    required Map<String, String> originalAbsenceReasons,
    required Map<String, String> absenceReasons,
  }) : _originalValues = Map<String, double>.unmodifiable(originalValues),
       _values = Map<String, double>.unmodifiable(values),
       _originalAbsenceReasons = Map<String, String>.unmodifiable(
         originalAbsenceReasons,
       ),
       _absenceReasons = Map<String, String>.unmodifiable(absenceReasons);

  factory TimesheetDraft.empty() {
    return TimesheetDraft._(
      originalValues: const <String, double>{},
      values: const <String, double>{},
      originalAbsenceReasons: const <String, String>{},
      absenceReasons: const <String, String>{},
    );
  }

  factory TimesheetDraft.fromValues(
    Map<String, double> values, {
    Map<String, String> absenceReasons = const <String, String>{},
  }) {
    final valueSnapshot = Map<String, double>.from(values);
    final reasonSnapshot = _normalizedReasons(absenceReasons);
    return TimesheetDraft._(
      originalValues: valueSnapshot,
      values: valueSnapshot,
      originalAbsenceReasons: reasonSnapshot,
      absenceReasons: reasonSnapshot,
    );
  }

  static Map<String, String> _normalizedReasons(Map<String, String> source) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final reason = TimesheetAbsenceReason.normalize(entry.value);
      if (reason != null) result[entry.key] = reason;
    }
    return result;
  }

  Map<String, double> get originalValues =>
      Map<String, double>.from(_originalValues);

  Map<String, double> get values => Map<String, double>.from(_values);

  Map<String, String> get originalAbsenceReasons =>
      Map<String, String>.from(_originalAbsenceReasons);

  Map<String, String> get absenceReasons =>
      Map<String, String>.from(_absenceReasons);

  bool get hasChanges {
    final ids = <String>{
      ..._originalValues.keys,
      ..._values.keys,
      ..._originalAbsenceReasons.keys,
      ..._absenceReasons.keys,
    };
    return ids.any(
      (id) =>
          valueFor(id) != originalValueFor(id) ||
          absenceReasonFor(id) != originalAbsenceReasonFor(id),
    );
  }

  Map<String, double> get changedValues {
    final result = <String, double>{};
    final ids = <String>{..._originalValues.keys, ..._values.keys};
    for (final id in ids) {
      final value = valueFor(id);
      if (value != originalValueFor(id)) result[id] = value;
    }
    return result;
  }

  double valueFor(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) return 0;
    return _values[employeeId] ?? 0;
  }

  double originalValueFor(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) return 0;
    return _originalValues[employeeId] ?? 0;
  }

  String? absenceReasonFor(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) return null;
    return TimesheetAbsenceReason.normalize(_absenceReasons[employeeId]);
  }

  String? originalAbsenceReasonFor(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) return null;
    return TimesheetAbsenceReason.normalize(_originalAbsenceReasons[employeeId]);
  }

  TimesheetDraft withValue(String? employeeId, double value) {
    if (employeeId == null || employeeId.isEmpty) return this;
    final shouldClearReason = value > 0 && absenceReasonFor(employeeId) != null;
    if (valueFor(employeeId) == value && !shouldClearReason) return this;

    final nextValues = Map<String, double>.from(_values);
    final nextReasons = Map<String, String>.from(_absenceReasons);
    nextValues[employeeId] = value;
    if (value > 0) nextReasons.remove(employeeId);
    return TimesheetDraft._(
      originalValues: _originalValues,
      values: nextValues,
      originalAbsenceReasons: _originalAbsenceReasons,
      absenceReasons: nextReasons,
    );
  }

  TimesheetDraft withValues(Iterable<String?> employeeIds, double value) {
    final nextValues = Map<String, double>.from(_values);
    final nextReasons = Map<String, String>.from(_absenceReasons);
    var changed = false;

    for (final employeeId in employeeIds) {
      if (employeeId == null || employeeId.isEmpty) continue;
      if ((nextValues[employeeId] ?? 0) != value) {
        nextValues[employeeId] = value;
        changed = true;
      }
      if (value > 0 && nextReasons.remove(employeeId) != null) changed = true;
    }

    if (!changed) return this;
    return TimesheetDraft._(
      originalValues: _originalValues,
      values: nextValues,
      originalAbsenceReasons: _originalAbsenceReasons,
      absenceReasons: nextReasons,
    );
  }

  TimesheetDraft withAbsenceReason(String? employeeId, String? reason) {
    if (employeeId == null || employeeId.isEmpty) return this;
    final normalized = TimesheetAbsenceReason.normalize(reason);
    if (absenceReasonFor(employeeId) == normalized) return this;

    final nextReasons = Map<String, String>.from(_absenceReasons);
    if (normalized == null) {
      nextReasons.remove(employeeId);
    } else {
      nextReasons[employeeId] = normalized;
    }
    return TimesheetDraft._(
      originalValues: _originalValues,
      values: _values,
      originalAbsenceReasons: _originalAbsenceReasons,
      absenceReasons: nextReasons,
    );
  }

  int workedCountFor(Iterable<String?> employeeIds) {
    return employeeIds.where((id) => valueFor(id) > 0).length;
  }

  double totalFor(Iterable<String?> employeeIds) {
    return employeeIds.fold<double>(0, (sum, id) => sum + valueFor(id));
  }

  TimesheetDraft markSaved() {
    return TimesheetDraft.fromValues(_values, absenceReasons: _absenceReasons);
  }
}

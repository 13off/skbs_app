class TimesheetDraft {
  final Map<String, double> _originalValues;
  final Map<String, double> _values;

  TimesheetDraft._({
    required Map<String, double> originalValues,
    required Map<String, double> values,
  })  : _originalValues = Map<String, double>.unmodifiable(originalValues),
        _values = Map<String, double>.unmodifiable(values);

  factory TimesheetDraft.empty() {
    return TimesheetDraft._(
      originalValues: const <String, double>{},
      values: const <String, double>{},
    );
  }

  factory TimesheetDraft.fromValues(Map<String, double> values) {
    final snapshot = Map<String, double>.from(values);
    return TimesheetDraft._(originalValues: snapshot, values: snapshot);
  }

  Map<String, double> get originalValues =>
      Map<String, double>.from(_originalValues);

  Map<String, double> get values => Map<String, double>.from(_values);

  bool get hasChanges {
    final ids = <String>{..._originalValues.keys, ..._values.keys};
    return ids.any((id) => valueFor(id) != originalValueFor(id));
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

  TimesheetDraft withValue(String? employeeId, double value) {
    if (employeeId == null || employeeId.isEmpty) return this;
    if (valueFor(employeeId) == value) return this;

    final nextValues = Map<String, double>.from(_values);
    nextValues[employeeId] = value;
    return TimesheetDraft._(
      originalValues: _originalValues,
      values: nextValues,
    );
  }

  TimesheetDraft withValues(Iterable<String?> employeeIds, double value) {
    final nextValues = Map<String, double>.from(_values);
    var changed = false;

    for (final employeeId in employeeIds) {
      if (employeeId == null || employeeId.isEmpty) continue;
      if ((nextValues[employeeId] ?? 0) == value) continue;
      nextValues[employeeId] = value;
      changed = true;
    }

    if (!changed) return this;
    return TimesheetDraft._(
      originalValues: _originalValues,
      values: nextValues,
    );
  }

  int workedCountFor(Iterable<String?> employeeIds) {
    return employeeIds.where((id) => valueFor(id) > 0).length;
  }

  double totalFor(Iterable<String?> employeeIds) {
    return employeeIds.fold<double>(0, (sum, id) => sum + valueFor(id));
  }

  TimesheetDraft markSaved() {
    return TimesheetDraft.fromValues(_values);
  }
}

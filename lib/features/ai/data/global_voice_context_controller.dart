import 'package:flutter/foundation.dart';

class GlobalVoiceContextSnapshot {
  final String companyId;
  final String objectName;
  final String entityType;
  final String entityId;

  const GlobalVoiceContextSnapshot({
    this.companyId = '',
    this.objectName = '',
    this.entityType = '',
    this.entityId = '',
  });

  GlobalVoiceContextSnapshot copyWith({
    String? companyId,
    String? objectName,
    String? entityType,
    String? entityId,
  }) {
    return GlobalVoiceContextSnapshot(
      companyId: companyId ?? this.companyId,
      objectName: objectName ?? this.objectName,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
    );
  }
}

/// Lightweight context bus for the floating microphone.
///
/// Professional shells publish only context that is already visible to the
/// current user. The server still performs its own authorization and scoping.
class GlobalVoiceContextController {
  GlobalVoiceContextController._();

  static final ValueNotifier<GlobalVoiceContextSnapshot> state =
      ValueNotifier<GlobalVoiceContextSnapshot>(
        const GlobalVoiceContextSnapshot(),
      );

  static void setObjectName({
    required String companyId,
    String? objectName,
  }) {
    final cleanCompany = companyId.trim();
    final cleanObject = objectName?.trim() ?? '';
    state.value = GlobalVoiceContextSnapshot(
      companyId: cleanCompany,
      objectName: cleanObject,
      entityType: state.value.companyId == cleanCompany
          ? state.value.entityType
          : '',
      entityId: state.value.companyId == cleanCompany
          ? state.value.entityId
          : '',
    );
  }

  static void setEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    String? objectName,
  }) {
    state.value = GlobalVoiceContextSnapshot(
      companyId: companyId.trim(),
      objectName: objectName?.trim() ?? state.value.objectName,
      entityType: entityType.trim(),
      entityId: entityId.trim(),
    );
  }

  static String? objectNameFor(String companyId) {
    final snapshot = state.value;
    if (snapshot.companyId != companyId.trim()) return null;
    final value = snapshot.objectName.trim();
    return value.isEmpty ? null : value;
  }

  static void clear({String? companyId}) {
    final expected = companyId?.trim();
    if (expected != null &&
        expected.isNotEmpty &&
        state.value.companyId != expected) {
      return;
    }
    state.value = const GlobalVoiceContextSnapshot();
  }
}

import 'package:flutter/foundation.dart';

class GlobalVoiceContextSnapshot {
  final String companyId;
  final String objectName;
  final String entityType;
  final String entityId;
  final String conversationTopic;
  final String conversationMode;
  final String conversationDate;
  final String conversationPrompt;

  const GlobalVoiceContextSnapshot({
    this.companyId = '',
    this.objectName = '',
    this.entityType = '',
    this.entityId = '',
    this.conversationTopic = '',
    this.conversationMode = '',
    this.conversationDate = '',
    this.conversationPrompt = '',
  });

  GlobalVoiceContextSnapshot copyWith({
    String? companyId,
    String? objectName,
    String? entityType,
    String? entityId,
    String? conversationTopic,
    String? conversationMode,
    String? conversationDate,
    String? conversationPrompt,
  }) {
    return GlobalVoiceContextSnapshot(
      companyId: companyId ?? this.companyId,
      objectName: objectName ?? this.objectName,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      conversationTopic: conversationTopic ?? this.conversationTopic,
      conversationMode: conversationMode ?? this.conversationMode,
      conversationDate: conversationDate ?? this.conversationDate,
      conversationPrompt: conversationPrompt ?? this.conversationPrompt,
    );
  }
}

/// Lightweight context bus for the floating microphone.
///
/// Professional shells publish only context that is already visible to the
/// current user. The server still performs its own authorization and scoping.
/// The same snapshot also keeps a short-lived conversational thread so a
/// follow-up such as «кто именно?» can refer to the previous voice result.
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
    final sameCompany = state.value.companyId == cleanCompany;
    state.value = GlobalVoiceContextSnapshot(
      companyId: cleanCompany,
      objectName: cleanObject,
      entityType: sameCompany ? state.value.entityType : '',
      entityId: sameCompany ? state.value.entityId : '',
      conversationTopic: sameCompany ? state.value.conversationTopic : '',
      conversationMode: sameCompany ? state.value.conversationMode : '',
      conversationDate: sameCompany ? state.value.conversationDate : '',
      conversationPrompt: sameCompany ? state.value.conversationPrompt : '',
    );
  }

  static void setEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    String? objectName,
  }) {
    final cleanCompany = companyId.trim();
    final sameCompany = state.value.companyId == cleanCompany;
    state.value = GlobalVoiceContextSnapshot(
      companyId: cleanCompany,
      objectName: objectName?.trim() ?? (sameCompany ? state.value.objectName : ''),
      entityType: entityType.trim(),
      entityId: entityId.trim(),
      conversationTopic: sameCompany ? state.value.conversationTopic : '',
      conversationMode: sameCompany ? state.value.conversationMode : '',
      conversationDate: sameCompany ? state.value.conversationDate : '',
      conversationPrompt: sameCompany ? state.value.conversationPrompt : '',
    );
  }

  static void setConversation({
    required String companyId,
    required String topic,
    required String mode,
    required String date,
    required String prompt,
    String? objectName,
  }) {
    final cleanCompany = companyId.trim();
    final sameCompany = state.value.companyId == cleanCompany;
    state.value = GlobalVoiceContextSnapshot(
      companyId: cleanCompany,
      objectName: objectName?.trim() ?? (sameCompany ? state.value.objectName : ''),
      entityType: sameCompany ? state.value.entityType : '',
      entityId: sameCompany ? state.value.entityId : '',
      conversationTopic: topic.trim(),
      conversationMode: mode.trim(),
      conversationDate: date.trim(),
      conversationPrompt: prompt.trim(),
    );
  }

  static GlobalVoiceContextSnapshot? snapshotFor(String companyId) {
    final snapshot = state.value;
    if (snapshot.companyId != companyId.trim()) return null;
    return snapshot;
  }

  static String? objectNameFor(String companyId) {
    final snapshot = snapshotFor(companyId);
    final value = snapshot?.objectName.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static void clearConversation({required String companyId}) {
    final snapshot = snapshotFor(companyId);
    if (snapshot == null) return;
    state.value = snapshot.copyWith(
      conversationTopic: '',
      conversationMode: '',
      conversationDate: '',
      conversationPrompt: '',
    );
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

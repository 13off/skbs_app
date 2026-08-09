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
  final String conversationObjectName;
  final String pendingClarificationPrompt;
  final String pendingClarificationQuestion;

  const GlobalVoiceContextSnapshot({
    this.companyId = '',
    this.objectName = '',
    this.entityType = '',
    this.entityId = '',
    this.conversationTopic = '',
    this.conversationMode = '',
    this.conversationDate = '',
    this.conversationPrompt = '',
    this.conversationObjectName = '',
    this.pendingClarificationPrompt = '',
    this.pendingClarificationQuestion = '',
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
    String? conversationObjectName,
    String? pendingClarificationPrompt,
    String? pendingClarificationQuestion,
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
      conversationObjectName:
          conversationObjectName ?? this.conversationObjectName,
      pendingClarificationPrompt:
          pendingClarificationPrompt ?? this.pendingClarificationPrompt,
      pendingClarificationQuestion:
          pendingClarificationQuestion ?? this.pendingClarificationQuestion,
    );
  }
}

/// Lightweight context bus for the floating microphone.
///
/// Professional shells publish only context that is already visible to the
/// current user. The server still performs its own authorization and scoping.
/// The same snapshot also keeps a short-lived conversational thread so a
/// follow-up such as «кто именно?» can refer to the previous voice result.
///
/// Clarification context is separate from read-only conversation context: if a
/// command is ambiguous or incomplete, the original command is remembered and
/// the next short utterance is appended to it instead of forcing the user to
/// repeat the whole instruction.
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
      conversationObjectName:
          sameCompany ? state.value.conversationObjectName : '',
      pendingClarificationPrompt:
          sameCompany ? state.value.pendingClarificationPrompt : '',
      pendingClarificationQuestion:
          sameCompany ? state.value.pendingClarificationQuestion : '',
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
      conversationObjectName:
          sameCompany ? state.value.conversationObjectName : '',
      pendingClarificationPrompt:
          sameCompany ? state.value.pendingClarificationPrompt : '',
      pendingClarificationQuestion:
          sameCompany ? state.value.pendingClarificationQuestion : '',
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
      objectName: sameCompany ? state.value.objectName : '',
      entityType: sameCompany ? state.value.entityType : '',
      entityId: sameCompany ? state.value.entityId : '',
      conversationTopic: topic.trim(),
      conversationMode: mode.trim(),
      conversationDate: date.trim(),
      conversationPrompt: prompt.trim(),
      conversationObjectName: objectName?.trim() ?? '',
      pendingClarificationPrompt:
          sameCompany ? state.value.pendingClarificationPrompt : '',
      pendingClarificationQuestion:
          sameCompany ? state.value.pendingClarificationQuestion : '',
    );
  }

  static void setClarification({
    required String companyId,
    required String prompt,
    required String question,
  }) {
    final cleanCompany = companyId.trim();
    final sameCompany = state.value.companyId == cleanCompany;
    state.value = GlobalVoiceContextSnapshot(
      companyId: cleanCompany,
      objectName: sameCompany ? state.value.objectName : '',
      entityType: sameCompany ? state.value.entityType : '',
      entityId: sameCompany ? state.value.entityId : '',
      conversationTopic: sameCompany ? state.value.conversationTopic : '',
      conversationMode: sameCompany ? state.value.conversationMode : '',
      conversationDate: sameCompany ? state.value.conversationDate : '',
      conversationPrompt: sameCompany ? state.value.conversationPrompt : '',
      conversationObjectName:
          sameCompany ? state.value.conversationObjectName : '',
      pendingClarificationPrompt: prompt.trim(),
      pendingClarificationQuestion: question.trim(),
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
      conversationObjectName: '',
    );
  }

  static void clearClarification({required String companyId}) {
    final snapshot = snapshotFor(companyId);
    if (snapshot == null) return;
    state.value = snapshot.copyWith(
      pendingClarificationPrompt: '',
      pendingClarificationQuestion: '',
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

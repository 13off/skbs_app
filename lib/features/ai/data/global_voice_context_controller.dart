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
  final List<String> pendingClarificationBefore;
  final List<String> pendingClarificationAfter;
  final String lastCommandPrompt;
  final String lastCommandObjectName;
  final String lastCommandDate;
  final String lastResultTitle;
  final String lastResultSummary;
  final Map<String, dynamic> lastAction;

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
    this.pendingClarificationBefore = const <String>[],
    this.pendingClarificationAfter = const <String>[],
    this.lastCommandPrompt = '',
    this.lastCommandObjectName = '',
    this.lastCommandDate = '',
    this.lastResultTitle = '',
    this.lastResultSummary = '',
    this.lastAction = const <String, dynamic>{},
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
    List<String>? pendingClarificationBefore,
    List<String>? pendingClarificationAfter,
    String? lastCommandPrompt,
    String? lastCommandObjectName,
    String? lastCommandDate,
    String? lastResultTitle,
    String? lastResultSummary,
    Map<String, dynamic>? lastAction,
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
      pendingClarificationBefore:
          pendingClarificationBefore ?? this.pendingClarificationBefore,
      pendingClarificationAfter:
          pendingClarificationAfter ?? this.pendingClarificationAfter,
      lastCommandPrompt: lastCommandPrompt ?? this.lastCommandPrompt,
      lastCommandObjectName:
          lastCommandObjectName ?? this.lastCommandObjectName,
      lastCommandDate: lastCommandDate ?? this.lastCommandDate,
      lastResultTitle: lastResultTitle ?? this.lastResultTitle,
      lastResultSummary: lastResultSummary ?? this.lastResultSummary,
      lastAction: lastAction ?? this.lastAction,
    );
  }
}

/// Lightweight context bus for the floating microphone.
///
/// Professional shells publish only context that is already visible to the
/// current user. The server still performs its own authorization and scoping.
/// Besides read-only query context, the snapshot keeps two short-lived layers:
///
/// - clarification memory for an incomplete/ambiguous command, including the
///   steps before and after it inside a compound command;
/// - the last successful voice turn so natural follow-ups such as
///   «не Иванову, а Петрову», «то же самое на завтра» or «да, подтверждай» can
///   reuse the previous command without bypassing the established action flow.
class GlobalVoiceContextController {
  GlobalVoiceContextController._();

  static final ValueNotifier<GlobalVoiceContextSnapshot> state =
      ValueNotifier<GlobalVoiceContextSnapshot>(
        const GlobalVoiceContextSnapshot(),
      );

  static GlobalVoiceContextSnapshot _forCompany(String companyId) {
    final cleanCompany = companyId.trim();
    final current = state.value;
    if (current.companyId == cleanCompany) return current;
    return GlobalVoiceContextSnapshot(companyId: cleanCompany);
  }

  static void setObjectName({
    required String companyId,
    String? objectName,
  }) {
    final cleanCompany = companyId.trim();
    state.value = _forCompany(cleanCompany).copyWith(
      companyId: cleanCompany,
      objectName: objectName?.trim() ?? '',
    );
  }

  static void setEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    String? objectName,
  }) {
    final cleanCompany = companyId.trim();
    final current = _forCompany(cleanCompany);
    state.value = current.copyWith(
      companyId: cleanCompany,
      objectName: objectName?.trim() ?? current.objectName,
      entityType: entityType.trim(),
      entityId: entityId.trim(),
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
    state.value = _forCompany(cleanCompany).copyWith(
      companyId: cleanCompany,
      conversationTopic: topic.trim(),
      conversationMode: mode.trim(),
      conversationDate: date.trim(),
      conversationPrompt: prompt.trim(),
      conversationObjectName: objectName?.trim() ?? '',
    );
  }

  static void setClarification({
    required String companyId,
    required String prompt,
    required String question,
    Iterable<String> before = const <String>[],
    Iterable<String> after = const <String>[],
  }) {
    final cleanCompany = companyId.trim();
    state.value = _forCompany(cleanCompany).copyWith(
      companyId: cleanCompany,
      pendingClarificationPrompt: prompt.trim(),
      pendingClarificationQuestion: question.trim(),
      pendingClarificationBefore: before
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      pendingClarificationAfter: after
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  static void rememberTurn({
    required String companyId,
    required String prompt,
    required String objectName,
    required String date,
    required String resultTitle,
    required String resultSummary,
    Map<String, dynamic> action = const <String, dynamic>{},
  }) {
    final cleanCompany = companyId.trim();
    state.value = _forCompany(cleanCompany).copyWith(
      companyId: cleanCompany,
      lastCommandPrompt: prompt.trim(),
      lastCommandObjectName: objectName.trim(),
      lastCommandDate: date.trim(),
      lastResultTitle: resultTitle.trim(),
      lastResultSummary: resultSummary.trim(),
      lastAction: Map<String, dynamic>.from(action),
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
      pendingClarificationBefore: const <String>[],
      pendingClarificationAfter: const <String>[],
    );
  }

  static void clearLastTurn({required String companyId}) {
    final snapshot = snapshotFor(companyId);
    if (snapshot == null) return;
    state.value = snapshot.copyWith(
      lastCommandPrompt: '',
      lastCommandObjectName: '',
      lastCommandDate: '',
      lastResultTitle: '',
      lastResultSummary: '',
      lastAction: const <String, dynamic>{},
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

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
  final int conversationUpdatedAtMs;
  final String pendingClarificationPrompt;
  final String pendingClarificationQuestion;
  final List<String> pendingClarificationBefore;
  final List<String> pendingClarificationAfter;
  final int clarificationUpdatedAtMs;
  final String lastCommandPrompt;
  final String lastCommandObjectName;
  final String lastCommandDate;
  final String lastResultTitle;
  final String lastResultSummary;
  final Map<String, dynamic> lastAction;
  final int lastTurnUpdatedAtMs;

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
    this.conversationUpdatedAtMs = 0,
    this.pendingClarificationPrompt = '',
    this.pendingClarificationQuestion = '',
    this.pendingClarificationBefore = const <String>[],
    this.pendingClarificationAfter = const <String>[],
    this.clarificationUpdatedAtMs = 0,
    this.lastCommandPrompt = '',
    this.lastCommandObjectName = '',
    this.lastCommandDate = '',
    this.lastResultTitle = '',
    this.lastResultSummary = '',
    this.lastAction = const <String, dynamic>{},
    this.lastTurnUpdatedAtMs = 0,
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
    int? conversationUpdatedAtMs,
    String? pendingClarificationPrompt,
    String? pendingClarificationQuestion,
    List<String>? pendingClarificationBefore,
    List<String>? pendingClarificationAfter,
    int? clarificationUpdatedAtMs,
    String? lastCommandPrompt,
    String? lastCommandObjectName,
    String? lastCommandDate,
    String? lastResultTitle,
    String? lastResultSummary,
    Map<String, dynamic>? lastAction,
    int? lastTurnUpdatedAtMs,
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
      conversationUpdatedAtMs:
          conversationUpdatedAtMs ?? this.conversationUpdatedAtMs,
      pendingClarificationPrompt:
          pendingClarificationPrompt ?? this.pendingClarificationPrompt,
      pendingClarificationQuestion:
          pendingClarificationQuestion ?? this.pendingClarificationQuestion,
      pendingClarificationBefore:
          pendingClarificationBefore ?? this.pendingClarificationBefore,
      pendingClarificationAfter:
          pendingClarificationAfter ?? this.pendingClarificationAfter,
      clarificationUpdatedAtMs:
          clarificationUpdatedAtMs ?? this.clarificationUpdatedAtMs,
      lastCommandPrompt: lastCommandPrompt ?? this.lastCommandPrompt,
      lastCommandObjectName:
          lastCommandObjectName ?? this.lastCommandObjectName,
      lastCommandDate: lastCommandDate ?? this.lastCommandDate,
      lastResultTitle: lastResultTitle ?? this.lastResultTitle,
      lastResultSummary: lastResultSummary ?? this.lastResultSummary,
      lastAction: lastAction ?? this.lastAction,
      lastTurnUpdatedAtMs: lastTurnUpdatedAtMs ?? this.lastTurnUpdatedAtMs,
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
///
/// Context is intentionally ephemeral. Read-result references expire after
/// 30 minutes; clarification and prepared-action memory expire after 15.
class GlobalVoiceContextController {
  GlobalVoiceContextController._();

  static const Duration conversationTtl = Duration(minutes: 30);
  static const Duration clarificationTtl = Duration(minutes: 15);
  static const Duration lastTurnTtl = Duration(minutes: 15);

  static final ValueNotifier<GlobalVoiceContextSnapshot> state =
      ValueNotifier<GlobalVoiceContextSnapshot>(
        const GlobalVoiceContextSnapshot(),
      );

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static bool _expired(int updatedAtMs, Duration ttl, int nowMs) {
    if (updatedAtMs <= 0) return false;
    return nowMs - updatedAtMs > ttl.inMilliseconds;
  }

  static GlobalVoiceContextSnapshot _withoutExpired(
    GlobalVoiceContextSnapshot snapshot,
  ) {
    final now = _nowMs();
    var result = snapshot;

    if (
      result.conversationTopic.isNotEmpty &&
      _expired(result.conversationUpdatedAtMs, conversationTtl, now)
    ) {
      result = result.copyWith(
        conversationTopic: '',
        conversationMode: '',
        conversationDate: '',
        conversationPrompt: '',
        conversationObjectName: '',
        conversationUpdatedAtMs: 0,
      );
    }

    if (
      result.pendingClarificationPrompt.isNotEmpty &&
      _expired(result.clarificationUpdatedAtMs, clarificationTtl, now)
    ) {
      result = result.copyWith(
        pendingClarificationPrompt: '',
        pendingClarificationQuestion: '',
        pendingClarificationBefore: const <String>[],
        pendingClarificationAfter: const <String>[],
        clarificationUpdatedAtMs: 0,
      );
    }

    if (
      result.lastCommandPrompt.isNotEmpty &&
      _expired(result.lastTurnUpdatedAtMs, lastTurnTtl, now)
    ) {
      result = result.copyWith(
        lastCommandPrompt: '',
        lastCommandObjectName: '',
        lastCommandDate: '',
        lastResultTitle: '',
        lastResultSummary: '',
        lastAction: const <String, dynamic>{},
        lastTurnUpdatedAtMs: 0,
      );
    }

    return result;
  }

  static GlobalVoiceContextSnapshot _forCompany(String companyId) {
    final cleanCompany = companyId.trim();
    final current = _withoutExpired(state.value);
    if (!identical(current, state.value)) state.value = current;
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
      conversationUpdatedAtMs: _nowMs(),
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
      clarificationUpdatedAtMs: _nowMs(),
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
      lastTurnUpdatedAtMs: _nowMs(),
    );
  }

  static GlobalVoiceContextSnapshot? snapshotFor(String companyId) {
    final snapshot = state.value;
    if (snapshot.companyId != companyId.trim()) return null;
    final fresh = _withoutExpired(snapshot);
    if (!identical(fresh, snapshot)) state.value = fresh;
    return fresh;
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
      conversationUpdatedAtMs: 0,
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
      clarificationUpdatedAtMs: 0,
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
      lastTurnUpdatedAtMs: 0,
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

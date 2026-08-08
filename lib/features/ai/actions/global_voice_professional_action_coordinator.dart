import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../legal/data/legal_repository.dart';
import '../../procurement/data/procurement_repository.dart';
import '../../recruitment/data/recruitment_crm_workspace_repository.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

class GlobalVoiceProfessionalActionCoordinator {
  GlobalVoiceProfessionalActionCoordinator._();

  static const supportedTypes = <String>{
    'move_candidate_stage',
    'decide_legal_matter',
    'advance_procurement_status',
  };

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (!supportedTypes.contains(action.type)) {
      throw UnsupportedError('Профессиональная голосовая команда не поддерживается');
    }

    _checkRole(profile, action);
    final audit = await AiActionAuditRepository.createProposed(
      companyId: profile.activeCompanyId,
      action: action,
    );
    if (!context.mounted) {
      await AiActionAuditRepository.markCancelled(audit.id);
      return const AiActionExecutionResult.cancelled();
    }

    try {
      final confirmed = await _confirm(context, action);
      if (!confirmed) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }
      await AiActionAuditRepository.markConfirmed(audit.id);

      final result = switch (action.type) {
        'move_candidate_stage' => await _moveCandidate(action),
        'decide_legal_matter' => await _decideLegalMatter(action),
        'advance_procurement_status' => await _advanceProcurement(action),
        _ => throw UnsupportedError(action.type),
      };
      await AiActionAuditRepository.markCompleted(
        audit.id,
        targetEntityType: result.targetEntityType,
        targetEntityId: result.targetEntityId,
      );
      return result;
    } catch (error) {
      await AiActionAuditRepository.markFailed(audit.id, error);
      rethrow;
    }
  }

  static void _checkRole(AppUserProfile profile, AiAssistantAction action) {
    switch (action.type) {
      case 'move_candidate_stage':
        if (!profile.isAdmin && !profile.isHr && !profile.isDeveloper) {
          throw StateError('Изменение этапа кандидата недоступно текущей роли');
        }
        return;
      case 'decide_legal_matter':
        if (!profile.isAdmin && !profile.isDeveloper) {
          throw StateError('Юридическое решение может подтверждать руководитель');
        }
        return;
      case 'advance_procurement_status':
        if (!profile.isAdmin && !profile.isProcurement && !profile.isDeveloper) {
          throw StateError('Изменение снабжения недоступно текущей роли');
        }
        return;
    }
  }

  static Future<AiActionExecutionResult> _moveCandidate(
    AiAssistantAction action,
  ) async {
    final applicationId = action.text('application_id');
    final stageId = action.text('stage_id');
    if (applicationId.isEmpty || stageId.isEmpty) {
      throw StateError('Не хватает кандидата или нового этапа');
    }
    final count = await RecruitmentCrmWorkspaceRepository.bulkMove(
      applicationIds: <String>[applicationId],
      stageId: stageId,
    );
    if (count != 1) {
      throw StateError('Кандидат не был переведён. Обнови CRM и повтори команду.');
    }
    try {
      await RecruitmentCrmWorkspaceRepository.runAutomations(
        applicationIds: <String>[applicationId],
      );
    } catch (_) {
      // Сам переход уже сохранён. CRM-автоматизации смогут выполниться отдельно.
    }
    return AiActionExecutionResult(
      completed: true,
      message: '${action.text('candidate_name')} → ${action.text('stage_title')}',
      targetEntityType: 'recruitment_application',
      targetEntityId: applicationId,
    );
  }

  static Future<AiActionExecutionResult> _decideLegalMatter(
    AiAssistantAction action,
  ) async {
    final matterId = action.text('matter_id');
    if (matterId.isEmpty) throw StateError('Юридический вопрос не найден');
    await LegalRepository.decideMatter(
      matterId: matterId,
      approved: action.boolean('approved'),
      comment: action.text('comment'),
    );
    return AiActionExecutionResult(
      completed: true,
      message: action.boolean('approved')
          ? 'Юридический вопрос согласован'
          : 'Юридический вопрос отклонён',
      targetEntityType: 'legal_matter',
      targetEntityId: matterId,
    );
  }

  static Future<AiActionExecutionResult> _advanceProcurement(
    AiAssistantAction action,
  ) async {
    final requestId = action.text('request_id');
    final status = action.text('new_status');
    if (requestId.isEmpty || status.isEmpty) {
      throw StateError('Не хватает заявки или нового статуса');
    }
    await ProcurementRepository.setStatus(requestId: requestId, status: status);
    return AiActionExecutionResult(
      completed: true,
      message: '${action.text('request_title')}: ${action.text('new_status_title')}',
      targetEntityType: 'procurement_request',
      targetEntityId: requestId,
    );
  }

  static Future<bool> _confirm(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final details = _details(action);
    final destructive = action.type == 'advance_procurement_status' &&
        action.text('new_status') == 'canceled';
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Material(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  for (final item in details)
                    _DetailRow(label: item.$1, value: item.$2),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: destructive
                          ? scheme.errorContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      destructive
                          ? 'Это отменит рабочую заявку. Изменение выполнится только после подтверждения и попадёт в журнал ИИ.'
                          : 'AppСтрой изменит данные только после подтверждения. Действие попадёт в журнал ИИ.',
                      style: TextStyle(
                        color: destructive ? scheme.onErrorContainer : scheme.onSurface,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: destructive
                              ? FilledButton.styleFrom(
                                  backgroundColor: scheme.error,
                                  foregroundColor: scheme.onError,
                                )
                              : null,
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: Text(destructive ? 'Подтвердить отмену' : 'Подтвердить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  static List<(String, String)> _details(AiAssistantAction action) {
    switch (action.type) {
      case 'move_candidate_stage':
        return <(String, String)>[
          ('Кандидат', action.text('candidate_name')),
          ('Новый этап', action.text('stage_title')),
        ];
      case 'decide_legal_matter':
        return <(String, String)>[
          ('Вопрос', action.text('matter_title')),
          ('Решение', action.boolean('approved') ? 'Согласовать' : 'Отклонить'),
          if (action.text('comment').isNotEmpty) ('Комментарий', action.text('comment')),
        ];
      case 'advance_procurement_status':
        return <(String, String)>[
          ('Заявка', action.text('request_title')),
          if (action.text('object_name').isNotEmpty) ('Объект', action.text('object_name')),
          ('Было', action.text('current_status_title')),
          ('Станет', action.text('new_status_title')),
        ];
      default:
        return const <(String, String)>[];
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

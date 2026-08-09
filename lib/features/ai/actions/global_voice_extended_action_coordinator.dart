import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../legal/data/legal_repository.dart';
import '../../procurement/data/procurement_repository.dart';
import '../../procurement/models/procurement_models.dart';
import '../../recruitment/data/recruitment_crm_workspace_repository.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

class GlobalVoiceExtendedActionCoordinator {
  GlobalVoiceExtendedActionCoordinator._();

  static const supportedTypes = <String>{
    'assign_candidate_responsible',
    'create_procurement_request',
    'create_legal_matter',
  };

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (!supportedTypes.contains(action.type)) {
      throw UnsupportedError(action.type);
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
        'assign_candidate_responsible' => await _assignCandidate(action),
        'create_procurement_request' => await _createProcurement(action),
        'create_legal_matter' => await _createLegalMatter(action),
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
      case 'assign_candidate_responsible':
        if (!profile.isAdmin && !profile.isHr && !profile.isDeveloper) {
          throw StateError('Назначение ответственного кандидату недоступно текущей роли');
        }
      case 'create_procurement_request':
        if (!profile.isAdmin && !profile.isProcurement && !profile.isDeveloper) {
          throw StateError('Создание заявки снабжения недоступно текущей роли');
        }
      case 'create_legal_matter':
        if (!profile.isAdmin && !profile.isLawyer && !profile.isDeveloper) {
          throw StateError('Создание юридического вопроса недоступно текущей роли');
        }
    }
  }

  static Future<AiActionExecutionResult> _assignCandidate(
    AiAssistantAction action,
  ) async {
    final applicationId = action.text('application_id');
    final responsibleUserId = action.text('responsible_user_id');
    if (applicationId.isEmpty || responsibleUserId.isEmpty) {
      throw StateError('Не хватает кандидата или ответственного');
    }
    await RecruitmentCrmWorkspaceRepository.assignResponsible(
      applicationId: applicationId,
      responsibleUserId: responsibleUserId,
    );
    return AiActionExecutionResult(
      completed: true,
      message:
          '${action.text('candidate_name')}: ответственный ${action.text('responsible_name')}',
      targetEntityType: 'recruitment_application',
      targetEntityId: applicationId,
    );
  }

  static Future<AiActionExecutionResult> _createProcurement(
    AiAssistantAction action,
  ) async {
    final objectId = action.text('object_id');
    final itemName = action.text('item_name');
    final quantity = action.number('quantity').toDouble();
    final unit = action.text('unit');
    if (objectId.isEmpty || itemName.isEmpty || quantity <= 0) {
      throw StateError('Не хватает объекта, материала или количества');
    }

    final id = await ProcurementRepository.saveRequest(
      existing: null,
      objectId: objectId,
      supplierId: '',
      title: action.text('title').isEmpty
          ? '$itemName — $quantity ${unit.isEmpty ? 'шт.' : unit}'
          : action.text('title'),
      priority: action.text('priority').isEmpty
          ? 'normal'
          : action.text('priority'),
      neededBy: action.date('needed_by'),
      expectedDeliveryAt: null,
      invoiceNumber: '',
      comment: 'Создано голосовой командой AppСтрой',
      items: <ProcurementRequestItem>[
        ProcurementRequestItem(
          name: itemName,
          quantity: quantity,
          unit: unit.isEmpty ? 'шт.' : unit,
        ),
      ],
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Заявка снабжения создана: ${action.text('title')}',
      targetEntityType: 'procurement_request',
      targetEntityId: id,
    );
  }

  static Future<AiActionExecutionResult> _createLegalMatter(
    AiAssistantAction action,
  ) async {
    final title = action.text('title');
    if (title.isEmpty) throw StateError('Не указан юридический вопрос');

    final matter = await LegalRepository.saveMatter(
      matterType: action.text('matter_type').isEmpty
          ? 'task'
          : action.text('matter_type'),
      title: title,
      description: action.text('description'),
      riskLevel: action.text('risk_level').isEmpty
          ? 'medium'
          : action.text('risk_level'),
      status: 'open',
      dueAt: action.date('due_at'),
      responsibleUserId: null,
      employeeId: null,
      objectId: action.text('object_id').isEmpty
          ? null
          : action.text('object_id'),
      counterpartyId: null,
      documentId: null,
      requiredActions: action.text('required_actions').isEmpty
          ? title
          : action.text('required_actions'),
      result: '',
      requiresForemanAction: false,
      requiresManagerDecision: action.boolean('requires_manager_decision'),
      managerQuestion: action.text('manager_question'),
      decisionStatus: action.boolean('requires_manager_decision')
          ? 'pending'
          : 'none',
      decisionComment: '',
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Юридический вопрос «${matter.title}» создан',
      targetEntityType: 'legal_matter',
      targetEntityId: matter.id,
    );
  }

  static Future<bool> _confirm(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final scheme = Theme.of(context).colorScheme;
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
                  for (final row in _details(action))
                    _DetailRow(label: row.$1, value: row.$2),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Данные изменятся только после подтверждения. Действие попадёт в журнал ИИ.',
                      style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
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
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('Подтвердить'),
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
      case 'assign_candidate_responsible':
        return <(String, String)>[
          ('Кандидат', action.text('candidate_name')),
          ('Ответственный', action.text('responsible_name')),
        ];
      case 'create_procurement_request':
        return <(String, String)>[
          ('Объект', action.text('object_name')),
          ('Материал', action.text('item_name')),
          ('Количество', '${action.number('quantity')} ${action.text('unit')}'),
          ('Приоритет', action.text('priority')),
          if (action.text('needed_by').isNotEmpty)
            ('Нужно к', action.text('needed_by')),
        ];
      case 'create_legal_matter':
        return <(String, String)>[
          ('Вопрос', action.text('title')),
          ('Риск', action.text('risk_level')),
          if (action.text('object_name').isNotEmpty)
            ('Объект', action.text('object_name')),
          if (action.text('due_at').isNotEmpty) ('Срок', action.text('due_at')),
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
            width: 128,
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

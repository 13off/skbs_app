import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/payments_screen.dart';
import '../../../screens/settings_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../legal/presentation/legal_documents_screen.dart';
import '../../milestones/presentation/milestones_screen.dart';
import '../../procurement/presentation/procurement_deliveries_screen.dart';
import '../../procurement/presentation/procurement_requests_screen.dart';
import '../../procurement/presentation/procurement_suppliers_screen.dart';
import '../../recruitment/presentation/recruitment_applications_screen.dart';
import '../../tools/presentation/company_tools_screen.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';
import 'global_voice_action_execution_coordinator.dart';

class GlobalVoiceActionRouter {
  GlobalVoiceActionRouter._();

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (action.type == 'open_screen') {
      return _openScreen(context, profile, action);
    }
    return GlobalVoiceActionExecutionCoordinator.execute(
      context: context,
      profile: profile,
      action: action,
    );
  }

  static Future<AiActionExecutionResult> _openScreen(
    BuildContext context,
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final screen = action.text('screen');
    final objectName = _objectName(action, profile);
    final target = switch (screen) {
      'notifications' => const NotificationsScreen(),
      'settings' => SettingsScreen(profile: profile),
      'employees' => _employees(profile, objectName),
      'timesheet' => _timesheet(profile, objectName),
      'tasks' => _tasks(profile, objectName),
      'payments' => _payments(profile, objectName),
      'recruitment' => _recruitment(profile),
      'legal' => _legal(profile),
      'procurement' => _procurement(profile),
      'suppliers' => _suppliers(profile),
      'deliveries' => _deliveries(profile),
      'milestones' => _milestones(profile, objectName),
      'tools' => CompanyToolsScreen(profile: profile),
      _ => throw StateError('Раздел пока нельзя открыть голосом'),
    };

    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => target),
    );
    return AiActionExecutionResult(
      completed: true,
      message: action.title,
      targetEntityType: 'navigation',
      targetEntityId: screen,
    );
  }

  static String? _objectName(
    AiAssistantAction action,
    AppUserProfile profile,
  ) {
    final fromAction = action.text('object_name');
    if (fromAction.isNotEmpty) return fromAction;
    final fromProfile = profile.objectName.trim();
    return fromProfile.isEmpty ? null : fromProfile;
  }

  static Widget _employees(AppUserProfile profile, String? objectName) {
    if (!profile.isAdmin && !profile.isForeman) {
      throw StateError('Раздел сотрудников недоступен текущей роли');
    }
    return AdaptiveEmployeesScreen(
      profile: profile,
      selectedObjectName: objectName,
    );
  }

  static Widget _timesheet(AppUserProfile profile, String? objectName) {
    if (!profile.isAdmin && !profile.isForeman && !profile.isAccountant) {
      throw StateError('Табель недоступен текущей роли');
    }
    return AdaptiveTimesheetScreen(
      profile: profile,
      selectedObjectName: objectName,
    );
  }

  static Widget _tasks(AppUserProfile profile, String? objectName) {
    if (!profile.isAdmin && !profile.isForeman) {
      throw StateError('Управление задачами недоступно текущей роли');
    }
    return TasksScreen(profile: profile, selectedObjectName: objectName);
  }

  static Widget _payments(AppUserProfile profile, String? objectName) {
    if (!profile.isAdmin && !profile.isAccountant) {
      throw StateError('Выплаты недоступны текущей роли');
    }
    return PaymentsScreen(selectedObjectName: objectName);
  }

  static Widget _recruitment(AppUserProfile profile) {
    if (!profile.isAdmin && !profile.isHr) {
      throw StateError('HR-раздел недоступен текущей роли');
    }
    return RecruitmentApplicationsScreen(profile: profile);
  }

  static Widget _legal(AppUserProfile profile) {
    if (!profile.isAdmin && !profile.isLawyer) {
      throw StateError('Юридический раздел недоступен текущей роли');
    }
    return const LegalDocumentsScreen();
  }

  static Widget _procurement(AppUserProfile profile) {
    if (!profile.isAdmin && !profile.isProcurement) {
      throw StateError('Снабжение недоступно текущей роли');
    }
    return ProcurementRequestsScreen(profile: profile);
  }

  static Widget _suppliers(AppUserProfile profile) {
    if (!profile.isAdmin && !profile.isProcurement) {
      throw StateError('Поставщики недоступны текущей роли');
    }
    return ProcurementSuppliersScreen(profile: profile);
  }

  static Widget _deliveries(AppUserProfile profile) {
    if (!profile.isAdmin && !profile.isProcurement) {
      throw StateError('Доставки недоступны текущей роли');
    }
    return ProcurementDeliveriesScreen(profile: profile);
  }

  static Widget _milestones(AppUserProfile profile, String? objectName) {
    if (!profile.isAdmin && !profile.isForeman) {
      throw StateError('Цели недоступны текущей роли');
    }
    return MilestonesScreen(
      profile: profile,
      selectedObjectName: objectName,
    );
  }
}

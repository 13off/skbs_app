import '../../data/app_state.dart';
import '../../models/app_user_profile.dart';
import '../../models/task_item_data.dart';
import '../developer/data/developer_policy_repository.dart';
import '../developer/models/task_policy.dart';

class TaskEditPolicy {
  static DateTime get operationalToday {
    final moscowNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(moscowNow.year, moscowNow.month, moscowNow.day);
  }

  static TaskPolicy forObject(String objectName) {
    return DeveloperPolicyRepository.policyForObjectSync(objectName);
  }

  static bool canCreateForDate(
    AppUserProfile profile,
    DateTime date, {
    String? objectName,
  }) {
    if (profile.isAdmin) return true;
    if (!profile.isForeman) return false;
    final policy = forObject(objectName ?? profile.objectName);
    return AppState.isSameDay(date, operationalToday) ||
        policy.foremanCanCreateAnyDate;
  }

  static bool canEditTask(AppUserProfile profile, TaskItemData task) {
    if (profile.isAdmin) return true;
    if (!profile.isForeman) return false;
    final policy = forObject(task.objectName);
    final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
    if (AppState.isSameDay(taskDate, operationalToday)) return true;
    if (taskDate.isAfter(operationalToday)) {
      return policy.foremanCanCreateAnyDate;
    }
    if (!policy.foremanCanEditPastTasks) return false;
    final window = policy.editWindowDays;
    if (window == null) return true;
    return !taskDate.isBefore(
      operationalToday.subtract(Duration(days: window)),
    );
  }

  static bool canEditDate(AppUserProfile profile, TaskItemData task) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return policy.foremanCanEditDate;
  }

  static bool canEditAxesWork(AppUserProfile profile, TaskItemData task) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return policy.foremanCanEditAxesWork;
  }

  static bool canEditAssignees(AppUserProfile profile, TaskItemData task) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return policy.foremanCanEditAssignees;
  }

  static bool canEditStatus(AppUserProfile profile, TaskItemData task) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return policy.foremanCanEditStatus;
  }

  static bool canDeletePhoto(
    AppUserProfile profile,
    TaskItemData task,
    String photoStage,
  ) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return photoStage == 'after'
        ? policy.foremanCanDeleteAfterPhotos
        : policy.foremanCanDeleteBeforePhotos;
  }

  static bool canDeleteTask(AppUserProfile profile, TaskItemData task) {
    if (!canEditTask(profile, task)) return false;
    if (profile.isAdmin) return true;
    final policy = forObject(task.objectName);
    return policy.foremanCanDeleteTask;
  }

  static String lockedMessage(TaskItemData task) {
    final policy = forObject(task.objectName);
    if (task.date.isBefore(operationalToday)) {
      if (!policy.foremanCanEditPastTasks) {
        return 'Редактирование закрыто настройками объекта: старые задачи менять нельзя.';
      }
      final window = policy.editWindowDays;
      if (window != null) {
        return 'Срок редактирования истёк: для объекта доступно $window дн. после даты задачи.';
      }
    }
    return 'Редактирование этой задачи недоступно для текущей роли или настроек объекта.';
  }
}

import '../../data/app_state.dart';
import '../../models/app_user_profile.dart';
import '../../models/task_item_data.dart';

class TaskEditPolicy {
  static DateTime get operationalToday {
    final moscowNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(moscowNow.year, moscowNow.month, moscowNow.day);
  }

  static bool canCreateForDate(AppUserProfile profile, DateTime date) {
    if (profile.isAdmin) return true;
    return profile.isForeman && AppState.isSameDay(date, operationalToday);
  }

  static bool canEditTask(AppUserProfile profile, TaskItemData task) {
    if (profile.isAdmin) return true;
    return profile.isForeman && AppState.isSameDay(task.date, operationalToday);
  }

  static String lockedMessage(TaskItemData task) {
    if (task.date.isBefore(operationalToday)) {
      return 'Редактирование закрыто: прораб может менять задачу и фотографии только в день задачи.';
    }
    return 'Редактирование этой задачи недоступно для текущей роли.';
  }
}

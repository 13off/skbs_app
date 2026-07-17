class TaskActContext {
  final String milestoneTitle;
  final String milestoneLocation;
  final int milestoneProgressPercent;
  final String checklistTitle;
  final int checklistProgressPercent;
  final String checklistStateTitle;
  final bool checklistIsCritical;

  const TaskActContext({
    required this.milestoneTitle,
    required this.milestoneLocation,
    required this.milestoneProgressPercent,
    required this.checklistTitle,
    required this.checklistProgressPercent,
    required this.checklistStateTitle,
    required this.checklistIsCritical,
  });
}

from pathlib import Path

path = Path('lib/features/milestones/presentation/milestone_detail_screen.dart')
text = path.read_text(encoding='utf-8')
old = '''      await MilestoneRepository.linkTask(
        taskId: taskId,
        milestoneId: milestone.id,
        checklistItemId: item.id,
      );
      await refresh();
'''
new = '''      await refresh();
'''
if old in text:
    text = text.replace(old, new, 1)
elif 'MilestoneRepository.linkTask(' in text:
    raise SystemExit('Unexpected legacy link block')
path.write_text(text, encoding='utf-8')

Path('tool/fix_task_goal_linking.py').unlink(missing_ok=True)

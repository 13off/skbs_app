alter table public.task_milestone_links
  add column if not exists progress_percent integer not null default 0;

alter table public.task_milestone_links
  drop constraint if exists task_milestone_links_progress_percent_check;

alter table public.task_milestone_links
  add constraint task_milestone_links_progress_percent_check
  check (progress_percent between 0 and 100);

-- Сохраняем прежний смысл уже выполненных связанных задач.
update public.task_milestone_links as link
set progress_percent = 100
from public.tasks as task
where task.id = link.task_id
  and task.status = 'Выполнено'
  and link.progress_percent = 0;

create index if not exists task_action_audit_actor_user_id_idx
  on public.task_action_audit(actor_user_id);

create index if not exists task_action_audit_object_id_idx
  on public.task_action_audit(object_id);

create index if not exists tasks_deleted_by_idx
  on public.tasks(deleted_by);

create index if not exists tasks_restored_by_idx
  on public.tasks(restored_by);

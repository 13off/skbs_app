create index if not exists recruitment_status_history_stage_id_idx
  on public.recruitment_status_history(stage_id)
  where stage_id is not null;

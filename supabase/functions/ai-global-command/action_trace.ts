type UnknownMap = Record<string, unknown>;

function map(value: unknown): UnknownMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownMap
    : {};
}

function text(value: unknown, max = 240): string {
  return String(value ?? "").trim().slice(0, max);
}

function numberValue(value: unknown): number | null {
  const parsed = Number(String(value ?? "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

function traceStep(rawAction: unknown): UnknownMap | null {
  const action = map(rawAction);
  const type = text(action.type, 80);
  const payload = map(action.payload);

  switch (type) {
    case "prepare_timesheet_correction": {
      const id = text(payload.employee_id, 80);
      const label = text(payload.employee_name, 180);
      const shifts = numberValue(payload.shifts);
      if (!id || !label || shifts == null) return null;
      return {
        k: "timesheet",
        et: "employee",
        id,
        label,
        object: text(payload.object_name, 180),
        date: text(payload.date, 10),
        shifts,
      };
    }
    case "assign_candidate_responsible": {
      const id = text(payload.application_id, 80);
      const label = text(payload.candidate_name, 180);
      if (!id || !label) return null;
      return {
        k: "candidate_responsible",
        et: "candidate",
        id,
        label,
        responsible_id: text(payload.responsible_user_id, 80),
        responsible: text(payload.responsible_name, 180),
      };
    }
    case "move_candidate_stage": {
      const id = text(payload.application_id, 80);
      const label = text(payload.candidate_name, 180);
      if (!id || !label) return null;
      return {
        k: "candidate_stage",
        et: "candidate",
        id,
        label,
        stage_id: text(payload.stage_id, 80),
        stage: text(payload.stage_title, 180),
      };
    }
    case "advance_procurement_status": {
      const id = text(payload.request_id, 80);
      const label = text(payload.request_title, 220);
      if (!id || !label) return null;
      return {
        k: "procurement_status",
        et: "procurement",
        id,
        label,
        object: text(payload.object_name, 180),
        status: text(payload.new_status, 60),
        status_title: text(payload.new_status_title, 120),
      };
    }
    case "send_candidate_message": {
      const id = text(payload.application_id, 80);
      const label = text(payload.candidate_name, 180);
      if (!id || !label) return null;
      return {
        k: "candidate_message",
        et: "candidate",
        id,
        label,
        source: text(payload.source, 30),
      };
    }
    case "open_candidate_detail": {
      const id = text(payload.application_id, 80);
      const label = text(payload.candidate_name, 180);
      if (!id || !label) return null;
      return {
        k: "candidate_open",
        et: "candidate",
        id,
        label,
      };
    }
    default:
      return null;
  }
}

function traceSteps(action: UnknownMap): UnknownMap[] {
  if (text(action.type, 80) !== "voice_compound_batch") {
    const step = traceStep(action);
    return step == null ? [] : [step];
  }

  const payload = map(action.payload);
  const rawActions = Array.isArray(payload.actions) ? payload.actions : [];
  const steps: UnknownMap[] = [];
  for (const raw of rawActions.slice(0, 30)) {
    const nested = map(raw);
    if (text(nested.type, 80) === "voice_compound_batch") continue;
    const step = traceStep(nested);
    if (step != null) steps.push(step);
  }
  return steps;
}

export function buildActionConversation({
  action,
  date,
  objectName,
}: {
  action: UnknownMap;
  date: string;
  objectName: string;
}): UnknownMap | null {
  const steps = traceSteps(action);
  if (steps.length === 0) return null;

  const payload = JSON.stringify({
    v: 1,
    iat: Date.now(),
    steps,
  });
  if (payload.length > 7800) return null;

  return {
    topic: "action_trace",
    query_mode: "action",
    date,
    prompt: payload,
    object_name: objectName,
  };
}

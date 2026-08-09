import { normalized, resultWithAction } from "./shared.ts";

export type NavigationTarget = {
  screen: string;
  title: string;
};

export function navigationTarget(prompt: string): NavigationTarget | null {
  const value = normalized(prompt);
  if (!/^(?:открой|открыть|перейди|перейти|зайди|зайти|иди\s+в|давай\s+в)\b/.test(value)) {
    return null;
  }

  const targets: Array<[RegExp, string, string]> = [
    [/(?:уведомлен|оповещен)/, "notifications", "Уведомления"],
    [/(?:настройк|параметр)/, "settings", "Настройки"],
    [/(?:сотрудник|люд|персонал|бригада|работник)/, "employees", "Сотрудники"],
    [/(?:табел|смен|выход|учет\s+времени)/, "timesheet", "Табель"],
    [/(?:задач|наряд|работы)/, "tasks", "Задачи"],
    [/(?:выплат|бухгалтер|зарплат|расчет|начислен)/, "payments", "Выплаты"],
    [/(?:кандидат|подбор|hr|эйчар|найм|соискател|ваканс)/, "recruitment", "HR и кандидаты"],
    [/(?:юрид|юрист|договор|правов|претензи)/, "legal", "Юридическое"],
    [/(?:поставщик|контрагент)/, "suppliers", "Поставщики"],
    [/(?:доставк|логист)/, "deliveries", "Доставки"],
    [/(?:снабжен|закуп|заявк|материал)/, "procurement", "Снабжение"],
    [/(?:цел|этап|план\s+работ)/, "milestones", "Цели"],
    [/(?:инструмент|трудоустрой|документооборот)/, "tools", "Инструменты"],
  ];
  for (const [pattern, screen, title] of targets) {
    if (pattern.test(value)) return { screen, title };
  }
  return null;
}

function isManager(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

export function canOpenScreen(role: string, screen: string): boolean {
  if (isManager(role)) return true;
  const shared = new Set(["notifications", "settings", "tools"]);
  if (shared.has(screen)) return true;

  if (role === "foreman") {
    return new Set(["employees", "timesheet", "tasks", "milestones"]).has(
      screen,
    );
  }
  if (role === "accountant") {
    return new Set(["timesheet", "payments"]).has(screen);
  }
  if (role === "hr") return screen === "recruitment";
  if (role === "lawyer") return screen === "legal";
  if (role === "procurement") {
    return new Set(["procurement", "suppliers", "deliveries"]).has(screen);
  }
  if (role === "employee") {
    return new Set(["notifications", "settings"]).has(screen);
  }
  return false;
}

export function buildNavigationResult({
  target,
  role,
  date,
  objectName,
  prompt,
}: {
  target: NavigationTarget;
  role: string;
  date: string;
  objectName: string;
  prompt: string;
}) {
  if (!canOpenScreen(role, target.screen)) {
    return {
      error: `Раздел «${target.title}» недоступен текущей роли`,
      status: 403,
    };
  }
  return {
    body: resultWithAction({
      title: target.title,
      summary: `Открыть раздел «${target.title}».`,
      date,
      objectName,
      action: {
        id: crypto.randomUUID(),
        type: "open_screen",
        title: `Открыть ${target.title}`,
        button_label: "Открыть",
        confirmation_required: false,
        payload: {
          screen: target.screen,
          object_name: objectName,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

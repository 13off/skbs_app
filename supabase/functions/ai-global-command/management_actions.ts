import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import {
  clean,
  nameMatches,
  normalized,
  resultWithAction,
  tokens,
} from "./shared.ts";

type ObjectRow = { id: string; name: string; is_active: boolean };
type MilestoneRow = {
  id: string;
  object_name: string;
  title: string;
  status: string;
  target_date: string;
};
type SupplierRow = { id: string; name: string; is_active: boolean };

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function procurementRole(role: string) {
  return managerRole(role) || role === "procurement";
}

function significant(value: string): string[] {
  const ignored = new Set([
    "создай", "создать", "добавь", "добавить", "объект", "объекта", "цель",
    "цели", "этап", "этапа", "переименуй", "переименовать", "архивируй",
    "архивировать", "восстанови", "восстановить", "поставщик", "поставщика",
    "скрой", "скрыть", "отметь", "отметить", "статус", "выполнено", "готово",
    "перенесено", "подготовка", "запланировано", "новый", "новая", "в", "на",
    "по", "до", "из", "и", "а", "с", "со",
  ]);
  return tokens(value).filter((token) => token.length >= 3 && !ignored.has(token));
}

function score(prompt: string, title: string): number {
  const expected = significant(title);
  if (expected.length === 0) return 0;
  const actual = significant(prompt);
  let matched = 0;
  for (const item of expected) {
    if (actual.some((token) => {
      if (token === item) return true;
      if (Math.min(token.length, item.length) >= 5) {
        return token.startsWith(item) || item.startsWith(token);
      }
      return false;
    })) matched += 1;
  }
  return matched / expected.length;
}

function uniqueBest<T>(rows: T[], scorer: (row: T) => number, minimum = 0.45): T | null {
  const ranked = rows
    .map((row) => ({ row, score: scorer(row) }))
    .filter((item) => item.score >= minimum)
    .sort((a, b) => b.score - a.score);
  if (ranked.length === 0) return rows.length === 1 ? rows[0] : null;
  if (ranked.length > 1 && Math.abs(ranked[0].score - ranked[1].score) < 0.0001) {
    return null;
  }
  return ranked[0].row;
}

function stripQuotes(value: string) {
  return value.trim().replace(/^[«\"']+|[»\"']+$/g, "").trim();
}

function objectCreateName(prompt: string): string {
  const match = prompt.match(/(?:создай|добавь)\s+(?:новый\s+)?объект\s+(.+)$/i);
  return stripQuotes(clean(match?.[1], 180));
}

function objectRenameNames(prompt: string): { oldName: string; newName: string } | null {
  const match = prompt.match(/переимен(?:уй|овать)\s+объект\s+(.+?)\s+в\s+(.+)$/i);
  if (!match) return null;
  const oldName = stripQuotes(clean(match[1], 180));
  const newName = stripQuotes(clean(match[2], 180));
  return oldName && newName ? { oldName, newName } : null;
}

export function objectManagementIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:создай|добавь|переимен|архивир|восстанов).*(?:объект)|(?:объект).*(?:переимен|архивир|восстанов)/.test(value);
}

export async function buildObjectManagement({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!managerRole(role)) {
    return { error: "Управление объектами доступно только руководителю", status: 403 };
  }
  const value = normalized(prompt);
  const { data, error } = await client
    .from("objects")
    .select("id, name, is_active")
    .eq("company_id", companyId)
    .order("name");
  if (error) throw error;
  const objects = (data ?? []) as ObjectRow[];

  if (/(?:создай|добавь)/.test(value)) {
    const name = objectCreateName(prompt);
    if (name.length < 2) return { error: "Не понял название нового объекта", status: 400 };
    if (objects.some((item) => normalized(item.name) === normalized(name) && item.is_active)) {
      return { error: `Объект «${name}» уже существует`, status: 400 };
    }
    return {
      body: resultWithAction({
        title: "Создание объекта подготовлено",
        summary: `Создать объект «${name}».`,
        highlights: [`Название: ${name}`],
        warnings: ["Объект появится только после подтверждения."],
        date,
        action: {
          id: crypto.randomUUID(),
          type: "manage_object",
          title: "Создать объект",
          button_label: "Проверить создание",
          confirmation_required: true,
          payload: { operation: "create", new_name: name, source_prompt: prompt },
        },
      }),
      status: 200,
    };
  }

  if (/переимен/.test(value)) {
    const names = objectRenameNames(prompt);
    if (!names) return { error: "Скажи: переименуй объект Старое название в Новое название", status: 400 };
    const oldObject = uniqueBest(objects.filter((item) => item.is_active), (item) => score(names.oldName, item.name), 0.5);
    if (!oldObject) return { error: "Не смог однозначно определить объект для переименования", status: 409 };
    if (objects.some((item) => normalized(item.name) === normalized(names.newName))) {
      return { error: `Объект «${names.newName}» уже существует или находится в архиве`, status: 400 };
    }
    return {
      body: resultWithAction({
        title: "Переименование объекта подготовлено",
        summary: `«${oldObject.name}» → «${names.newName}».`,
        highlights: [`Было: ${oldObject.name}`, `Станет: ${names.newName}`],
        warnings: ["Название изменится во связанных данных только после подтверждения."],
        date,
        action: {
          id: crypto.randomUUID(),
          type: "manage_object",
          title: "Переименовать объект",
          button_label: "Проверить переименование",
          confirmation_required: true,
          payload: {
            operation: "rename",
            old_name: oldObject.name,
            new_name: names.newName,
            source_prompt: prompt,
          },
        },
      }),
      status: 200,
    };
  }

  const restore = /восстанов/.test(value);
  const source = objects.filter((item) => restore ? !item.is_active : item.is_active);
  const object = uniqueBest(source, (item) => score(prompt, item.name), 0.45);
  if (!object) return { error: "Не смог однозначно определить объект", status: 409 };
  const operation = restore ? "restore" : "archive";
  return {
    body: resultWithAction({
      title: restore ? "Восстановление объекта подготовлено" : "Архивация объекта подготовлена",
      summary: `${restore ? "Восстановить" : "Архивировать"} объект «${object.name}».`,
      highlights: [object.name],
      warnings: [restore
        ? "Объект вернётся в рабочий список после подтверждения."
        : "Данные сохранятся, но объект исчезнет из рабочего списка после подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "manage_object",
        title: restore ? "Восстановить объект" : "Архивировать объект",
        button_label: restore ? "Проверить восстановление" : "Проверить архивацию",
        confirmation_required: true,
        payload: { operation, old_name: object.name, source_prompt: prompt },
      },
    }),
    status: 200,
  };
}

function russianMonth(value: string): number | null {
  const month = normalized(value);
  const names = [
    "январ", "феврал", "март", "апрел", "ма", "июн", "июл", "август",
    "сентябр", "октябр", "ноябр", "декабр",
  ];
  const index = names.findIndex((name) => month.startsWith(name));
  return index >= 0 ? index + 1 : null;
}

function targetDateFromPrompt(prompt: string, fallbackDate: string): string {
  const value = normalized(prompt);
  const word = value.match(/\b(\d{1,2})\s+(январ\w*|феврал\w*|март\w*|апрел\w*|ма[йя]|июн\w*|июл\w*|август\w*|сентябр\w*|октябр\w*|ноябр\w*|декабр\w*)(?:\s+(20\d{2}))?/);
  if (!word) return fallbackDate;
  const month = russianMonth(word[2]);
  if (month == null) return fallbackDate;
  const baseYear = Number(fallbackDate.slice(0, 4));
  const year = Number(word[3] ?? baseYear);
  return `${year}-${String(month).padStart(2, "0")}-${String(Number(word[1])).padStart(2, "0")}`;
}

function milestoneCreateTitle(prompt: string): string {
  const match = prompt.match(/(?:создай|добавь)\s+(?:новую\s+)?(?:цель|этап)\s+(.+)$/i);
  if (!match) return "";
  return stripQuotes(clean(match[1], 300))
    .replace(/\s+до\s+\d{1,2}(?:[./]\d{1,2}(?:[./]20\d{2})?|\s+[а-яё]+(?:\s+20\d{2})?)\s*$/i, "")
    .trim();
}

function milestoneStatus(prompt: string): string | null {
  const value = normalized(prompt);
  if (/(?:выполн|заверш|готова?$)/.test(value)) return "completed";
  if (/перенес/.test(value)) return "postponed";
  if (/(?:готов\w*\s+к\s+выполн)/.test(value)) return "ready";
  if (/подготов/.test(value)) return "preparing";
  if (/заплан/.test(value)) return "planned";
  return null;
}

export function milestoneManagementIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const entity = /(?:цель|этап)/.test(value);
  const action = /(?:создай|добавь|отмет|постав|перенес|выполн|заверш|подготов)/.test(value);
  return entity && action;
}

export async function buildMilestoneManagement({
  client,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  const isForeman = role === "foreman";
  if (!managerRole(role) && !isForeman) {
    return { error: "Управление целями недоступно текущей роли", status: 403 };
  }
  const objectName = isForeman ? assignedObject : requestedObject;
  if (!objectName) return { error: "Для голосового управления целью выбери объект", status: 400 };
  const value = normalized(prompt);

  if (/(?:создай|добавь)/.test(value)) {
    const title = milestoneCreateTitle(prompt);
    if (title.length < 2) return { error: "Не понял название новой цели", status: 400 };
    const targetDate = targetDateFromPrompt(prompt, date);
    return {
      body: resultWithAction({
        title: "Новая цель подготовлена",
        summary: `${title} · ${objectName} · срок ${targetDate}.`,
        highlights: [title, `Объект: ${objectName}`, `Срок: ${targetDate}`],
        warnings: ["Цель создастся после подтверждения. Чек-лист можно дополнить отдельно."],
        objectName,
        date,
        action: {
          id: crypto.randomUUID(),
          type: "manage_milestone",
          title: "Создать цель",
          button_label: "Проверить цель",
          confirmation_required: true,
          payload: {
            operation: "create",
            object_name: objectName,
            title,
            target_date: targetDate,
            source_prompt: prompt,
          },
        },
      }),
      status: 200,
    };
  }

  const { data, error } = await client
    .from("project_milestones")
    .select("id, object_name, title, status, target_date")
    .eq("object_name", objectName)
    .order("target_date", { ascending: true })
    .limit(100);
  if (error) throw error;
  const milestones = (data ?? []) as MilestoneRow[];
  const milestone = uniqueBest(milestones, (item) => score(prompt, item.title), 0.4);
  if (!milestone) return { error: "Не смог однозначно определить цель", status: 409 };
  const status = milestoneStatus(prompt);
  if (!status) return { error: "Не понял новый статус цели", status: 400 };
  if (status === milestone.status) return { error: `Цель «${milestone.title}» уже имеет этот статус`, status: 400 };
  return {
    body: resultWithAction({
      title: "Статус цели подготовлен",
      summary: `${milestone.title}: ${milestone.status} → ${status}.`,
      highlights: [milestone.title, `Новый статус: ${status}`],
      warnings: ["Статус цели изменится только после подтверждения."],
      objectName,
      date,
      action: {
        id: crypto.randomUUID(),
        type: "manage_milestone",
        title: "Изменить статус цели",
        button_label: "Проверить статус",
        confirmation_required: true,
        payload: {
          operation: "status",
          milestone_id: milestone.id,
          milestone_title: milestone.title,
          object_name: objectName,
          old_status: milestone.status,
          new_status: status,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

function supplierNameAfterVerb(prompt: string): string {
  const match = prompt.match(/(?:добавь|создай)\s+(?:нового\s+)?поставщика\s+(.+)$/i);
  return stripQuotes(clean(match?.[1], 220));
}

export function supplierManagementIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:добавь|создай|скрой|архивир).*(?:поставщик)|(?:поставщик).*(?:скрой|архивир)/.test(value);
}

export async function buildSupplierManagement({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!procurementRole(role)) {
    return { error: "Управление поставщиками недоступно текущей роли", status: 403 };
  }
  const value = normalized(prompt);
  const { data, error } = await client
    .from("procurement_suppliers")
    .select("id, name, is_active")
    .eq("company_id", companyId)
    .order("name");
  if (error) throw error;
  const suppliers = (data ?? []) as SupplierRow[];

  if (/(?:добавь|создай)/.test(value)) {
    const name = supplierNameAfterVerb(prompt);
    if (name.length < 2) return { error: "Не понял название поставщика", status: 400 };
    if (suppliers.some((item) => item.is_active && normalized(item.name) === normalized(name))) {
      return { error: `Поставщик «${name}» уже существует`, status: 400 };
    }
    return {
      body: resultWithAction({
        title: "Новый поставщик подготовлен",
        summary: `Добавить поставщика «${name}».`,
        highlights: [name],
        warnings: ["Контакты можно заполнить позже в карточке поставщика."],
        date,
        action: {
          id: crypto.randomUUID(),
          type: "manage_supplier",
          title: "Добавить поставщика",
          button_label: "Проверить поставщика",
          confirmation_required: true,
          payload: { operation: "create", supplier_name: name, source_prompt: prompt },
        },
      }),
      status: 200,
    };
  }

  const supplier = uniqueBest(
    suppliers.filter((item) => item.is_active),
    (item) => score(prompt, item.name),
    0.45,
  );
  if (!supplier) return { error: "Не смог однозначно определить поставщика", status: 409 };
  return {
    body: resultWithAction({
      title: "Архивация поставщика подготовлена",
      summary: `Скрыть поставщика «${supplier.name}».`,
      highlights: [supplier.name],
      warnings: ["Поставщик исчезнет из рабочего списка после подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "manage_supplier",
        title: "Скрыть поставщика",
        button_label: "Проверить архивацию",
        confirmation_required: true,
        payload: {
          operation: "archive",
          supplier_id: supplier.id,
          supplier_name: supplier.name,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

export function uiSettingIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:темн|светл).*(?:тем)|(?:тем).*(?:темн|светл)|(?:масштаб).*(?:80|90|100|110|120)/.test(value);
}

export function buildUiSetting({ prompt, date }: { prompt: string; date: string }) {
  const value = normalized(prompt);
  let setting = "";
  let rawValue: string | number | boolean = "";
  if (/(?:темн).*(?:тем)|(?:тем).*(?:темн)/.test(value)) {
    setting = "dark_theme";
    rawValue = true;
  } else if (/(?:светл).*(?:тем)|(?:тем).*(?:светл)/.test(value)) {
    setting = "dark_theme";
    rawValue = false;
  } else {
    const scale = value.match(/(?:масштаб).*?\b(80|90|100|110|120)\b/);
    if (!scale) return { error: "Доступны масштабы 80, 90, 100, 110 или 120 процентов", status: 400 };
    setting = "ui_scale";
    rawValue = Number(scale[1]);
  }
  const summary = setting === "dark_theme"
    ? `${rawValue === true ? "Включить тёмную" : "Включить светлую"} тему.`
    : `Установить масштаб интерфейса ${rawValue}%.`;
  return {
    body: resultWithAction({
      title: "Настройка интерфейса",
      summary,
      highlights: [summary],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "toggle_app_setting",
        title: summary,
        button_label: "Применить",
        confirmation_required: false,
        payload: { setting, value: rawValue, source_prompt: prompt },
      },
    }),
    status: 200,
  };
}

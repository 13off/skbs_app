import {
  actionResponse,
  clean,
  type EmployeeRow,
  json,
  moneyFromPrompt,
  normalized,
  paymentType,
  requestedTime,
} from "./shared.ts";

export function buildPeopleAction({
  actionKind,
  prompt,
  objectName,
  date,
  employee,
}: {
  actionKind: string;
  prompt: string;
  objectName: string;
  date: string;
  employee: EmployeeRow | null;
}): Response | null {
  if (actionKind === "create_employee_draft") {
    if (!objectName) return json({ error: "Выбери конкретный объект для сотрудника" }, 400);
    const value = clean(
      prompt.replace(/.*?(?:сотрудника|работника|человека)\s*/i, ""),
      240,
    );
    const beforePosition = value.split(/\s+(?:на должность|должность|как)\s+/i);
    const fio = clean(beforePosition[0], 120);
    const positionMatch = normalized(prompt).match(
      /(?:на должность|должность|как)\s+([^,.;]+?)(?:\s+(?:ставк|телефон)|$)/,
    );
    const position = clean(positionMatch?.[1], 100);
    const phoneMatch = prompt.match(/(?:\+7|8)[\d\s()+-]{9,}/);
    const rateMatch = normalized(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
    const dailyRate = rateMatch ? Number(rateMatch[1].replace(/\s/g, "")) : 6000;
    if (fio.length < 5) return json({ error: "Укажи ФИО нового сотрудника" }, 400);
    return json(actionResponse({
      type: actionKind,
      title: "Карточка нового сотрудника подготовлена",
      button: "Открыть карточку сотрудника",
      summary: `${fio}. Объект: ${objectName}.`,
      highlights: [
        `ФИО: ${fio}`,
        `Объект: ${objectName}`,
        position ? `Должность: ${position}` : "Должность нужно проверить",
        `Ставка: ${dailyRate}`,
      ],
      warnings: ["Сотрудник будет создан только после сохранения обычной формы."],
      objectName,
      date,
      payload: {
        fio,
        position,
        phone: clean(phoneMatch?.[0], 40),
        object_name: objectName,
        daily_rate: dailyRate,
        comment: "Создано из проверенного черновика ИИ",
        source_prompt: prompt,
      },
    }));
  }

  if (actionKind === "prepare_payment") {
    if (!employee) return json({ error: "Укажи одного сотрудника для выплаты" }, 400);
    const amount = moneyFromPrompt(prompt);
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: "Укажи сумму выплаты" }, 400);
    }
    const type = paymentType(prompt);
    return json(actionResponse({
      type: actionKind,
      title: "Черновик выплаты подготовлен",
      button: "Открыть форму выплаты",
      summary: `${employee.fio}: ${amount} ₽.`,
      highlights: [
        `Сотрудник: ${employee.fio}`,
        `Объект: ${employee.object_name}`,
        `Сумма: ${amount} ₽`,
        `Дата: ${date}`,
      ],
      warnings: ["Чек и остальные поля нужно проверить перед сохранением."],
      objectName: employee.object_name,
      date,
      payload: {
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        amount,
        payment_type: type,
        date,
        comment: "Подготовлено ИИ",
        source_prompt: prompt,
      },
    }));
  }

  if (actionKind === "prepare_timesheet_correction") {
    if (!employee) {
      return json({ error: "Укажи одного сотрудника для корректировки табеля" }, 400);
    }
    const shiftMatch = normalized(prompt).match(
      /(\d+(?:[.,]\d+)?)\s*(?:смен|смены|смену)?/,
    );
    const shifts = shiftMatch
      ? Number(shiftMatch[1].replace(",", "."))
      : Number.NaN;
    if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) {
      return json({ error: "Укажи количество смен от 0 до 3" }, 400);
    }
    return json(actionResponse({
      type: actionKind,
      title: "Корректировка табеля подготовлена",
      button: "Проверить и применить",
      summary: `${employee.fio}: ${shifts} смены за ${date}.`,
      highlights: [
        `Сотрудник: ${employee.fio}`,
        `Объект: ${employee.object_name}`,
        `Дата: ${date}`,
        `Новое значение: ${shifts}`,
      ],
      warnings: ["После подтверждения запись табеля будет изменена."],
      objectName: employee.object_name,
      date,
      payload: {
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        date,
        shifts,
        source_prompt: prompt,
      },
    }));
  }

  if (actionKind === "prepare_employee_update") {
    if (!employee) return json({ error: "Укажи одного сотрудника для изменения" }, 400);
    const rateMatch = normalized(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
    const dailyRate = rateMatch
      ? Number(rateMatch[1].replace(/\s/g, ""))
      : Number.NaN;
    if (!Number.isFinite(dailyRate) || dailyRate <= 0) {
      return json({ error: "Сейчас поддерживается изменение ставки: укажи новую сумму" }, 400);
    }
    return json(actionResponse({
      type: actionKind,
      title: "Изменение сотрудника подготовлено",
      button: "Открыть карточку изменения",
      summary: `${employee.fio}: ставка ${employee.daily_rate} → ${dailyRate}.`,
      highlights: [
        `Сотрудник: ${employee.fio}`,
        `Объект: ${employee.object_name}`,
        `Текущая ставка: ${employee.daily_rate}`,
        `Новая ставка: ${dailyRate}`,
      ],
      warnings: ["Обычная форма редактирования откроется после подтверждения."],
      objectName: employee.object_name,
      date,
      payload: {
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        current_daily_rate: employee.daily_rate,
        daily_rate: dailyRate,
        source_prompt: prompt,
      },
    }));
  }

  if (actionKind === "create_reminder") {
    const time = requestedTime(prompt);
    const reminderTitle = clean(
      prompt.replace(/напомни(?:ть)?/i, ""),
      120,
    ) || "Рабочее напоминание";
    return json(actionResponse({
      type: actionKind,
      title: "Напоминание подготовлено",
      button: "Открыть настройки напоминания",
      summary: `${reminderTitle}. ${date} в ${time}.`,
      highlights: [
        `Название: ${reminderTitle}`,
        `Дата: ${date}`,
        `Время: ${time}`,
        objectName ? `Объект: ${objectName}` : "Все объекты",
      ],
      warnings: ["Получателей, push и точное расписание нужно проверить в конструкторе."],
      objectName,
      date,
      payload: {
        title: reminderTitle,
        message: prompt,
        object_name: objectName,
        date,
        local_time: time,
        schedule_type: "once",
        recipient_roles: ["admin"],
        source_prompt: prompt,
      },
    }));
  }

  return null;
}

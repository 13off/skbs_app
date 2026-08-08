import { normalized } from "./shared.ts";

export function employeeWorkflowIntentGuard(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:начн|начни|заверш|закончи).*(?:рабоч|смен|день)|(?:начн|начни).*(?:задач)|(?:добав|прикреп).*(?:фото).*(?:задач)|(?:фото\s+(?:до|после))/.test(
    value,
  );
}

export function flightWorkflowIntentGuard(prompt: string): boolean {
  const value = normalized(prompt);
  const reminder = /(?:напомн).*(?:вылет|рейс)/.test(value);
  const status =
    /(?:прибыл|прилетел|вылетел|улетел|регистрац).*(?:статус|рейс|вылет)/.test(
      value,
    ) ||
    /(?:статус|рейс|вылет).*(?:прибыл|прилетел|вылетел|улетел|регистрац)/.test(
      value,
    );
  const cancellation =
    /(?:отмен).*(?:рейс|вылет)/.test(value) ||
    /(?:рейс|вылет).*(?:отмен)/.test(value);
  return reminder || status || cancellation;
}

export function chatMessageIntentGuard(prompt: string): boolean {
  const value = normalized(prompt);
  const explicitChat = /(?:напиши|отправь).*(?:сообщен|в\s+общий\s+чат|в\s+чат)/.test(
    value,
  );
  const directRecipient = /^(?:напиши|отправь)\s+[^:]{2,80}:\s*.+/.test(value);
  return explicitChat || directRecipient;
}

export function archiveRestoreIntentGuard(prompt: string): boolean {
  return /(?:восстанов).*(?:сотрудник|архив)|(?:сотрудник).*(?:из\s+архив|восстанов)/.test(
    normalized(prompt),
  );
}

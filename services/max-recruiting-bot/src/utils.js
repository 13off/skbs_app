export function escapeMarkdown(value) {
  return String(value ?? '')
    .replaceAll('\\', '\\\\')
    .replace(/([*_~+`\[\]()#>^])/g, '\\$1');
}

export function getUserName(user) {
  const name = [user?.first_name, user?.last_name].filter(Boolean).join(' ').trim();
  return name || `Пользователь ${user?.user_id ?? ''}`.trim();
}

export function normalizePhone(value) {
  const raw = String(value ?? '').trim();
  if (!raw) return null;
  let digits = raw.replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('8')) digits = `7${digits.slice(1)}`;
  if (digits.length === 10) digits = `7${digits}`;
  if (digits.length < 10 || digits.length > 15) return null;
  return `+${digits}`;
}

export function extractPhoneFromAttachments(attachments) {
  for (const attachment of attachments ?? []) {
    if (attachment?.type !== 'contact') continue;
    const vcf = attachment?.payload?.vcf_info;
    if (typeof vcf === 'string') {
      const match = vcf.match(/^TEL(?:;[^:]*)?:(.+)$/im);
      const normalized = normalizePhone(match?.[1]);
      if (normalized) return normalized;
    }
  }
  return null;
}

export function formatApplication(application) {
  const username = application.maxUsername ? `@${application.maxUsername}` : 'не указан';
  const comment = application.comment || 'нет';
  const syncLine = application.syncStatus === 'synced'
    ? `✅ AppСтрой: ${application.appstroyNumber || application.appstroyApplicationId || 'передано'}`
    : `⚠️ AppСтрой: ожидает передачи${application.syncError ? ` (${application.syncError})` : ''}`;
  return [
    `**НОВАЯ ЗАЯВКА ${escapeMarkdown(application.id)}**`,
    '',
    `**Объект:** ${escapeMarkdown(application.objectTitle)}`,
    `**Должность:** ${escapeMarkdown(application.positionTitle)}`,
    `**ФИО:** ${escapeMarkdown(application.fullName)}`,
    `**Возраст:** ${escapeMarkdown(application.age)}`,
    `**Гражданство:** ${escapeMarkdown(application.citizenship)}`,
    `**Опыт:** ${escapeMarkdown(application.experience)}`,
    `**Готовность к выезду:** ${escapeMarkdown(application.readyDate)}`,
    `**Телефон:** ${escapeMarkdown(application.phone)}`,
    `**Комментарий:** ${escapeMarkdown(comment)}`,
    '',
    `**MAX ID:** ${escapeMarkdown(application.maxUserId)}`,
    `**MAX:** ${escapeMarkdown(username)}`,
    `**Источник:** MAX-бот`,
    escapeMarkdown(syncLine),
  ].join('\n');
}

import { createHmac, timingSafeEqual } from 'node:crypto';

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

function secureTextEqual(left, right) {
  const a = Buffer.from(String(left ?? ''), 'utf8');
  const b = Buffer.from(String(right ?? ''), 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

function contactHashMatches(payload, botToken) {
  const vcfInfo = typeof payload?.vcf_info === 'string' ? payload.vcf_info : '';
  const receivedHash = String(payload?.hash ?? '').trim();
  if (!vcfInfo || !receivedHash || !botToken) return false;

  // MAX may return literal escaped CRLF or already-decoded line breaks.
  const variants = new Set([vcfInfo, vcfInfo.replaceAll('\\r\\n', '\r\n')]);
  for (const value of variants) {
    const digest = createHmac('sha256', botToken).update(value, 'utf8').digest();
    const candidates = [
      digest.toString('hex'),
      digest.toString('base64'),
      digest.toString('base64url'),
    ];
    if (candidates.some((candidate) => secureTextEqual(candidate, receivedHash))) {
      return true;
    }
  }
  return false;
}

export function extractVerifiedPhoneFromAttachments(attachments, botToken) {
  for (const attachment of attachments ?? []) {
    if (attachment?.type !== 'contact') continue;
    if (!contactHashMatches(attachment.payload, botToken)) continue;
    const vcf = attachment?.payload?.vcf_info;
    const match = vcf.match(/^TEL(?:;[^:]*)?:(.+)$/im);
    const normalized = normalizePhone(match?.[1]);
    if (normalized) return normalized;
  }
  return null;
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

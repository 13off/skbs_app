from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f'Не найден шаблон: {label}')
    return text.replace(old, new, 1)


root = Path(__file__).resolve().parents[1]
utils_path = root / 'services/max-recruiting-bot/src/utils.js'
bridge_path = root / 'services/max-recruiting-bot/src/appstroy.js'
index_path = root / 'services/max-recruiting-bot/src/index.js'

utils = utils_path.read_text(encoding='utf-8')
utils = replace_once(
    utils,
    "export function escapeMarkdown(value) {",
    "import { createHmac, timingSafeEqual } from 'node:crypto';\n\nexport function escapeMarkdown(value) {",
    'node crypto import',
)
verified_contact = r'''function secureTextEqual(left, right) {
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

'''
utils = replace_once(
    utils,
    'export function extractPhoneFromAttachments(attachments) {',
    verified_contact + 'export function extractPhoneFromAttachments(attachments) {',
    'verified MAX contact helper',
)
utils_path.write_text(utils, encoding='utf-8')

bridge = bridge_path.read_text(encoding='utf-8')
bridge = replace_once(
    bridge,
    "    this.url = url;\n    this.fileUrl = fileUrl || url.replace(/max-recruitment-bridge\\/?$/, 'max-recruitment-file-bridge');",
    "    this.url = url;\n    this.employeeLinkUrl = url.replace(/max-recruitment-bridge\\/?$/, 'max-employee-link-bridge');\n    this.fileUrl = fileUrl || url.replace(/max-recruitment-bridge\\/?$/, 'max-recruitment-file-bridge');",
    'employee link URL',
)
claim_method = r'''  async claimEmployeeLink({
    connectToken,
    maxUserId,
    maxChatId,
    maxUsername,
    phone,
  }) {
    const response = await fetch(this.employeeLinkUrl, {
      method: 'POST',
      headers: {
        'x-appstroy-max-secret': this.secret,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        action: 'claim_token',
        connect_token: connectToken,
        max_user_id: String(maxUserId ?? ''),
        max_chat_id: String(maxChatId ?? ''),
        max_username: String(maxUsername ?? ''),
        phone,
        contact_verified: true,
      }),
      signal: AbortSignal.timeout(30_000),
    });
    return this.parseResponse(response, 'AppСтрой employee link bridge');
  }

'''
bridge = replace_once(
    bridge,
    '  async getCatalog({ force = false } = {}) {',
    claim_method + '  async getCatalog({ force = false } = {}) {',
    'claim employee link method',
)
bridge_path.write_text(bridge, encoding='utf-8')

index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '  extractPhoneFromAttachments,\n  formatApplication,',
    '  extractPhoneFromAttachments,\n  extractVerifiedPhoneFromAttachments,\n  formatApplication,',
    'verified contact import',
)
link_flow = r'''function employeeLinkKeyboard() {
  return inlineKeyboard([[requestContactButton('📱 Подтвердить свой номер')]]);
}

function isEmployeeConnectToken(value) {
  return /^[A-Za-z0-9_-]{24,128}$/.test(String(value ?? '').trim());
}

async function startEmployeeLink(update) {
  const user = update?.user;
  const connectToken = String(update?.payload ?? '').trim();
  if (!user || !isEmployeeConnectToken(connectToken)) return false;

  await store.resetSession(user.user_id);
  await store.setSession(user.user_id, {
    stage: 'employee_link',
    data: {
      connectToken,
      chatId: String(update?.chat_id ?? user.user_id),
    },
  });
  await api.sendMessageToUser(
    user.user_id,
    '**Подключение кабинета сотрудника AppСтрой**\n\nНажмите кнопку ниже и отправьте именно свой контакт. Номер должен совпадать с карточкой сотрудника.',
    { attachments: [employeeLinkKeyboard()] },
  );
  return true;
}

async function handleEmployeeLinkContact(user, message, session) {
  const userId = user.user_id;
  const attachments = message?.body?.attachments ?? [];
  const phone = extractVerifiedPhoneFromAttachments(attachments, token);
  if (!phone) {
    return api.sendMessageToUser(
      userId,
      'Нужно нажать кнопку «Подтвердить свой номер» и отправить контакт, привязанный к вашему аккаунту MAX. Вводить номер текстом нельзя.',
      { attachments: [employeeLinkKeyboard()] },
    );
  }

  try {
    const result = await appstroy.claimEmployeeLink({
      connectToken: session?.data?.connectToken,
      maxUserId: userId,
      maxChatId: session?.data?.chatId || message?.recipient?.chat_id || userId,
      maxUsername: user.username ?? '',
      phone,
    });
    await store.resetSession(userId);
    return api.sendMessageToUser(
      userId,
      `✅ ${result?.message || 'MAX подключён к кабинету сотрудника.'}\n\nВернитесь в AppСтрой — вход продолжится автоматически.`,
    );
  } catch (error) {
    console.error('Не удалось подключить MAX к сотруднику:', error.message);
    if (error.status === 410) {
      await store.resetSession(userId);
      return api.sendMessageToUser(
        userId,
        'Ссылка подключения истекла. Вернитесь в AppСтрой, нажмите «Начать заново» и снова откройте MAX.',
      );
    }
    if (error.status === 409) {
      return api.sendMessageToUser(
        userId,
        'Этот номер не совпадает с карточкой сотрудника. Отправьте свой контакт MAX либо попросите руководителя исправить номер в карточке.',
        { attachments: [employeeLinkKeyboard()] },
      );
    }
    return api.sendMessageToUser(
      userId,
      'Не удалось подключить кабинет. Попробуйте ещё раз через минуту, не закрывая этот диалог.',
      { attachments: [employeeLinkKeyboard()] },
    );
  }
}

'''
index = replace_once(
    index,
    'async function sendMainMenu(userId, firstName = \'\') {',
    link_flow + "async function sendMainMenu(userId, firstName = '') {",
    'employee link flow',
)
index = replace_once(
    index,
    "  const attachments = message.body?.attachments ?? [];\n\n  if (/^\\/(start|menu)(?:\\s|$)/i.test(text)) {",
    "  const attachments = message.body?.attachments ?? [];\n  const session = store.getSession(userId);\n\n  if (session?.stage === 'employee_link') {\n    return handleEmployeeLinkContact(user, message, session);\n  }\n\n  if (/^\\/(start|menu)(?:\\s|$)/i.test(text)) {",
    'employee link message routing',
)
index = replace_once(
    index,
    "  if (/^\\/sync(?:\\s|$)/i.test(text)) return handleAdminSync(user);\n\n  const session = store.getSession(userId);\n  if (!session) {",
    "  if (/^\\/sync(?:\\s|$)/i.test(text)) return handleAdminSync(user);\n\n  if (!session) {",
    'remove duplicate session lookup',
)
index = replace_once(
    index,
    "  if (update.update_type === 'bot_started') {\n    await store.resetSession(update.user.user_id);\n    return sendMainMenu(update.user.user_id, update.user.first_name);\n  }",
    "  if (update.update_type === 'bot_started') {\n    if (await startEmployeeLink(update)) return;\n    await store.resetSession(update.user.user_id);\n    return sendMainMenu(update.user.user_id, update.user.first_name);\n  }",
    'bot_started payload routing',
)
index_path.write_text(index, encoding='utf-8')

print('MAX employee-link routing fix applied')

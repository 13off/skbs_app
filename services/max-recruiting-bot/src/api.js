import { createHash } from 'node:crypto';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const ALLOWED_INBOUND_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

function cleanMimeType(value) {
  return String(value ?? '').split(';')[0].trim().toLowerCase();
}

function firstDirectUrl(value) {
  if (typeof value === 'string' && /^https:\/\//i.test(value)) return value;
  if (!value || typeof value !== 'object') return '';
  if (typeof value.url === 'string' && /^https:\/\//i.test(value.url)) return value.url;
  return '';
}

function collectUrls(value, result = []) {
  const direct = firstDirectUrl(value);
  if (direct) result.push(direct);
  if (!value || typeof value !== 'object') return result;
  for (const nested of Object.values(value)) {
    if (nested !== value?.url) collectUrls(nested, result);
  }
  return result;
}

function inferMimeType(fileName, declaredMimeType, attachmentType) {
  const declared = cleanMimeType(declaredMimeType);
  if (ALLOWED_INBOUND_MIME_TYPES.has(declared)) return declared;
  const lower = String(fileName ?? '').toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return attachmentType === 'image' ? 'image/jpeg' : '';
}

function appendExtension(fileName, mimeType) {
  const cleanName = String(fileName ?? '').trim() || 'document';
  if (/\.[a-z0-9]{2,8}$/i.test(cleanName)) return cleanName;
  const extension = mimeType === 'application/pdf'
    ? '.pdf'
    : mimeType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ? '.docx'
      : mimeType === 'image/png'
        ? '.png'
        : mimeType === 'image/webp'
          ? '.webp'
          : '.jpg';
  return `${cleanName}${extension}`;
}

function maxMessageId(update) {
  const message = update?.message;
  return String(
    message?.body?.mid
      ?? message?.message_id
      ?? message?.id
      ?? update?.timestamp
      ?? `${message?.sender?.user_id ?? 'user'}:${Date.now()}`,
  );
}

function extractDownloadableAttachments(attachments) {
  return (attachments ?? []).flatMap((attachment, index) => {
    const type = String(attachment?.type ?? '').toLowerCase();
    if (type !== 'image' && type !== 'file') return [];
    const payload = attachment?.payload ?? {};
    const directUrl = firstDirectUrl(payload) || firstDirectUrl(attachment?.url);
    const nestedUrls = collectUrls(payload);
    const url = directUrl || nestedUrls.at(-1) || '';
    if (!url) return [];

    const fallbackName = type === 'image' ? `photo-${index + 1}.jpg` : `file-${index + 1}`;
    const fileName = String(
      attachment?.filename
        ?? attachment?.file_name
        ?? payload?.filename
        ?? payload?.file_name
        ?? fallbackName,
    ).trim() || fallbackName;
    const sourceId = String(
      attachment?.id
        ?? attachment?.hash
        ?? payload?.token
        ?? payload?.id
        ?? `${type}:${index}:${url}`,
    );
    const id = `max-${createHash('sha256').update(sourceId).digest('hex').slice(0, 48)}`;
    const size = Number(attachment?.size ?? payload?.size ?? 0);
    const declaredMimeType = attachment?.mime_type
      ?? attachment?.mimeType
      ?? payload?.mime_type
      ?? payload?.mimeType;
    return [{ id, type, url, fileName, size, declaredMimeType }];
  }).slice(0, 10);
}

export function callbackButton(text, payload, intent = 'default') {
  return { type: 'callback', text, payload, intent };
}

export function requestContactButton(text = '📱 Поделиться номером') {
  return { type: 'request_contact', text };
}

export function inlineKeyboard(rows) {
  return {
    type: 'inline_keyboard',
    payload: { buttons: rows },
  };
}

export class MaxApi {
  constructor({ token, baseUrl, debug = false }) {
    if (!token) throw new Error('Не задан BOT_TOKEN');
    this.token = token;
    this.baseUrl = (baseUrl || 'https://platform-api2.max.ru').replace(/\/$/, '');
    this.debug = debug;
    this.fileBridgeSecret = process.env.APPSTROY_BRIDGE_SECRET ?? '';
    this.fileBridgeUrl = process.env.APPSTROY_FILE_BRIDGE_URL
      || String(process.env.APPSTROY_BRIDGE_URL ?? '')
        .replace(/max-recruitment-bridge\/?$/, 'max-recruitment-file-bridge');
    this.maxInboundFileBytes = Number.parseInt(
      process.env.MAX_INBOUND_FILE_MAX_BYTES ?? '20971520',
      10,
    );
  }

  async request(method, path, { query = {}, body } = {}) {
    const url = new URL(`${this.baseUrl}${path}`);
    for (const [key, value] of Object.entries(query)) {
      if (value === undefined || value === null || value === '') continue;
      url.searchParams.set(key, Array.isArray(value) ? value.join(',') : String(value));
    }

    const response = await fetch(url, {
      method,
      headers: {
        Authorization: this.token,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(100_000),
    });

    const raw = await response.text();
    let data = null;
    if (raw) {
      try {
        data = JSON.parse(raw);
      } catch {
        data = { raw };
      }
    }

    if (!response.ok) {
      const message = data?.message || data?.error || raw || `HTTP ${response.status}`;
      const error = new Error(`MAX API ${method} ${path}: ${message}`);
      error.status = response.status;
      error.response = data;
      throw error;
    }

    if (this.debug) {
      console.log(`[MAX API] ${method} ${url.pathname} -> ${response.status}`);
    }
    return data;
  }

  getMe() {
    return this.request('GET', '/me');
  }

  getUpdates(marker) {
    return this.request('GET', '/updates', {
      query: {
        timeout: 30,
        limit: 100,
        marker,
        types: ['bot_started', 'message_created', 'message_callback'],
      },
    });
  }

  sendMessageToUser(userId, text, { attachments, format = 'markdown', notify = true } = {}) {
    return this.request('POST', '/messages', {
      query: { user_id: userId },
      body: {
        text,
        ...(attachments ? { attachments } : {}),
        format,
        notify,
      },
    });
  }

  answerCallback(callbackId, notification = 'Готово') {
    if (!callbackId) return Promise.resolve(null);
    return this.request('POST', '/answers', {
      query: { callback_id: callbackId },
      body: { notification },
    }).catch((error) => {
      console.warn('Не удалось ответить на callback:', error.message);
      return null;
    });
  }

  async downloadAttachment(attachment) {
    const declaredSize = Number.isFinite(attachment.size) ? attachment.size : 0;
    if (declaredSize > this.maxInboundFileBytes) throw new Error('Файл больше 20 МБ');
    const url = new URL(attachment.url);
    if (url.protocol !== 'https:') throw new Error('MAX вернул небезопасную ссылку на файл');

    const response = await fetch(url, {
      redirect: 'follow',
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) throw new Error(`Не удалось скачать файл из MAX: HTTP ${response.status}`);
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > this.maxInboundFileBytes) throw new Error('Файл больше 20 МБ');

    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength === 0) throw new Error('MAX вернул пустой файл');
    if (bytes.byteLength > this.maxInboundFileBytes) throw new Error('Файл больше 20 МБ');

    const mimeType = inferMimeType(
      attachment.fileName,
      response.headers.get('content-type') || attachment.declaredMimeType,
      attachment.type,
    );
    if (!ALLOWED_INBOUND_MIME_TYPES.has(mimeType)) {
      throw new Error('Этот формат файла пока не поддерживается');
    }
    return {
      ...attachment,
      bytes,
      mimeType,
      fileName: appendExtension(attachment.fileName, mimeType),
    };
  }

  async uploadAttachmentToAppStroy(update, attachment, index) {
    if (!this.fileBridgeUrl || !this.fileBridgeSecret) {
      throw new Error('Не настроен шлюз файлов AppСтрой');
    }
    const message = update.message;
    const userId = String(message?.sender?.user_id ?? '');
    const downloaded = await this.downloadAttachment(attachment);
    const form = new FormData();
    form.append('maxUserId', userId);
    form.append('maxChatId', userId);
    form.append('maxMessageId', maxMessageId(update));
    form.append('attachmentId', downloaded.id);
    form.append('text', index === 0 ? String(message?.body?.text ?? '').trim() : '');
    form.append('documentType', 'other');
    form.append('originalName', downloaded.fileName);
    form.append('mimeType', downloaded.mimeType);
    form.append(
      'file',
      new Blob([downloaded.bytes], { type: downloaded.mimeType }),
      downloaded.fileName,
    );

    const response = await fetch(this.fileBridgeUrl, {
      method: 'POST',
      headers: { 'x-appstroy-max-secret': this.fileBridgeSecret },
      body: form,
      signal: AbortSignal.timeout(90_000),
    });
    const raw = await response.text();
    let data = {};
    try {
      data = raw ? JSON.parse(raw) : {};
    } catch {
      data = { raw };
    }
    if (!response.ok) {
      const error = new Error(`AppСтрой file bridge: ${data?.error || raw || `HTTP ${response.status}`}`);
      error.status = response.status;
      error.response = data;
      throw error;
    }
    return data;
  }

  async preprocessInboundAttachments(update) {
    if (update?.update_type !== 'message_created') return false;
    const message = update.message;
    const userId = message?.sender?.user_id;
    if (!userId || message?.sender?.is_bot) return false;
    const allAttachments = message?.body?.attachments ?? [];
    const downloadable = extractDownloadableAttachments(allAttachments);
    if (downloadable.length === 0) return false;

    let uploaded = 0;
    let failed = 0;
    let applicationMissing = false;
    for (const [index, attachment] of downloadable.entries()) {
      try {
        await this.uploadAttachmentToAppStroy(update, attachment, index);
        uploaded += 1;
      } catch (error) {
        if (error?.status === 404) applicationMissing = true;
        failed += 1;
        console.error(`Не удалось принять вложение MAX ${attachment.id}:`, error.message);
      }
    }

    if (uploaded > 0) {
      const status = uploaded === 1 ? 'Файл получен' : `Файлы получены: ${uploaded}`;
      const failedText = failed > 0 ? ` Не удалось обработать: ${failed}.` : '';
      await this.sendMessageToUser(
        userId,
        `${status} и прикреплён${uploaded === 1 ? '' : 'ы'} к заявке в AppСтрой ✅${failedText}`,
      );
      return true;
    }

    if (applicationMissing) return false;
    await this.sendMessageToUser(
      userId,
      'Не удалось сохранить файл. Поддерживаются фотографии, PDF и DOCX до 20 МБ. Попробуйте ещё раз через минуту.',
    );
    return true;
  }

  async pollingLoop(handler) {
    let marker;
    let failures = 0;

    while (true) {
      try {
        const result = await this.getUpdates(marker);
        marker = result?.marker ?? marker;
        failures = 0;

        for (const update of result?.updates ?? []) {
          try {
            if (await this.preprocessInboundAttachments(update)) continue;
            await handler(update);
          } catch (error) {
            console.error('Ошибка обработки события:', error);
          }
        }
      } catch (error) {
        failures += 1;
        const delay = Math.min(30_000, 1_000 * 2 ** Math.min(failures, 5));
        console.error(`Ошибка Long Polling. Повтор через ${delay / 1000} сек:`, error.message);
        await sleep(delay);
      }
    }
  }
}

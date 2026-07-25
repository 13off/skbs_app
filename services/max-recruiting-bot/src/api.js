const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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

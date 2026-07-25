export class AppStroyBridge {
  constructor({ url, secret, debug = false }) {
    if (!url) throw new Error('Не задан APPSTROY_BRIDGE_URL');
    if (!secret) throw new Error('Не задан APPSTROY_BRIDGE_SECRET');
    this.url = url;
    this.secret = secret;
    this.debug = debug;
    this.catalogCache = null;
    this.catalogExpiresAt = 0;
  }

  async request(method, body, query = {}) {
    const url = new URL(this.url);
    for (const [key, value] of Object.entries(query)) {
      if (value === undefined || value === null || value === '') continue;
      url.searchParams.set(key, String(value));
    }

    const response = await fetch(url, {
      method,
      headers: {
        'x-appstroy-max-secret': this.secret,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(30_000),
    });

    const raw = await response.text();
    let data = {};
    if (raw) {
      try {
        data = JSON.parse(raw);
      } catch {
        data = { raw };
      }
    }

    if (!response.ok) {
      const error = new Error(`AppСтрой bridge: ${data?.error || raw || `HTTP ${response.status}`}`);
      error.status = response.status;
      error.response = data;
      throw error;
    }

    if (this.debug) console.log(`[AppСтрой] ${method} ${url.search} -> ${response.status}`);
    return data;
  }

  async getCatalog({ force = false } = {}) {
    const now = Date.now();
    if (!force && this.catalogCache && now < this.catalogExpiresAt) {
      return this.catalogCache;
    }

    const data = await this.request('GET');
    const objects = Array.isArray(data?.objects) ? data.objects : [];
    const catalog = {
      companyId: String(data?.companyId ?? ''),
      objects: objects
        .map((object) => ({
          id: String(object?.id ?? ''),
          title: String(object?.title ?? ''),
          shortDescription: String(object?.shortDescription ?? ''),
          conditions: Array.isArray(object?.conditions)
            ? object.conditions.map((item) => String(item)).filter(Boolean)
            : [],
          positions: Array.isArray(object?.positions)
            ? object.positions
              .map((position) => ({
                id: String(position?.id ?? ''),
                title: String(position?.title ?? ''),
                salaryText: String(position?.salaryText ?? ''),
                scheduleText: String(position?.scheduleText ?? ''),
                conditionsText: String(position?.conditionsText ?? ''),
              }))
              .filter((position) => position.id && position.title)
            : [],
        }))
        .filter((object) => object.id && object.title && object.positions.length > 0),
    };

    if (catalog.objects.length === 0) {
      throw new Error('AppСтрой не вернул активные объекты и вакансии');
    }

    this.catalogCache = catalog;
    this.catalogExpiresAt = now + 5 * 60_000;
    return catalog;
  }

  submitApplication(application) {
    return this.request('POST', {
      action: 'submit_application',
      application: {
        externalApplicationId: application.id,
        maxUserId: application.maxUserId,
        maxChatId: application.maxChatId || application.maxUserId,
        maxUsername: application.maxUsername,
        maxDisplayName: application.maxDisplayName,
        fullName: application.fullName,
        phone: application.phone,
        citizenship: application.citizenship,
        objectId: application.objectId,
        vacancyId: application.positionId,
        positionTitle: application.positionTitle,
        experience: application.experience,
        readyText: application.readyDate,
        age: application.age,
        comment: application.comment,
      },
    });
  }

  ingestCandidateMessage(application, message) {
    return this.request('POST', {
      action: 'ingest_message',
      applicationId: application.appstroyApplicationId,
      externalApplicationId: application.id,
      maxUserId: application.maxUserId,
      maxChatId: application.maxChatId || application.maxUserId,
      maxMessageId: message.id,
      text: message.text,
    });
  }

  async pullOutboundMessages() {
    const data = await this.request('GET', null, { action: 'pull_outbound' });
    return Array.isArray(data?.messages) ? data.messages : [];
  }

  acknowledgeOutbound({ messageId, maxMessageId = '', error = '' }) {
    return this.request('POST', {
      action: 'ack_outbound',
      messageId,
      maxMessageId,
      error,
    });
  }
}

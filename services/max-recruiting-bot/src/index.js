import {
  MaxApi,
  callbackButton,
  inlineKeyboard,
  requestContactButton,
} from './api.js';
import { AppStroyBridge } from './appstroy.js';
import { CITIZENSHIPS, COMPANY } from './config.js';
import { JsonStore } from './store.js';
import {
  escapeMarkdown,
  extractPhoneFromAttachments,
  formatApplication,
  getUserName,
  normalizePhone,
} from './utils.js';

const token = process.env.BOT_TOKEN;
const adminSetupCode = process.env.ADMIN_SETUP_CODE;
const debug = process.env.DEBUG === '1';

if (!token) throw new Error('Создайте .env и заполните BOT_TOKEN');
if (!adminSetupCode || adminSetupCode === 'CHANGE_ME_TO_A_LONG_RANDOM_CODE') {
  console.warn('ВНИМАНИЕ: задайте надёжный ADMIN_SETUP_CODE в .env');
}

const api = new MaxApi({
  token,
  baseUrl: process.env.MAX_API_BASE_URL,
  debug,
});
const appstroy = new AppStroyBridge({
  url: process.env.APPSTROY_BRIDGE_URL,
  secret: process.env.APPSTROY_BRIDGE_SECRET,
  debug,
});
const store = new JsonStore(process.env.DATA_FILE);
await store.init();

function mainMenuKeyboard() {
  return inlineKeyboard([
    [callbackButton('📝 Оставить заявку', 'menu:apply', 'positive')],
    [callbackButton('🏗 Актуальные объекты', 'menu:objects')],
    [callbackButton('ℹ️ Условия работы', 'menu:conditions')],
    [callbackButton('☎️ Связаться со специалистом', 'menu:contact')],
  ]);
}

function objectKeyboard(objects, prefix = 'apply:object') {
  return inlineKeyboard([
    ...objects.map((object) => [callbackButton(object.title, `${prefix}:${object.id}`)]),
    [callbackButton('⬅️ В меню', 'menu:home')],
  ]);
}

function positionKeyboard(object) {
  return inlineKeyboard([
    ...object.positions.map((position) => [
      callbackButton(position.title, `apply:position:${position.id}`),
    ]),
    [callbackButton('⬅️ Выбрать другой объект', 'menu:apply')],
    [callbackButton('❌ Отменить', 'apply:cancel', 'negative')],
  ]);
}

function citizenshipKeyboard() {
  return inlineKeyboard([
    [callbackButton('🇷🇺 РФ', 'apply:citizenship:ru')],
    [callbackButton('🇧🇾 Беларусь', 'apply:citizenship:by')],
    [callbackButton('🇰🇿 Казахстан', 'apply:citizenship:kz')],
    [callbackButton('🇰🇬 Кыргызстан', 'apply:citizenship:kg')],
    [callbackButton('🌍 Другое', 'apply:citizenship:other')],
    [callbackButton('❌ Отменить', 'apply:cancel', 'negative')],
  ]);
}

function findObject(catalog, objectId) {
  return catalog.objects.find((item) => item.id === objectId) ?? null;
}

function findPosition(catalog, objectId, positionId) {
  return findObject(catalog, objectId)?.positions.find((item) => item.id === positionId) ?? null;
}

async function sendTemporaryError(userId) {
  await api.sendMessageToUser(
    userId,
    'Не удалось получить данные из AppСтрой. Попробуйте ещё раз через минуту.',
    { attachments: [inlineKeyboard([[callbackButton('🔄 Повторить', 'menu:apply')], [callbackButton('⬅️ В меню', 'menu:home')]])] },
  );
}

async function sendMainMenu(userId, firstName = '') {
  const greeting = firstName ? `, ${escapeMarkdown(firstName)}` : '';
  await api.sendMessageToUser(
    userId,
    `Здравствуйте${greeting}!\n\nЭто бот по трудоустройству в **${COMPANY.legalName}**. Заявки автоматически передаются в AppСтрой. Выберите нужный раздел:`,
    { attachments: [mainMenuKeyboard()] },
  );
}

async function showObjects(userId) {
  try {
    const catalog = await appstroy.getCatalog();
    const text = catalog.objects.map((object) => {
      const positions = object.positions.map((item) => item.title).join(', ');
      return `**${escapeMarkdown(object.title)}**\n${escapeMarkdown(object.shortDescription)}\nВакансии: ${escapeMarkdown(positions)}`;
    }).join('\n\n');

    await api.sendMessageToUser(userId, `**Актуальные объекты AppСтрой**\n\n${text}`, {
      attachments: [inlineKeyboard([
        [callbackButton('📝 Оставить заявку', 'menu:apply', 'positive')],
        [callbackButton('⬅️ В меню', 'menu:home')],
      ])],
    });
  } catch (error) {
    console.error('Не удалось загрузить объекты AppСтрой:', error.message);
    await sendTemporaryError(userId);
  }
}

async function showConditions(userId) {
  try {
    const catalog = await appstroy.getCatalog();
    const text = catalog.objects.map((object) => {
      const positions = object.positions.map((position) => {
        const details = [position.salaryText, position.scheduleText, position.conditionsText]
          .filter(Boolean)
          .map((item) => `• ${escapeMarkdown(item)}`)
          .join('\n');
        return `**${escapeMarkdown(position.title)}**${details ? `\n${details}` : ''}`;
      }).join('\n\n');
      return `**🏗 ${escapeMarkdown(object.title)}**\n${positions}`;
    }).join('\n\n');

    await api.sendMessageToUser(
      userId,
      `**Условия работы**\n\n${text}\n\nТочные условия подтверждает специалист после получения заявки.`,
      { attachments: [inlineKeyboard([
        [callbackButton('📝 Заполнить анкету', 'menu:apply', 'positive')],
        [callbackButton('⬅️ В меню', 'menu:home')],
      ])] },
    );
  } catch (error) {
    console.error('Не удалось загрузить условия AppСтрой:', error.message);
    await sendTemporaryError(userId);
  }
}

async function startApplication(userId) {
  try {
    const catalog = await appstroy.getCatalog();
    await store.setSession(userId, { stage: 'object', data: {} });
    await api.sendMessageToUser(userId, '**Шаг 1 из 8. Выберите объект:**', {
      attachments: [objectKeyboard(catalog.objects)],
    });
  } catch (error) {
    console.error('Не удалось начать анкету:', error.message);
    await sendTemporaryError(userId);
  }
}

async function cancelApplication(userId) {
  await store.resetSession(userId);
  await api.sendMessageToUser(userId, 'Анкета отменена. Данные не отправлены.');
  await sendMainMenu(userId);
}

async function sendReview(userId, session) {
  try {
    const catalog = await appstroy.getCatalog();
    const data = session.data;
    const object = findObject(catalog, data.objectId);
    const position = findPosition(catalog, data.objectId, data.positionId);
    if (!object || !position) return startApplication(userId);

    const text = [
      '**Проверьте анкету:**',
      '',
      `**Объект:** ${escapeMarkdown(object.title)}`,
      `**Должность:** ${escapeMarkdown(position.title)}`,
      `**ФИО:** ${escapeMarkdown(data.fullName)}`,
      `**Возраст:** ${escapeMarkdown(data.age)}`,
      `**Гражданство:** ${escapeMarkdown(data.citizenship)}`,
      `**Опыт:** ${escapeMarkdown(data.experience)}`,
      `**Готовность к выезду:** ${escapeMarkdown(data.readyDate)}`,
      `**Телефон:** ${escapeMarkdown(data.phone)}`,
      `**Комментарий:** ${escapeMarkdown(data.comment || 'нет')}`,
      '',
      'Нажимая «Согласен и отправить», вы соглашаетесь на обработку указанных персональных данных для рассмотрения заявки на трудоустройство.',
    ].join('\n');

    await store.setSession(userId, { ...session, stage: 'review' });
    await api.sendMessageToUser(userId, text, {
      attachments: [inlineKeyboard([
        [callbackButton('✅ Согласен и отправить', 'apply:submit', 'positive')],
        [callbackButton('🔄 Заполнить заново', 'menu:apply')],
        [callbackButton('❌ Отменить', 'apply:cancel', 'negative')],
      ])],
    });
  } catch (error) {
    console.error('Не удалось подготовить анкету:', error.message);
    await sendTemporaryError(userId);
  }
}

async function notifyAdmins(application) {
  const admins = store.getAdmins();
  if (admins.length === 0) {
    console.warn(`Заявка ${application.id} сохранена, но администраторы ещё не зарегистрированы.`);
    return;
  }

  const text = formatApplication(application);
  await Promise.allSettled(
    admins.map((admin) => api.sendMessageToUser(admin.userId, text)),
  );
}

async function syncApplication(application) {
  const attempts = Number(application.syncAttempts ?? 0) + 1;
  await store.updateApplication(application.id, {
    syncStatus: 'syncing',
    syncAttempts: attempts,
    lastSyncAttemptAt: new Date().toISOString(),
    syncError: '',
  });

  try {
    const result = await appstroy.submitApplication(application);
    return await store.updateApplication(application.id, {
      syncStatus: 'synced',
      syncedAt: new Date().toISOString(),
      syncError: '',
      appstroyApplicationId: String(result?.applicationId ?? ''),
      appstroyNumber: String(result?.number ?? ''),
    });
  } catch (error) {
    console.error(`Не удалось передать ${application.id} в AppСтрой:`, error.message);
    return await store.updateApplication(application.id, {
      syncStatus: 'error',
      syncError: error.message.slice(0, 300),
    });
  }
}

let syncInProgress = false;
async function syncPendingApplications() {
  if (syncInProgress) return { synced: 0, failed: 0 };
  syncInProgress = true;
  let synced = 0;
  let failed = 0;
  try {
    for (const application of store.getPendingApplications(50)) {
      const updated = await syncApplication(application);
      if (updated?.syncStatus === 'synced') synced += 1;
      else failed += 1;
    }
    return { synced, failed };
  } finally {
    syncInProgress = false;
  }
}

async function submitApplication(user, session) {
  if (!session || session.stage !== 'review') {
    await api.sendMessageToUser(user.user_id, 'Анкета не готова. Начните заполнение заново.');
    return startApplication(user.user_id);
  }

  let catalog;
  try {
    catalog = await appstroy.getCatalog();
  } catch (error) {
    console.error('AppСтрой недоступен при отправке:', error.message);
    return sendTemporaryError(user.user_id);
  }

  const object = findObject(catalog, session.data.objectId);
  const position = findPosition(catalog, session.data.objectId, session.data.positionId);
  if (!object || !position) return startApplication(user.user_id);

  const localApplication = await store.addApplication({
    ...session.data,
    objectTitle: object.title,
    positionTitle: position.title,
    maxUserId: String(user.user_id),
    maxChatId: String(user.user_id),
    maxUsername: user.username ?? null,
    maxDisplayName: getUserName(user),
  });

  const application = await syncApplication(localApplication);
  await store.resetSession(user.user_id);
  await notifyAdmins(application);

  if (application?.syncStatus === 'synced') {
    await api.sendMessageToUser(
      user.user_id,
      `Заявка **${escapeMarkdown(application.appstroyNumber || application.id)}** принята и передана в AppСтрой ✅\n\n${COMPANY.managerText}`,
      { attachments: [inlineKeyboard([[callbackButton('⬅️ В главное меню', 'menu:home')]])] },
    );
    return;
  }

  await api.sendMessageToUser(
    user.user_id,
    `Заявка **${escapeMarkdown(localApplication.id)}** принята ✅\n\nСистема автоматически повторит передачу в AppСтрой. Специалист также получил уведомление.`,
    { attachments: [inlineKeyboard([[callbackButton('⬅️ В главное меню', 'menu:home')]])] },
  );
}

async function handleCallback(update) {
  const callback = update.callback;
  const user = callback?.user;
  const payload = callback?.payload ?? '';
  if (!user) return;

  await api.answerCallback(callback.callback_id, 'Принято');

  if (payload === 'menu:home') return sendMainMenu(user.user_id, user.first_name);
  if (payload === 'menu:apply') return startApplication(user.user_id);
  if (payload === 'menu:objects') return showObjects(user.user_id);
  if (payload === 'menu:conditions') return showConditions(user.user_id);
  if (payload === 'menu:contact') {
    return api.sendMessageToUser(
      user.user_id,
      'Оставьте заявку — она сразу появится в AppСтрой, и специалист свяжется с вами.\n\nЕсли анкета уже отправлена, просто дождитесь ответа.',
      { attachments: [inlineKeyboard([
        [callbackButton('📝 Оставить заявку', 'menu:apply', 'positive')],
        [callbackButton('⬅️ В меню', 'menu:home')],
      ])] },
    );
  }
  if (payload === 'apply:cancel') return cancelApplication(user.user_id);

  if (payload.startsWith('apply:object:')) {
    const objectId = payload.slice('apply:object:'.length);
    try {
      const catalog = await appstroy.getCatalog();
      const object = findObject(catalog, objectId);
      if (!object) return startApplication(user.user_id);

      await store.setSession(user.user_id, {
        stage: 'position',
        data: { objectId },
      });
      return api.sendMessageToUser(
        user.user_id,
        `Вы выбрали **${escapeMarkdown(object.title)}**.\n\n**Шаг 2 из 8. Выберите должность:**`,
        { attachments: [positionKeyboard(object)] },
      );
    } catch (error) {
      console.error('Ошибка выбора объекта:', error.message);
      return sendTemporaryError(user.user_id);
    }
  }

  if (payload.startsWith('apply:position:')) {
    const session = store.getSession(user.user_id);
    const positionId = payload.slice('apply:position:'.length);
    try {
      const catalog = await appstroy.getCatalog();
      const position = findPosition(catalog, session?.data?.objectId, positionId);
      if (!session || !position) return startApplication(user.user_id);

      await store.setSession(user.user_id, {
        ...session,
        stage: 'full_name',
        data: { ...session.data, positionId },
      });
      return api.sendMessageToUser(user.user_id, '**Шаг 3 из 8. Напишите полностью ФИО:**\n\nНапример: Иванов Иван Иванович');
    } catch (error) {
      console.error('Ошибка выбора должности:', error.message);
      return sendTemporaryError(user.user_id);
    }
  }

  if (payload.startsWith('apply:citizenship:')) {
    const session = store.getSession(user.user_id);
    const code = payload.slice('apply:citizenship:'.length);
    if (!session || session.stage !== 'citizenship' || !CITIZENSHIPS[code]) {
      return startApplication(user.user_id);
    }

    await store.setSession(user.user_id, {
      ...session,
      stage: 'experience',
      data: { ...session.data, citizenship: CITIZENSHIPS[code] },
    });
    return api.sendMessageToUser(
      user.user_id,
      '**Шаг 6 из 8. Опишите опыт работы:**\n\nНапишите специальность, стаж, разряд и основные виды работ. Если опыта нет — так и напишите.',
    );
  }

  if (payload === 'apply:skip_comment') {
    const session = store.getSession(user.user_id);
    if (!session || session.stage !== 'comment') return startApplication(user.user_id);
    return sendReview(user.user_id, { ...session, data: { ...session.data, comment: '' } });
  }

  if (payload === 'apply:submit') {
    return submitApplication(user, store.getSession(user.user_id));
  }
}

async function handleAdminCommand(user, text) {
  const parts = text.split(/\s+/);
  const providedCode = parts.slice(1).join(' ');
  if (!providedCode || providedCode !== adminSetupCode) {
    await api.sendMessageToUser(user.user_id, 'Неверный код администратора.');
    return true;
  }

  await store.registerAdmin(user);
  await api.sendMessageToUser(
    user.user_id,
    'Вы зарегистрированы как администратор ✅\n\nНовые заявки будут приходить вам в этот диалог и одновременно попадать в AppСтрой.',
  );
  return true;
}

async function handleAdminApplications(user) {
  if (!store.isAdmin(user.user_id)) {
    await api.sendMessageToUser(user.user_id, 'Команда доступна только администратору.');
    return;
  }

  const applications = store.getRecentApplications(10);
  if (applications.length === 0) {
    await api.sendMessageToUser(user.user_id, 'Заявок пока нет.');
    return;
  }

  const text = applications.map((item) => {
    const sync = item.syncStatus === 'synced'
      ? `AppСтрой: ${item.appstroyNumber || 'передано'}`
      : 'AppСтрой: ожидает передачи';
    return `**${escapeMarkdown(item.id)}** — ${escapeMarkdown(item.fullName)}\n${escapeMarkdown(item.objectTitle)}, ${escapeMarkdown(item.positionTitle)}\n${escapeMarkdown(item.phone)}\n${escapeMarkdown(sync)}`;
  }).join('\n\n');
  await api.sendMessageToUser(user.user_id, `**Последние заявки:**\n\n${text}`);
}

async function handleAdminSync(user) {
  if (!store.isAdmin(user.user_id)) {
    await api.sendMessageToUser(user.user_id, 'Команда доступна только администратору.');
    return;
  }
  await api.sendMessageToUser(user.user_id, 'Запускаю повторную передачу заявок в AppСтрой…');
  const result = await syncPendingApplications();
  await api.sendMessageToUser(
    user.user_id,
    `Синхронизация завершена. Передано: ${result.synced}. Осталось с ошибкой: ${result.failed}.`,
  );
}

function maxMessageId(message, update) {
  return String(
    message?.body?.mid
      ?? message?.message_id
      ?? message?.id
      ?? update?.timestamp
      ?? `${message?.sender?.user_id ?? 'user'}:${Date.now()}`,
  );
}

function maxResponseMessageId(response) {
  return String(
    response?.message?.body?.mid
      ?? response?.body?.mid
      ?? response?.message_id
      ?? response?.id
      ?? '',
  );
}

async function forwardCandidateMessageToAppStroy(update, application) {
  const message = update.message;
  const userId = message?.sender?.user_id;
  const text = (message?.body?.text ?? '').trim();
  const attachments = message?.body?.attachments ?? [];

  if (!text) {
    if (attachments.length > 0) {
      await api.sendMessageToUser(
        userId,
        'Файлы из MAX пока не прикрепляются автоматически. Отправьте текст или позвоните специалисту по номеру из вакансии.',
      );
      return true;
    }
    return false;
  }

  try {
    await appstroy.ingestCandidateMessage(application, {
      id: maxMessageId(message, update),
      text,
    });
    await api.sendMessageToUser(userId, 'Сообщение передано HR в AppСтрой ✅');
  } catch (error) {
    console.error('Не удалось передать сообщение кандидата в AppСтрой:', error.message);
    await api.sendMessageToUser(
      userId,
      'Не удалось передать сообщение. Попробуйте ещё раз через минуту.',
    );
  }
  return true;
}

let outboundMessagesInProgress = false;
async function processOutboundMessages() {
  if (outboundMessagesInProgress) return;
  outboundMessagesInProgress = true;
  try {
    const messages = await appstroy.pullOutboundMessages();
    for (const item of messages) {
      try {
        const response = await api.sendMessageToUser(item.maxUserId, item.text);
        await appstroy.acknowledgeOutbound({
          messageId: item.messageId,
          maxMessageId: maxResponseMessageId(response),
        });
      } catch (error) {
        console.error(`Не удалось отправить сообщение ${item.messageId} в MAX:`, error.message);
        await appstroy.acknowledgeOutbound({
          messageId: item.messageId,
          error: error.message.slice(0, 500),
        }).catch((ackError) => console.error('Не удалось записать ошибку отправки:', ackError.message));
      }
    }
  } finally {
    outboundMessagesInProgress = false;
  }
}

async function handleMessage(update) {
  const message = update.message;
  const user = message?.sender;
  if (!user || user.is_bot) return;

  const userId = user.user_id;
  const text = (message.body?.text ?? '').trim();
  const attachments = message.body?.attachments ?? [];

  if (/^\/(start|menu)(?:\s|$)/i.test(text)) {
    await store.resetSession(userId);
    return sendMainMenu(userId, user.first_name);
  }
  if (/^\/cancel(?:\s|$)/i.test(text)) return cancelApplication(userId);
  if (/^\/myid(?:\s|$)/i.test(text)) {
    return api.sendMessageToUser(userId, `Ваш MAX ID: \`${escapeMarkdown(userId)}\``);
  }
  if (/^\/admin(?:\s|$)/i.test(text)) return handleAdminCommand(user, text);
  if (/^\/applications(?:\s|$)/i.test(text)) return handleAdminApplications(user);
  if (/^\/sync(?:\s|$)/i.test(text)) return handleAdminSync(user);

  const session = store.getSession(userId);
  if (!session) {
    const application = store.getLatestSyncedApplicationByUserId(userId);
    if (application && await forwardCandidateMessageToAppStroy(update, application)) return;
    return sendMainMenu(userId, user.first_name);
  }

  if (session.stage === 'full_name') {
    if (text.length < 5 || text.split(/\s+/).length < 2) {
      return api.sendMessageToUser(userId, 'Напишите фамилию, имя и отчество полностью. Если отчества нет — фамилию и имя.');
    }
    await store.setSession(userId, {
      ...session,
      stage: 'age',
      data: { ...session.data, fullName: text },
    });
    return api.sendMessageToUser(userId, '**Шаг 4 из 8. Сколько вам полных лет?**');
  }

  if (session.stage === 'age') {
    const age = Number.parseInt(text, 10);
    if (!Number.isInteger(age) || age < 18 || age > 75) {
      return api.sendMessageToUser(userId, 'Укажите возраст числом от 18 до 75.');
    }
    await store.setSession(userId, {
      ...session,
      stage: 'citizenship',
      data: { ...session.data, age },
    });
    return api.sendMessageToUser(userId, '**Шаг 5 из 8. Выберите гражданство:**', {
      attachments: [citizenshipKeyboard()],
    });
  }

  if (session.stage === 'experience') {
    if (text.length < 2) return api.sendMessageToUser(userId, 'Кратко опишите опыт или напишите «без опыта».');
    await store.setSession(userId, {
      ...session,
      stage: 'ready_date',
      data: { ...session.data, experience: text },
    });
    return api.sendMessageToUser(userId, '**Шаг 7 из 8. Когда готовы выехать или приступить к работе?**\n\nНапример: 01.08.2026, через неделю, готов сейчас.');
  }

  if (session.stage === 'ready_date') {
    if (text.length < 2) return api.sendMessageToUser(userId, 'Напишите ориентировочную дату или срок готовности.');
    await store.setSession(userId, {
      ...session,
      stage: 'phone',
      data: { ...session.data, readyDate: text },
    });
    return api.sendMessageToUser(
      userId,
      '**Шаг 8 из 8. Отправьте номер телефона:**\n\nНажмите кнопку или напишите номер сообщением.',
      { attachments: [inlineKeyboard([[requestContactButton()]])] },
    );
  }

  if (session.stage === 'phone') {
    const phone = extractPhoneFromAttachments(attachments) || normalizePhone(text);
    if (!phone) {
      return api.sendMessageToUser(
        userId,
        'Не удалось распознать номер. Нажмите кнопку «Поделиться номером» или напишите его в формате +7 999 123-45-67.',
        { attachments: [inlineKeyboard([[requestContactButton()]])] },
      );
    }
    await store.setSession(userId, {
      ...session,
      stage: 'comment',
      data: { ...session.data, phone },
    });
    return api.sendMessageToUser(
      userId,
      'Дополнительно напишите важный комментарий: предпочтительный способ связи, вопросы или ограничения. Либо пропустите.',
      { attachments: [inlineKeyboard([[callbackButton('Пропустить', 'apply:skip_comment')]])] },
    );
  }

  if (session.stage === 'comment') {
    return sendReview(userId, { ...session, data: { ...session.data, comment: text } });
  }

  if (session.stage === 'review') {
    return api.sendMessageToUser(userId, 'Проверьте анкету выше и нажмите «Согласен и отправить» либо заполните её заново.');
  }

  return startApplication(userId);
}

async function handleUpdate(update) {
  if (debug) console.log('Update:', JSON.stringify(update));
  if (update.update_type === 'bot_started') {
    await store.resetSession(update.user.user_id);
    return sendMainMenu(update.user.user_id, update.user.first_name);
  }
  if (update.update_type === 'message_created') return handleMessage(update);
  if (update.update_type === 'message_callback') return handleCallback(update);
}

const botInfo = await api.getMe();
const catalog = await appstroy.getCatalog({ force: true });
console.log(`MAX-бот запущен: ${botInfo?.first_name ?? botInfo?.name ?? 'без названия'} (@${botInfo?.username ?? 'без username'})`);
console.log(`AppСтрой подключён: объектов ${catalog.objects.length}, вакансий ${catalog.objects.reduce((sum, object) => sum + object.positions.length, 0)}.`);
console.log(`Администраторов: ${store.getAdmins().length}. Для регистрации: /admin <ADMIN_SETUP_CODE>`);

const initialSync = await syncPendingApplications();
if (initialSync.synced || initialSync.failed) {
  console.log(`Повторная синхронизация: передано ${initialSync.synced}, ошибок ${initialSync.failed}.`);
}
setInterval(() => {
  syncPendingApplications().catch((error) => console.error('Фоновая синхронизация:', error));
}, 60_000).unref();

await processOutboundMessages().catch((error) => console.error('Первая проверка исходящих сообщений:', error));
setInterval(() => {
  processOutboundMessages().catch((error) => console.error('Проверка исходящих сообщений:', error));
}, 5_000).unref();

await api.pollingLoop(handleUpdate);

# AppСтрой — push-уведомления

## Архитектура

1. Любое рабочее событие сначала сохраняется в существующую таблицу `app_notifications`.
2. Внутренний колокольчик продолжает читать `app_notifications`, `app_notification_reads` и `app_notification_clears`.
3. После успешной вставки клиент в режиме best effort вызывает Edge Function `dispatch-push-notification` с ID уже созданного уведомления.
4. Edge Function принимает JWT текущего пользователя, проверяет, что он является автором события, и сама вычисляет получателей.
5. Получатели ограничиваются `company_id`, активным членством, ролью и назначением на объект. Автор события исключается.
6. FCM используется как транспорт для Android, APNs через FCM для iOS и Web Push через FCM/VAPID для PWA.
7. Ошибка push не откатывает и не блокирует основную рабочую запись.

## База данных

- `push_device_tokens` — FCM-токены пользователя и компании.
- `push_notification_deliveries` — серверная идемпотентность и результат доставки.
- `register_current_push_device(...)` — безопасная регистрация и обновление токена.
- `set_current_push_device_enabled(...)` — включение/отключение текущего устройства.
- `unregister_current_push_device(...)` — удаление текущего устройства при выходе.
- Прямые INSERT/UPDATE/DELETE для обычного клиента запрещены.
- Недействительный FCM-токен с кодом `UNREGISTERED` автоматически отключается.

## Клиент

`PushNotificationService`:

- не блокирует запуск приложения при отсутствии Firebase-конфигурации;
- запрашивает разрешение пользователя;
- регистрирует токен и слушает `onTokenRefresh`;
- учитывает Android, iOS и Web;
- удаляет токен при выходе;
- обновляет внутренний колокольчик при foreground-сообщении;
- открывает внутренний экран уведомлений после нажатия;
- хранит только публичную Firebase-конфигурацию из `--dart-define`.

## Секреты

В репозитории и Flutter запрещены:

- Firebase service account JSON;
- Supabase service-role key;
- Apple APNs private key `.p8`;
- любые закрытые ключи подписи.

Firebase service account хранится только как Supabase Edge Function Secret `FIREBASE_SERVICE_ACCOUNT_JSON`.

## Что нужно добавить для фактической доставки

### Firebase Console

Создать или выбрать Firebase project и зарегистрировать три приложения:

- Android package: `ru.appstroy.skbs`;
- iOS bundle ID: `ru.appstroy.mobile`;
- Web app для `https://13off.github.io/appstroy-web/`.

### GitHub Actions Variables

В `13off/skbs_app` → Settings → Secrets and variables → Actions → Variables добавить публичные значения:

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_WEB_APP_ID`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_VAPID_KEY`

Эти значения не являются service account и используются только для инициализации клиентских SDK.

### Web VAPID

Firebase Console → Project settings → Cloud Messaging → Web configuration → Web Push certificates → Generate key pair. Публичный ключ записать в `FIREBASE_VAPID_KEY`.

### Supabase Edge Function Secret

Firebase Console → Project settings → Service accounts → Generate new private key. Полный JSON добавить в Supabase как:

- `FIREBASE_SERVICE_ACCOUNT_JSON`

Опционально:

- `APP_PUBLIC_URL=https://13off.github.io/appstroy-web/`

### Apple APNs

1. Apple Developer → Certificates, Identifiers & Profiles → Keys.
2. Создать ключ с Apple Push Notifications service, скачать `.p8`, сохранить Key ID и Team ID.
3. Firebase Console → Project settings → Cloud Messaging → Apple app → APNs authentication key.
4. Загрузить `.p8`, указать Key ID и Team ID.
5. Для релизной подписанной сборки включить Push Notifications и Background Modes → Remote notifications в provisioning profile проекта `ru.appstroy.mobile`.

Неподписанная проверочная IPA подтверждает сборку кода, но не может служить окончательной проверкой APNs на реальном iPhone.

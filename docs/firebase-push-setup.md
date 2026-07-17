# Firebase push для AppСтрой

Серверная очередь, напоминания и маршрутизация получателей работают в Supabase. Для доставки на реальные устройства нужно один раз подключить Firebase Cloud Messaging.

## 1. Приложения Firebase

В одном Firebase-проекте зарегистрировать:

- Android-приложение с package name `ru.appstroy.mobile`;
- iOS-приложение с bundle id `ru.appstroy.mobile`;
- Web-приложение для PWA.

Для iOS дополнительно подключить APNs key в Firebase Console и включить Push Notifications/Background Modes в Apple-профиле подписи.

## 2. GitHub Actions variables

В репозитории `13off/skbs_app` открыть `Settings → Secrets and variables → Actions → Variables` и добавить публичные значения Firebase:

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_WEB_APP_ID`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_VAPID_KEY`

Это публичная конфигурация клиентских приложений. Она передаётся в Flutter через `--dart-define`, а для Web также подставляется в `firebase-messaging-sw.js` во время сборки.

## 3. Supabase Edge Function Secret

В Supabase Dashboard открыть `Project Settings → Edge Functions → Secrets` и добавить:

- `FIREBASE_SERVICE_ACCOUNT_JSON` — полный JSON сервисного аккаунта Firebase с доступом к Firebase Cloud Messaging API.

Значение сервисного аккаунта нельзя добавлять в GitHub, исходный код, Flutter-клиент или чат.

## 4. Проверка устройства

После новой сборки:

1. Войти в AppСтрой.
2. Открыть `Профиль → Push-уведомления`.
3. Включить «Получать push на этом устройстве».
4. Нажать «Разрешить и подключить».
5. Убедиться, что отображается «Токен зарегистрирован».

Токен хранится с привязкой к пользователю и активной компании. При выходе из аккаунта устройство отключается.

## Что отправляется автоматически

- новые рабочие действия, уже попадающие во внутренний колокольчик;
- новые заявки, сообщения и файлы кандидатов;
- напоминания HR и администратору за день до готовности кандидата к выезду и в день готовности;
- юридические сроки, просроченные документы и действия;
- повторная попытка серверной отправки при временной ошибке.

Напоминания проверяются сервером каждые 5 минут, поэтому приложение может быть закрыто.

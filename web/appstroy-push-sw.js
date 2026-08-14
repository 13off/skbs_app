/*
 * Standards-based Web Push worker for AppСтрой.
 * It uses a narrow scope and does not replace Flutter's offline service worker.
 */

function appRootUrl() {
  return new URL('../', self.registration.scope).href;
}

function iconUrl() {
  return new URL('../icons/AppStroy-192-v2.png', self.registration.scope).href;
}

function safeNotificationTarget(value) {
  var root = new URL(appRootUrl());
  try {
    var target = new URL(value || root.href, root);
    var rootPath = root.pathname.endsWith('/') ? root.pathname : root.pathname + '/';
    var insideApp = target.origin === root.origin &&
      (target.pathname === root.pathname || target.pathname.startsWith(rootPath));
    return insideApp ? target.href : root.href;
  } catch (_) {
    return root.href;
  }
}

self.addEventListener('push', function (event) {
  var payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  var title = payload.title || 'AppСтрой';
  var body = payload.body || 'В приложении есть новое уведомление';
  var link = safeNotificationTarget(payload.link);
  var options = {
    body: body,
    icon: iconUrl(),
    badge: iconUrl(),
    tag: payload.notification_id || undefined,
    renotify: Boolean(payload.notification_id),
    data: {
      link: link,
      notification_id: payload.notification_id || '',
      entity_type: payload.entity_type || '',
      entity_id: payload.entity_id || '',
    },
  };

  event.waitUntil(
    self.registration.showNotification(title, options).then(function () {
      if (self.navigator && 'setAppBadge' in self.navigator) {
        return self.navigator.setAppBadge().catch(function () {});
      }
      return undefined;
    }),
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = safeNotificationTarget(
    event.notification.data && event.notification.data.link
  );

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (windows) {
      for (var index = 0; index < windows.length; index += 1) {
        var client = windows[index];
        if ('navigate' in client) {
          client.navigate(target);
        }
        if ('focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow ? clients.openWindow(target) : undefined;
    }),
  );
});

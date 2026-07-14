import "jsr:@supabase/functions-js/edge-runtime.d.ts";

function escapeForScript(value: string) {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}

Deno.serve((request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, apikey, content-type",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
      },
    });
  }

  if (request.method !== "GET") {
    return new Response("Метод не поддерживается", { status: 405 });
  }

  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const url = new URL(request.url);
  const companyId = (url.searchParams.get("companyInvite") ?? "").trim();
  const tokenHash = (url.searchParams.get("inviteTokenHash") ?? "").trim();
  const inviteType = (url.searchParams.get("inviteType") ?? "").trim().toLowerCase();

  const config = {
    anonKey,
    companyId,
    tokenHash,
    inviteType,
  };

  const html = `<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#f3f1ec">
  <meta name="referrer" content="no-referrer">
  <meta http-equiv="Cache-Control" content="no-store">
  <title>Приглашение в AppСтрой</title>
  <style>
    *{box-sizing:border-box}html,body{margin:0;min-height:100%}body{min-height:100vh;min-height:100dvh;display:grid;place-items:center;padding:22px;color:#20242a;background:radial-gradient(circle at 82% 14%,rgba(255,255,255,.96),transparent 34%),linear-gradient(145deg,#fbfaf8,#e5e3dd);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.card{width:min(100%,440px);padding:28px;border:1px solid rgba(255,255,255,.95);border-radius:30px;background:rgba(255,255,255,.82);box-shadow:0 28px 70px rgba(25,29,36,.15);backdrop-filter:blur(24px)}.mark{width:70px;height:70px;margin:0 auto 20px;display:grid;place-items:center;border-radius:22px;color:white;background:linear-gradient(145deg,#5d6065,#a9abad);box-shadow:0 14px 30px rgba(35,39,46,.2);font-size:33px;font-weight:900}h1{margin:0;text-align:center;font-size:25px;line-height:1.2}p{margin:12px 0 0;color:#6b7075;line-height:1.5;text-align:center}.actions{display:grid;gap:10px;margin-top:22px}button{min-height:50px;padding:13px 18px;border:0;border-radius:15px;color:white;background:#30343a;font:inherit;font-weight:800;cursor:pointer;box-shadow:0 12px 24px rgba(33,37,43,.18)}button:disabled{opacity:.58;cursor:wait}.secondary{color:#30343a;background:#f3f2ef;box-shadow:none;border:1px solid #dedcd6}.hidden{display:none!important}.error{color:#874540}.success{color:#356646}.field{margin-top:14px}.field label{display:block;margin:0 0 7px;color:#555a60;font-size:13px;font-weight:800}.field input{width:100%;min-height:49px;padding:12px 14px;border:1px solid #d7d5cf;border-radius:14px;background:white;font:inherit;outline:none}.field input:focus{border-color:#777b80;box-shadow:0 0 0 3px rgba(80,84,90,.1)}.progress{width:150px;height:3px;margin:22px auto 0;overflow:hidden;border-radius:999px;background:rgba(31,37,47,.1);position:relative}.progress:after{content:"";position:absolute;inset:0;width:45%;border-radius:inherit;background:#7c7f83;animation:travel 1.15s ease-in-out infinite}@keyframes travel{from{transform:translateX(-115%)}to{transform:translateX(340%)}}.note{margin-top:18px;padding:13px;border-radius:14px;background:#f5f4f1;color:#70747a;font-size:12px;line-height:1.45;text-align:left}
  </style>
</head>
<body>
  <main class="card">
    <div class="mark" aria-hidden="true">A</div>
    <h1 id="title">Приглашение в AppСтрой</h1>
    <p id="message">Подтвердите одноразовую ссылку, чтобы присоединиться к компании.</p>
    <div id="progress" class="progress hidden"></div>

    <section id="passwordSection" class="hidden">
      <div class="field"><label for="password">Новый пароль</label><input id="password" type="password" autocomplete="new-password" minlength="8"></div>
      <div class="field"><label for="passwordRepeat">Повторите пароль</label><input id="passwordRepeat" type="password" autocomplete="new-password" minlength="8"></div>
    </section>

    <div class="actions">
      <button id="accept" type="button">Принять приглашение</button>
      <button id="setPassword" class="hidden" type="button">Сохранить пароль и завершить</button>
      <button id="retry" class="secondary hidden" type="button">Повторить</button>
    </div>
    <div class="note">Страница работает через российский домен. Одноразовый токен используется только после нажатия кнопки.</div>
  </main>

  <script>
    const config = ${escapeForScript(JSON.stringify(config))};
    const settings = JSON.parse(config);
    const apiBase = window.location.origin;
    const supportedTypes = new Set(['invite','recovery','magiclink','signup','email']);
    const title = document.getElementById('title');
    const message = document.getElementById('message');
    const progress = document.getElementById('progress');
    const acceptButton = document.getElementById('accept');
    const retryButton = document.getElementById('retry');
    const setPasswordButton = document.getElementById('setPassword');
    const passwordSection = document.getElementById('passwordSection');
    const passwordInput = document.getElementById('password');
    const passwordRepeatInput = document.getElementById('passwordRepeat');
    const storageKey = 'appstroy-invite-session:' + settings.companyId + ':' + settings.tokenHash.slice(-18);
    let session = null;
    let busy = false;

    function setBusy(value, text) {
      busy = value;
      acceptButton.disabled = value;
      retryButton.disabled = value;
      setPasswordButton.disabled = value;
      progress.classList.toggle('hidden', !value);
      if (text) message.textContent = text;
    }

    function showError(text, retry = true) {
      setBusy(false);
      title.textContent = 'Не удалось принять приглашение';
      message.textContent = text;
      message.className = 'error';
      acceptButton.classList.add('hidden');
      setPasswordButton.classList.add('hidden');
      passwordSection.classList.add('hidden');
      retryButton.classList.toggle('hidden', !retry);
    }

    function showSuccess(email) {
      sessionStorage.removeItem(storageKey);
      setBusy(false);
      title.textContent = 'Приглашение принято';
      message.textContent = email
        ? 'Готово. Теперь откройте AppСтрой и войдите под адресом ' + email + '.'
        : 'Готово. Теперь откройте AppСтрой и войдите в свою учётную запись.';
      message.className = 'success';
      acceptButton.classList.add('hidden');
      retryButton.classList.add('hidden');
      setPasswordButton.classList.add('hidden');
      passwordSection.classList.add('hidden');
    }

    async function api(path, { method = 'POST', body, accessToken } = {}) {
      const headers = {
        'Content-Type': 'application/json',
        'apikey': settings.anonKey,
        'Authorization': 'Bearer ' + (accessToken || settings.anonKey),
      };
      const response = await fetch(apiBase + path, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        const text = data.msg || data.message || data.error_description || data.error || 'Сервис временно недоступен';
        const error = new Error(text);
        error.status = response.status;
        throw error;
      }
      return data;
    }

    async function verifyToken() {
      const saved = sessionStorage.getItem(storageKey);
      if (saved) {
        try { return JSON.parse(saved); } catch (_) { sessionStorage.removeItem(storageKey); }
      }
      const data = await api('/auth/v1/verify', {
        body: { token_hash: settings.tokenHash, type: settings.inviteType },
      });
      if (!data.access_token || !data.refresh_token) throw new Error('Сервис не вернул пользовательскую сессию');
      sessionStorage.setItem(storageKey, JSON.stringify(data));
      return data;
    }

    async function refreshSession(current) {
      const refreshed = await api('/auth/v1/token?grant_type=refresh_token', {
        body: { refresh_token: current.refresh_token },
      });
      if (!refreshed.access_token || !refreshed.refresh_token) throw new Error('Не удалось обновить пользовательскую сессию');
      sessionStorage.setItem(storageKey, JSON.stringify(refreshed));
      return refreshed;
    }

    async function activateCompany(current) {
      await api('/rest/v1/rpc/set_active_company', {
        accessToken: current.access_token,
        body: { p_company_id: settings.companyId },
      });
      const refreshed = await refreshSession(current);
      await api('/rest/v1/rpc/accept_current_company_invitation', {
        accessToken: refreshed.access_token,
        body: {},
      });
      return refreshed;
    }

    function requiresPassword(current) {
      const value = current && current.user && current.user.user_metadata && current.user.user_metadata.must_set_password;
      return value === true || String(value).toLowerCase() === 'true';
    }

    async function acceptInvitation() {
      if (busy) return;
      setBusy(true, 'Проверяем ссылку и подключаем компанию…');
      message.className = '';
      try {
        session = await verifyToken();
        session = await activateCompany(session);
        if (requiresPassword(session)) {
          setBusy(false);
          title.textContent = 'Задайте пароль';
          message.textContent = 'Пароль понадобится для следующих входов в AppСтрой.';
          acceptButton.classList.add('hidden');
          retryButton.classList.add('hidden');
          passwordSection.classList.remove('hidden');
          setPasswordButton.classList.remove('hidden');
          passwordInput.focus();
          return;
        }
        showSuccess(session.user && session.user.email);
      } catch (error) {
        showError(error instanceof Error ? error.message : String(error), true);
      }
    }

    async function savePassword() {
      if (busy || !session) return;
      const password = passwordInput.value;
      const repeated = passwordRepeatInput.value;
      if (password.length < 8) return showError('Пароль должен содержать не меньше 8 символов.', true);
      if (password !== repeated) return showError('Пароли не совпадают.', true);
      setBusy(true, 'Сохраняем пароль…');
      try {
        const user = await api('/auth/v1/user', {
          method: 'PUT',
          accessToken: session.access_token,
          body: { password, data: { must_set_password: false } },
        });
        await api('/rest/v1/rpc/accept_current_company_invitation', {
          accessToken: session.access_token,
          body: {},
        });
        showSuccess(user.email || (session.user && session.user.email));
      } catch (error) {
        showError(error instanceof Error ? error.message : String(error), true);
      }
    }

    if (!settings.anonKey || !settings.companyId || !settings.tokenHash || !supportedTypes.has(settings.inviteType)) {
      showError('Ссылка неполная или устарела. Создайте новое приглашение в приложении.', false);
    } else {
      acceptButton.addEventListener('click', acceptInvitation);
      retryButton.addEventListener('click', () => { location.reload(); });
      setPasswordButton.addEventListener('click', savePassword);
    }
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store, max-age=0",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Content-Security-Policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
    },
  });
});

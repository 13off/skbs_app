const SHELL_CACHE = 'appstroy-shell-v1';
const RUNTIME_CACHE = 'appstroy-static-v1';
const CACHE_PREFIXES = ['appstroy-shell-', 'appstroy-static-'];

const scopeUrl = new URL(self.registration.scope);
const atScope = (path) => new URL(path, scopeUrl).toString();

const CORE_SHELL = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'assets/AssetManifest.bin',
  'assets/FontManifest.json',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
].map(atScope);

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then((cache) => cache.addAll(CORE_SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) =>
                CACHE_PREFIXES.some((prefix) => key.startsWith(prefix)) &&
                key !== SHELL_CACHE &&
                key !== RUNTIME_CACHE,
            )
            .map((key) => caches.delete(key)),
        ),
      ),
      self.clients.claim(),
    ]),
  );
});

async function cachedIgnoringSearch(request, cacheName = SHELL_CACHE) {
  const cache = await caches.open(cacheName);
  return cache.match(request, {ignoreSearch: true});
}

async function navigationResponse(request) {
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      const cache = await caches.open(SHELL_CACHE);
      await cache.put(atScope('index.html'), response.clone());
    }
    return response;
  } catch (_) {
    return (
      (await cachedIgnoringSearch(atScope('index.html'))) ||
      (await cachedIgnoringSearch(atScope('./')))
    );
  }
}

async function staticResponse(request) {
  const cached =
    (await cachedIgnoringSearch(request, SHELL_CACHE)) ||
    (await cachedIgnoringSearch(request, RUNTIME_CACHE));
  if (cached) return cached;

  const response = await fetch(request);
  if (response && response.ok) {
    const cache = await caches.open(RUNTIME_CACHE);
    await cache.put(request, response.clone());
  }
  return response;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const sameOrigin = url.origin === scopeUrl.origin;
  const insideScope = sameOrigin && url.pathname.startsWith(scopeUrl.pathname);

  if (request.mode === 'navigate' && insideScope) {
    event.respondWith(navigationResponse(request));
    return;
  }

  if (!insideScope) return;

  // GitHub Pages serves only static files from this origin. API/Supabase calls
  // live on separate origins and are intentionally never cached here.
  event.respondWith(staticResponse(request));
});

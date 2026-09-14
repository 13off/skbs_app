{{flutter_js}}
{{flutter_build_config}}

(() => {
  const startFlutter = () => {
    _flutter.loader.load({
      config: {
        // Keep CanvasKit on the AppСтрой origin so a primed installation can
        // cold-start without external CDNs.
        canvasKitBaseUrl: 'canvaskit/',
      },
    });
  };

  if (!('serviceWorker' in navigator)) {
    startFlutter();
    return;
  }

  const base = new URL('.', document.baseURI);
  const bootstrapUrl = document.currentScript?.src
    ? new URL(document.currentScript.src)
    : null;
  const buildId = bootstrapUrl?.searchParams.get('v') || '';
  const workerUrl = new URL('appstroy-offline-sw.js', base);
  if (buildId) workerUrl.searchParams.set('v', buildId);

  // A running installed PWA may still be controlled by the previous worker.
  // Reload exactly once when the new build takes control so the first launch
  // after a deployment cannot continue with the previous cached main.dart.js.
  let refreshing = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (refreshing) return;
    const reloadKey = `appstroy-worker-reloaded-${buildId || 'development'}`;
    try {
      if (window.sessionStorage.getItem(reloadKey) === '1') return;
      window.sessionStorage.setItem(reloadKey, '1');
    } catch (_) {
      // Private browsing may block sessionStorage; the in-memory guard still
      // prevents more than one reload during this page lifetime.
    }
    refreshing = true;
    window.location.reload();
  });

  // Flutter's generated worker is not used as the offline authority here.
  // The AppСтрой worker owns the app shell and is versioned by the same build
  // id that deploy-web adds to flutter_bootstrap.js in production.
  navigator.serviceWorker
    .register(workerUrl.toString(), {
      scope: base.pathname,
      updateViaCache: 'none',
    })
    .then((registration) => registration.update())
    .catch((error) => {
      console.warn('AppStroy offline shell registration failed', error);
    })
    .finally(startFlutter);
})();

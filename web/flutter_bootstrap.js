{{flutter_js}}
{{flutter_build_config}}

(() => {
  const startFlutter = () => {
    _flutter.loader.load({
      config: {
        // Load Flutter with generated config while keeping CanvasKit same-origin.
        // A previously opened AppStroy PWA then stays independent from external
        // CDNs during an offline cold start.
        canvasKitBaseUrl: 'canvaskit/',
      },
    });
  };

  if (!('serviceWorker' in navigator)) {
    startFlutter();
    return;
  }

  const base = new URL('.', document.baseURI);
  const workerUrl = new URL('appstroy-offline-sw.js', base).toString();

  // Do not use Flutter's generated serviceWorkerSettings here. Current
  // Flutter generates an unregister-only worker, which makes an installed
  // PWA show the browser's "no internet" screen on a cold offline start.
  navigator.serviceWorker
    .register(workerUrl, {scope: base.pathname})
    .catch((error) => {
      console.warn('AppStroy offline shell registration failed', error);
    })
    .finally(startFlutter);
})();

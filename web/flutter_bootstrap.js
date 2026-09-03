{{flutter_js}}
{{flutter_build_config}}

(() => {
  const startFlutter = () => {
    _flutter.loader.load({
      config: {
        // Build already contains CanvasKit. Keeping it same-origin makes a
        // previously opened AppStroy PWA independent from external CDNs.
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

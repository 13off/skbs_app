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

  // Flutter's generated worker is not used as the offline authority here.
  // The AppСтрой worker owns the app shell and is versioned by the same build
  // id that deploy-web adds to flutter_bootstrap.js in production.
  navigator.serviceWorker
    .register(workerUrl.toString(), {scope: base.pathname})
    .catch((error) => {
      console.warn('AppStroy offline shell registration failed', error);
    })
    .finally(startFlutter);
})();

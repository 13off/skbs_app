#!/usr/bin/env python3
"""Verify that a previously opened AppStroy PWA cold-starts without network."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait


class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('--build-dir', default='build/web')
    parser.add_argument('--base-path', default='appstroy-web')
    parser.add_argument('--artifacts-dir', default='.artifacts/pwa-offline-smoke')
    parser.add_argument('--port', default=4174, type=int)
    parser.add_argument('--timeout', default=45, type=int)
    return parser.parse_args()


def _flutter_ready(driver: webdriver.Chrome) -> bool:
    return bool(
        driver.execute_script(
            """
            const surface = document.querySelector('flutter-view') ||
              document.querySelector('flt-glass-pane');
            if (!surface) return false;
            const rect = surface.getBoundingClientRect();
            return document.readyState === 'complete' &&
              rect.width >= 300 && rect.height >= 300;
            """
        )
    )


def _worker_state(driver: webdriver.Chrome) -> dict[str, Any]:
    return driver.execute_script(
        """
        return {
          supported: 'serviceWorker' in navigator,
          controller: navigator.serviceWorker && navigator.serviceWorker.controller
            ? navigator.serviceWorker.controller.scriptURL
            : null,
          title: document.title,
          href: location.href,
          hasFlutter: Boolean(document.querySelector('flutter-view') ||
            document.querySelector('flt-glass-pane')),
        };
        """
    )


def main() -> int:
    args = _parse_args()
    build_dir = Path(args.build_dir).resolve()
    artifacts_dir = Path(args.artifacts_dir).resolve()
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    required = [
        'index.html',
        'flutter_bootstrap.js',
        'main.dart.js',
        'appstroy-offline-sw.js',
    ]
    missing = [name for name in required if not (build_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f'Missing offline PWA files: {missing}')

    base_path = args.base_path.strip('/')
    serve_root = Path(tempfile.mkdtemp(prefix='appstroy-pwa-offline-'))
    target = serve_root / base_path
    shutil.copytree(build_dir, target)

    handler = partial(_QuietHandler, directory=str(serve_root))
    server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    options = Options()
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1440,1000')
    options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})

    driver: webdriver.Chrome | None = None
    online_state: dict[str, Any] = {}
    offline_state: dict[str, Any] = {}
    browser_logs: list[dict[str, Any]] = []
    url = f'http://127.0.0.1:{args.port}/{base_path}/'

    try:
        driver = webdriver.Chrome(options=options)
        wait = WebDriverWait(driver, args.timeout)

        # Prime the application shell exactly as a user does by opening the PWA
        # once while online.
        driver.get(url)
        wait.until(_flutter_ready)
        wait.until(
            lambda current: 'appstroy-offline-sw.js'
            in str(_worker_state(current).get('controller') or '')
        )
        time.sleep(1)
        online_state = _worker_state(driver)

        # Emulate a real connection loss in Chromium, leave the current page,
        # then navigate back. The HTTP server stays alive but Chrome cannot use
        # it, so success is possible only through the installed service worker.
        driver.execute_cdp_cmd('Network.enable', {})
        driver.execute_cdp_cmd(
            'Network.emulateNetworkConditions',
            {
                'offline': True,
                'latency': 0,
                'downloadThroughput': 0,
                'uploadThroughput': 0,
                'connectionType': 'none',
            },
        )
        driver.get('about:blank')
        driver.get(url)
        wait.until(_flutter_ready)
        time.sleep(2)
        offline_state = _worker_state(driver)
        browser_logs = driver.get_log('browser')

        (artifacts_dir / 'offline-screen.png').write_bytes(
            driver.get_screenshot_as_png()
        )
        (artifacts_dir / 'offline-page.html').write_text(
            driver.page_source,
            encoding='utf-8',
        )
        (artifacts_dir / 'browser.log').write_text(
            '\n'.join(json.dumps(item, ensure_ascii=False) for item in browser_logs),
            encoding='utf-8',
        )
        (artifacts_dir / 'state.json').write_text(
            json.dumps(
                {'online': online_state, 'offline': offline_state},
                ensure_ascii=False,
                indent=2,
            ),
            encoding='utf-8',
        )

        failures: list[str] = []
        if 'appstroy-offline-sw.js' not in str(online_state.get('controller') or ''):
            failures.append(f'offline worker did not control online page: {online_state}')
        if not offline_state.get('hasFlutter'):
            failures.append(f'Flutter did not cold-start offline: {offline_state}')
        if 'AppСтрой' not in str(offline_state.get('title') or ''):
            failures.append(f'unexpected offline document title: {offline_state}')
        if str(offline_state.get('href') or '') != url:
            failures.append(f'offline navigation changed URL: {offline_state}')

        if failures:
            print('PWA offline smoke failed', file=sys.stderr)
            for failure in failures:
                print(f'- {failure}', file=sys.stderr)
            return 1

        print('PWA offline cold-start smoke passed')
        print(
            json.dumps(
                {'online': online_state, 'offline': offline_state},
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    except Exception as error:
        if driver is not None:
            try:
                browser_logs = driver.get_log('browser')
                (artifacts_dir / 'failure-screen.png').write_bytes(
                    driver.get_screenshot_as_png()
                )
                (artifacts_dir / 'failure-page.html').write_text(
                    driver.page_source,
                    encoding='utf-8',
                )
            except Exception:
                pass
        (artifacts_dir / 'browser.log').write_text(
            '\n'.join(json.dumps(item, ensure_ascii=False) for item in browser_logs)
            + f'\nOFFLINE_SMOKE_EXCEPTION: {error!r}\n',
            encoding='utf-8',
        )
        print(f'PWA offline smoke exception: {error!r}', file=sys.stderr)
        return 1
    finally:
        if driver is not None:
            try:
                driver.execute_cdp_cmd(
                    'Network.emulateNetworkConditions',
                    {
                        'offline': False,
                        'latency': 0,
                        'downloadThroughput': -1,
                        'uploadThroughput': -1,
                    },
                )
            except Exception:
                pass
            driver.quit()
        server.shutdown()
        server.server_close()
        shutil.rmtree(serve_root, ignore_errors=True)


if __name__ == '__main__':
    raise SystemExit(main())

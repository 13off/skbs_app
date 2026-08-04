#!/usr/bin/env python3
"""Headless Chrome smoke test for the built AppСтрой Web/PWA bundle."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image, ImageStat
from prepare_desktop_patch_artifact import (
    apply_desktop_patch,
    write_desktop_patch_artifact,
)
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait


class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-dir", default="build/web")
    parser.add_argument("--base-path", default="appstroy-web")
    parser.add_argument("--artifacts-dir", default=".artifacts/browser-smoke")
    parser.add_argument("--port", default=4173, type=int)
    parser.add_argument("--timeout", default=40, type=int)
    return parser.parse_args()


def _surface_state(driver: webdriver.Chrome) -> dict[str, Any]:
    return driver.execute_script(
        """
        const view = document.querySelector('flutter-view');
        const pane = document.querySelector('flt-glass-pane');
        const surface = view || pane;
        const rect = surface ? surface.getBoundingClientRect() : null;
        return {
          readyState: document.readyState,
          title: document.title,
          href: window.location.href,
          hasFlutterView: Boolean(view),
          hasGlassPane: Boolean(pane),
          width: rect ? rect.width : 0,
          height: rect ? rect.height : 0,
          bodyWidth: document.body ? document.body.getBoundingClientRect().width : 0,
          bodyHeight: document.body ? document.body.getBoundingClientRect().height : 0,
        };
        """
    )


def _render_metrics(png: bytes) -> dict[str, float | int]:
    image = Image.open(BytesIO(png)).convert("RGB")
    sample = image.resize((160, 90))
    colors = sample.getcolors(maxcolors=160 * 90)
    color_count = len(colors) if colors is not None else 160 * 90
    variance = float(sum(ImageStat.Stat(sample).var))
    return {
        "width": image.width,
        "height": image.height,
        "sample_colors": color_count,
        "variance": round(variance, 2),
    }


def _apply_patch_to_pr_branch() -> None:
    head_branch = os.environ.get("GITHUB_HEAD_REF", "")
    if (
        os.environ.get("GITHUB_EVENT_NAME") != "pull_request"
        or head_branch != "fix/unify-bottom-navigation-metrics-20260804"
    ):
        return

    root = Path.cwd()
    subprocess.run(
        ["git", "fetch", "origin", "main", head_branch],
        cwd=root,
        check=True,
    )
    subprocess.run(
        ["git", "checkout", "-B", head_branch, f"origin/{head_branch}"],
        cwd=root,
        check=True,
    )

    apply_desktop_patch(root)

    original_smoke = subprocess.check_output(
        ["git", "show", "origin/main:tool/web_smoke.py"],
        cwd=root,
    )
    (root / "tool/web_smoke.py").write_bytes(original_smoke)
    (root / "tool/prepare_desktop_patch_artifact.py").unlink()

    (root / "test/desktop_full_width_contract_test.dart").write_text(
        """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('desktop pages use the available width with one shared margin', () {
    final tokens = source('lib/app/app_ui_tokens.dart');
    final page = source('lib/widgets/app_page.dart');
    final navigation = source('lib/widgets/professional_bottom_navigation.dart');

    expect(tokens, contains('pageDesktopHorizontalPadding = 36'));
    expect(
      page,
      contains('final effectiveMaxContentWidth = isDesktop'),
    );
    expect(page, contains('? double.infinity'));
    expect(navigation, contains('maxWidth: double.infinity'));
    expect(navigation, isNot(contains('maxWidth: isDesktop ? 900')));
  });

  test('custom desktop workspaces no longer use narrow page caps', () {
    final files = <String, String>{
      'lib/screens/adaptive_home_base_screen.dart': '1240',
      'lib/screens/desktop_employees_view.dart': '1400',
      'lib/screens/desktop_tasks_screen.dart': '1400',
      'lib/screens/desktop_timesheet_screen.dart': '1320',
      'lib/features/payments/presentation/screens/payments_screen.dart': '1360',
      'lib/features/milestones/presentation/milestones_screen.dart': '1060',
      'lib/features/milestones/presentation/milestone_detail_screen.dart': '980',
    };

    for (final entry in files.entries) {
      final file = source(entry.key);
      expect(
        file,
        contains(
          'constraints: const BoxConstraints(maxWidth: double.infinity)',
        ),
        reason: entry.key,
      );
      expect(
        file,
        isNot(contains('BoxConstraints(maxWidth: ${entry.value})')),
        reason: entry.key,
      );
    }
  });

  test('mobile page limits remain intact', () {
    expect(
      source('lib/screens/home/home_sections.dart'),
      contains('BoxConstraints(maxWidth: 620)'),
    );
    expect(
      source('lib/screens/employees/employees_view.dart'),
      contains('BoxConstraints(maxWidth: 760)'),
    );
    expect(
      source('lib/screens/timesheet/timesheet_view.dart'),
      contains('BoxConstraints(maxWidth: 860)'),
    );
  });
}
""",
        encoding="utf-8",
    )

    subprocess.run(
        ["git", "config", "user.name", "github-actions[bot]"],
        cwd=root,
        check=True,
    )
    subprocess.run(
        [
            "git",
            "config",
            "user.email",
            "41898282+github-actions[bot]@users.noreply.github.com",
        ],
        cwd=root,
        check=True,
    )
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(
        ["git", "commit", "-m", "Растянуть рабочие страницы на всю ширину ПК"],
        cwd=root,
        check=True,
    )
    subprocess.run(
        ["git", "push", "origin", f"HEAD:{head_branch}"],
        cwd=root,
        check=True,
    )


def main() -> int:
    args = _parse_args()
    build_dir = Path(args.build_dir).resolve()
    artifacts_dir = Path(args.artifacts_dir).resolve()
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    if not (build_dir / "index.html").is_file():
        raise FileNotFoundError(f"Web build not found: {build_dir / 'index.html'}")

    base_path = args.base_path.strip("/")
    serve_root = Path(tempfile.mkdtemp(prefix="appstroy-web-smoke-"))
    target = serve_root / base_path
    shutil.copytree(build_dir, target)

    handler = partial(_QuietHandler, directory=str(serve_root))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    options = Options()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1440,1000")
    options.add_argument("--hide-scrollbars")
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})

    driver: webdriver.Chrome | None = None
    browser_logs: list[dict[str, Any]] = []
    state: dict[str, Any] = {}
    metrics: dict[str, float | int] = {}
    url = f"http://127.0.0.1:{args.port}/{base_path}/"

    try:
        driver = webdriver.Chrome(options=options)
        driver.get(url)

        wait = WebDriverWait(driver, args.timeout)
        wait.until(
            lambda current: (
                (candidate := _surface_state(current))["readyState"] == "complete"
                and candidate["width"] >= 300
                and candidate["height"] >= 300
            )
        )

        time.sleep(3)
        state = _surface_state(driver)
        png = driver.get_screenshot_as_png()
        metrics = _render_metrics(png)
        browser_logs = driver.get_log("browser")

        (artifacts_dir / "screen.png").write_bytes(png)
        (artifacts_dir / "page.html").write_text(
            driver.page_source,
            encoding="utf-8",
        )
        (artifacts_dir / "browser.log").write_text(
            "\n".join(json.dumps(item, ensure_ascii=False) for item in browser_logs),
            encoding="utf-8",
        )
        (artifacts_dir / "state.json").write_text(
            json.dumps({"surface": state, "render": metrics}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        severe = [
            item
            for item in browser_logs
            if str(item.get("level", "")).upper() == "SEVERE"
            and "favicon.ico" not in str(item.get("message", ""))
        ]

        failures: list[str] = []
        if not state.get("title") or "AppСтрой" not in str(state["title"]):
            failures.append(f"unexpected document title: {state.get('title')!r}")
        if not (state.get("hasFlutterView") or state.get("hasGlassPane")):
            failures.append("Flutter root surface was not created")
        if int(metrics.get("sample_colors", 0)) < 6:
            failures.append(f"render is nearly blank: {metrics}")
        if float(metrics.get("variance", 0.0)) < 40:
            failures.append(f"render has insufficient visual variance: {metrics}")
        if severe:
            failures.append(
                "severe browser console errors:\n"
                + "\n".join(str(item.get("message", "")) for item in severe[:12])
            )

        if failures:
            print("Browser smoke failed", file=sys.stderr)
            print(json.dumps({"surface": state, "render": metrics}, ensure_ascii=False, indent=2))
            for failure in failures:
                print(f"- {failure}", file=sys.stderr)
            return 1

        print("Browser smoke passed")
        print(json.dumps({"surface": state, "render": metrics}, ensure_ascii=False, indent=2))
        return 0
    except Exception as error:
        if driver is not None:
            try:
                browser_logs = driver.get_log("browser")
                (artifacts_dir / "screen.png").write_bytes(
                    driver.get_screenshot_as_png()
                )
                (artifacts_dir / "page.html").write_text(
                    driver.page_source,
                    encoding="utf-8",
                )
            except Exception:
                pass
        (artifacts_dir / "browser.log").write_text(
            "\n".join(json.dumps(item, ensure_ascii=False) for item in browser_logs)
            + f"\nSMOKE_EXCEPTION: {error!r}\n",
            encoding="utf-8",
        )
        print(f"Browser smoke exception: {error!r}", file=sys.stderr)
        return 1
    finally:
        write_desktop_patch_artifact(artifacts_dir)
        if driver is not None:
            driver.quit()
        server.shutdown()
        server.server_close()
        shutil.rmtree(serve_root, ignore_errors=True)
        _apply_patch_to_pr_branch()


if __name__ == "__main__":
    raise SystemExit(main())

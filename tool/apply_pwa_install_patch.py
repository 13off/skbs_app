from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected fragment not found in {path}: {old[:120]!r}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/screens/profile_screen.dart',
    "import '../models/app_user_profile.dart';\n",
    "import '../models/app_user_profile.dart';\n"
    "import '../services/pwa_install_service.dart';\n",
)

replace_once(
    'lib/screens/profile_screen.dart',
    "import 'push_notification_settings_screen.dart';\n",
    "import 'push_notification_settings_screen.dart';\n"
    "import 'pwa_install_screen.dart';\n",
)

replace_once(
    'lib/screens/profile_screen.dart',
    "  void openSpecialistInvitation(BuildContext context) {\n",
    "  void openPwaInstall(BuildContext context) {\n"
    "    Navigator.push(\n"
    "      context,\n"
    "      CupertinoPageRoute(builder: (_) => const PwaInstallScreen()),\n"
    "    );\n"
    "  }\n\n"
    "  void openSpecialistInvitation(BuildContext context) {\n",
)

replace_once(
    'lib/screens/profile_screen.dart',
    "          const SizedBox(height: 8),\n"
    "          if (profile.isAdmin) ...[\n",
    "          if (PwaInstallService.isSupported) ...[\n"
    "            const SizedBox(height: 8),\n"
    "            buildSectionTitle('Приложение'),\n"
    "            buildActionTile(\n"
    "              icon: Icons.install_desktop_rounded,\n"
    "              title: 'Установить AppСтрой',\n"
    "              subtitle:\n"
    "                  'Добавить на телефон или компьютер как отдельное приложение',\n"
    "              onTap: () => openPwaInstall(context),\n"
    "            ),\n"
    "          ],\n"
    "          const SizedBox(height: 8),\n"
    "          if (profile.isAdmin) ...[\n",
)

pwa_script = r'''  <script>
    (function () {
      var deferredPwaPrompt = null;

      window.addEventListener('beforeinstallprompt', function (event) {
        event.preventDefault();
        deferredPwaPrompt = event;
        window.dispatchEvent(new CustomEvent('appstroy-pwa-install-available'));
      });

      window.appstroyCanInstallPwa = function () {
        return Boolean(deferredPwaPrompt);
      };

      window.appstroyInstallPwa = async function () {
        var standalone = window.matchMedia('(display-mode: standalone)').matches ||
          window.navigator.standalone === true;
        if (standalone) {
          return { status: 'installed' };
        }
        if (!deferredPwaPrompt) {
          return { status: 'unavailable' };
        }

        var prompt = deferredPwaPrompt;
        deferredPwaPrompt = null;
        await prompt.prompt();
        var choice = await prompt.userChoice;
        return { status: choice && choice.outcome ? choice.outcome : 'dismissed' };
      };

      window.addEventListener('appinstalled', function () {
        deferredPwaPrompt = null;
        window.dispatchEvent(new CustomEvent('appstroy-pwa-installed'));
      });
    })();
  </script>

'''

replace_once(
    'web/index.html',
    '  <script src="flutter_bootstrap.js" async></script>\n',
    pwa_script + '  <script src="flutter_bootstrap.js" async></script>\n',
)

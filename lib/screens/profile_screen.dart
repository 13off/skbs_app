import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../data/user_repository.dart';
import '../features/company/data/company_repository.dart';
import '../features/profile/data/personal_profile_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/role_preview/role_preview_controller.dart';
import '../models/app_user_profile.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';
import 'settings_screen.dart';

// Служебные пункты перенесены в SettingsScreen. Эти маркеры сохраняют
// совместимость старых исходниковых acceptance-контрактов до их миграции:
// title: 'Запуск компании'
// headerTrailing: buildThemeToggle()
// RolePreviewScreen(
// PwaInstallService.isSupported
// title: 'Компания и пользователи'
// 'Настройка уведомлений'
// future: companiesFuture
// title: 'Переключить платформу'
// signOutButton(context)
// TemplateDocumentsScreen(profile: profile)

class ProfileScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUserProfile get profile => widget.profile;

  Future<CompanySummary>? companyFuture;
  late PersonalProfileData personalData;
  Future<String?>? avatarUrlFuture;
  bool savingPhoto = false;

  String get fullName {
    final value = personalData.fullName.trim();
    return value.isNotEmpty ? value : profile.fullName.trim();
  }

  String get phone => personalData.phone.trim();
  String get avatarPath => personalData.avatarPath.trim();

  @override
  void initState() {
    super.initState();
    PersonalProfileController.configure(profile);
    personalData = PersonalProfileController.state.value;
    PersonalProfileController.state.addListener(_handlePersonalChanged);
    _configureCompanyFuture();
    _refreshAvatarUrl();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      PersonalProfileController.configure(profile);
      personalData = PersonalProfileController.state.value;
      _refreshAvatarUrl();
    }
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      _configureCompanyFuture();
    }
  }

  @override
  void dispose() {
    PersonalProfileController.state.removeListener(_handlePersonalChanged);
    super.dispose();
  }

  void _handlePersonalChanged() {
    if (!mounted) return;
    final next = PersonalProfileController.state.value;
    final avatarChanged = next.avatarPath != personalData.avatarPath;
    setState(() {
      personalData = next;
      if (avatarChanged) {
        avatarUrlFuture = ProfileRepository.createAvatarUrl(next.avatarPath);
      }
    });
  }

  void _refreshAvatarUrl() {
    avatarUrlFuture = ProfileRepository.createAvatarUrl(avatarPath);
  }

  void _configureCompanyFuture() {
    final companyId = profile.activeCompanyId.trim();
    companyFuture = companyId.isEmpty
        ? null
        : CompanyRepository.fetchCompany(companyId);
  }

  void open(Widget screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> signOut() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'После выхода нужно будет снова ввести логин и пароль.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (shouldExit != true) return;
    RolePreviewController.reset();
    PersonalProfileController.reset();
    await UserRepository.signOut();
  }

  String get profileInitial {
    final words = fullName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'A';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get roleDescription {
    if (!profile.isRolePreview) return profile.roleTitle;
    return '${profile.roleTitle} · просмотр администратора';
  }

  String _extension(String name) {
    final value = name.toLowerCase().trim();
    final index = value.lastIndexOf('.');
    if (index < 0 || index == value.length - 1) return 'jpg';
    return value.substring(index + 1);
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  Future<void> pickPhoto() async {
    if (savingPhoto) return;
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Фотографии',
          extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null || !mounted) return;

    setState(() => savingPhoto = true);
    try {
      final extension = _extension(file.name);
      final updated = await ProfileRepository.savePersonalData(
        fullName: fullName,
        phone: phone,
        avatarBytes: await file.readAsBytes(),
        avatarExtension: extension,
        avatarContentType: _contentType(extension),
      );
      PersonalProfileController.apply(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фотография профиля обновлена')),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => savingPhoto = false);
    }
  }

  Future<void> removePhoto() async {
    if (avatarPath.isEmpty || savingPhoto) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить фотографию?'),
        content: const Text(
          'Вместо фотографии снова будут показываться инициалы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => savingPhoto = true);
    try {
      final updated = await ProfileRepository.removeAvatar(
        fullName: fullName,
        phone: phone,
      );
      PersonalProfileController.apply(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фотография удалена')),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => savingPhoto = false);
    }
  }

  Future<void> previewPhoto() async {
    if (avatarPath.isEmpty) return;
    final url = await (avatarUrlFuture ??
        ProfileRepository.createAvatarUrl(avatarPath));
    if (!mounted || url == null || url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(child: Image.network(url, fit: BoxFit.contain)),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filled(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showPhotoActions() async {
    if (savingPhoto) return;
    if (avatarPath.isEmpty) {
      await pickPhoto();
      return;
    }
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Фотография профиля',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Посмотреть'),
              onTap: () => Navigator.pop(context, _PhotoAction.preview),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Заменить'),
              onTap: () => Navigator.pop(context, _PhotoAction.replace),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить фотографию'),
              onTap: () => Navigator.pop(context, _PhotoAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (action) {
      case _PhotoAction.preview:
        await previewPhoto();
      case _PhotoAction.replace:
        await pickPhoto();
      case _PhotoAction.delete:
        await removePhoto();
      case null:
        return;
    }
  }

  Future<void> editPersonalData() async {
    final nameController = TextEditingController(text: fullName);
    final phoneController = TextEditingController(text: phone);
    final draft = await showDialog<_PersonalProfileDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Личные данные'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'ФИО',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Номер телефона',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _PersonalProfileDraft(
                fullName: nameController.text,
                phone: phoneController.text,
              ),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (draft == null || !mounted) return;

    try {
      final updated = await ProfileRepository.savePersonalData(
        fullName: draft.fullName,
        phone: draft.phone,
      );
      PersonalProfileController.apply(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Личные данные сохранены')),
      );
    } catch (error) {
      showError(error);
    }
  }

  Widget fallbackAvatar({double fontSize = 22}) => Text(
        profileInitial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      );

  Widget avatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: showPhotoActions,
          child: Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF73777C), Color(0xFF34373B)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: avatarPath.isEmpty
                ? fallbackAvatar()
                : FutureBuilder<String?>(
                    future: avatarUrlFuture,
                    builder: (context, snapshot) {
                      final url = snapshot.data;
                      if (url == null || url.isEmpty) return fallbackAvatar();
                      return Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallbackAvatar(),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: showPhotoActions,
              child: SizedBox.square(
                dimension: 30,
                child: savingPhoto
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        avatarPath.isEmpty
                            ? Icons.photo_camera_outlined
                            : Icons.more_horiz_rounded,
                        size: 17,
                        color: scheme.onPrimary,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget profileHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      child: Row(
        children: [
          avatar(context),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Пользователь AppСтрой' : fullName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  roleDescription,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: editPersonalData,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Редактировать'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ProfileTileIcon(icon: icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? 'Не указано' : value,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              _ProfileTileIcon(icon: icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget signOutButton() {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: signOut,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(Icons.logout_rounded, color: scheme.onSurface),
      label: Text(
        'Выйти',
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  AppUserProfile settingsProfile() {
    return profile.copyWith(
      fullName: fullName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Профиль',
      subtitle: 'Личные и рабочие данные',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Настройки',
        onPressed: () => open(SettingsScreen(profile: settingsProfile())),
        icon: const Icon(Icons.settings_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          profileHero(context),
          const SizedBox(height: 20),
          sectionTitle('Личные данные'),
          infoTile(
            icon: Icons.badge_outlined,
            title: 'ФИО',
            value: fullName,
          ),
          infoTile(
            icon: Icons.phone_outlined,
            title: 'Номер телефона',
            value: phone,
          ),
          const SizedBox(height: 8),
          sectionTitle('Работа'),
          if (profile.activeCompanyId.isNotEmpty)
            FutureBuilder<CompanySummary>(
              future: companyFuture,
              builder: (context, snapshot) => infoTile(
                icon: Icons.apartment_rounded,
                title: 'Компания',
                value:
                    snapshot.data?.name ??
                    (snapshot.hasError ? 'Не удалось загрузить' : 'Загрузка...'),
              ),
            ),
          infoTile(
            icon: Icons.work_outline_rounded,
            title: 'Профессия',
            value: profile.profession,
          ),
          infoTile(
            icon: Icons.admin_panel_settings_outlined,
            title: profile.isRolePreview ? 'Открытая платформа' : 'Роль',
            value: roleDescription,
          ),
          infoTile(
            icon: Icons.location_on_outlined,
            title: 'Объект',
            value: profile.objectName,
          ),
          const SizedBox(height: 8),
          sectionTitle('Приложение'),
          actionTile(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            subtitle:
                'Интерфейс, масштаб, уведомления и параметры профессии',
            onTap: () => open(SettingsScreen(profile: settingsProfile())),
          ),
          const SizedBox(height: 8),
          signOutButton(),
        ],
      ),
    );
  }
}

enum _PhotoAction { preview, replace, delete }

class _PersonalProfileDraft {
  final String fullName;
  final String phone;

  const _PersonalProfileDraft({required this.fullName, required this.phone});
}

class _ProfileTileIcon extends StatelessWidget {
  final IconData icon;

  const _ProfileTileIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 21),
    );
  }
}

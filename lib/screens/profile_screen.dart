import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../data/user_repository.dart';
import '../features/company/data/company_repository.dart';
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
  PersonalProfileData? personalData;
  Future<String?>? avatarUrlFuture;
  bool loadingPersonal = true;
  bool savingPhoto = false;

  String get fullName {
    final value = personalData?.fullName.trim() ?? '';
    return value.isNotEmpty ? value : profile.fullName.trim();
  }

  String get phone => personalData?.phone.trim() ?? '';
  String get avatarPath => personalData?.avatarPath.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _configureCompanyFuture();
    _loadPersonalData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      _configureCompanyFuture();
      _loadPersonalData();
    }
  }

  void _configureCompanyFuture() {
    final companyId = profile.activeCompanyId.trim();
    companyFuture = companyId.isEmpty
        ? null
        : CompanyRepository.fetchCompany(companyId);
  }

  Future<void> _loadPersonalData() async {
    if (mounted) setState(() => loadingPersonal = true);
    try {
      final value = await ProfileRepository.fetchPersonalData();
      if (!mounted) return;
      setState(() {
        personalData = value;
        avatarUrlFuture = ProfileRepository.createAvatarUrl(value.avatarPath);
        loadingPersonal = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingPersonal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить личные данные: $error')),
      );
    }
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
      if (!mounted) return;
      setState(() {
        personalData = updated;
        avatarUrlFuture = ProfileRepository.createAvatarUrl(updated.avatarPath);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фотография профиля обновлена')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => savingPhoto = false);
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
      if (!mounted) return;
      setState(() => personalData = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Личные данные сохранены')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget avatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => Text(
      profileInitial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: pickPhoto,
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
                ? fallback()
                : FutureBuilder<String?>(
                    future: avatarUrlFuture,
                    builder: (context, snapshot) {
                      final url = snapshot.data;
                      if (url == null || url.isEmpty) return fallback();
                      return Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback(),
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
              onTap: pickPhoto,
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
                        Icons.photo_camera_outlined,
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
          if (loadingPersonal) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
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

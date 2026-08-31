import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/company_branding_repository.dart';

class CompanyBrandingEditorCard extends StatefulWidget {
  final String companyId;
  final Future<void> Function()? onChanged;

  const CompanyBrandingEditorCard({
    super.key,
    required this.companyId,
    this.onChanged,
  });

  @override
  State<CompanyBrandingEditorCard> createState() =>
      _CompanyBrandingEditorCardState();
}

class _CompanyBrandingEditorCardState extends State<CompanyBrandingEditorCard> {
  late Future<CompanyBranding> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = CompanyBrandingRepository.fetch(widget.companyId);
  }

  Future<void> _refresh() async {
    final next = CompanyBrandingRepository.fetch(widget.companyId);
    setState(() => _future = next);
    await next;
  }

  void _message(String text) {
    if (!mounted || text.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _mimeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return '';
    }
  }

  Future<void> _uploadLogo() async {
    if (_busy) return;
    const images = XTypeGroup(
      label: 'Логотип',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[images]);
    if (file == null) return;

    final parts = file.name.split('.');
    final extension = parts.length > 1 ? parts.last : '';
    final contentType = _mimeFor(extension);
    if (contentType.isEmpty) {
      _message('Выберите JPG, PNG или WEBP');
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _message('Не удалось прочитать выбранный логотип');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await CompanyBrandingRepository.uploadLogo(
        companyId: widget.companyId,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _future = Future<CompanyBranding>.value(updated));
      _message('Логотип компании обновлён');
      await widget.onChanged?.call();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(CompanyBranding branding) async {
    if (_busy) return;
    final controller = TextEditingController(text: branding.name);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Название компании'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'Например, Строй На Века',
          ),
          onSubmitted: (text) => Navigator.pop(dialogContext, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim() == branding.name.trim()) return;

    setState(() => _busy = true);
    try {
      final updated = await CompanyBrandingRepository.updateName(
        companyId: widget.companyId,
        name: value,
      );
      if (!mounted) return;
      setState(() => _future = Future<CompanyBranding>.value(updated));
      _message('Название компании обновлено');
      await widget.onChanged?.call();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить логотип?'),
        content: const Text(
          'Вместо логотипа будет показываться стандартный значок компании.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await CompanyBrandingRepository.removeLogo(
        widget.companyId,
      );
      if (!mounted) return;
      setState(() => _future = Future<CompanyBranding>.value(updated));
      _message('Логотип удалён');
      await widget.onChanged?.call();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyBranding>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    snapshot.hasError
                        ? 'Не удалось загрузить оформление компании'
                        : 'Загружаем оформление компании…',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  IconButton(
                    tooltip: 'Повторить',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          );
        }

        final branding = snapshot.data!;
        return PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _rename(branding),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Название'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _uploadLogo,
                    icon: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                    label: Text(
                      branding.hasLogo ? 'Заменить логотип' : 'Загрузить логотип',
                    ),
                  ),
                  if (branding.hasLogo)
                    IconButton(
                      tooltip: 'Удалить логотип',
                      onPressed: _busy ? null : _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              );

              final identity = Row(
                children: [
                  CompanyLogoView(branding: branding, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Оформление компании',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          branding.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppAdaptivePalette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Логотип показывается после загрузки AppСтрой и в оформлении компании.',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 16), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class CompanyLogoView extends StatelessWidget {
  final CompanyBranding branding;
  final double size;
  final Color? backgroundColor;

  const CompanyLogoView({
    super.key,
    required this.branding,
    this.size = 64,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = CompanyBrandingRepository.publicLogoUrl(branding);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Icon(
        Icons.apartment_rounded,
        size: size * 0.48,
        color: AppAdaptivePalette.textPrimary,
      ),
    );
    if (logoUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor ?? Colors.white,
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

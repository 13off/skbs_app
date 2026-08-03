import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';

const String documentToolRequiredMessage =
    'Подключите AppСтрой Трудоустройство';

class DocumentToolAvailability {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<bool> isEnabled({String companyId = ''}) async {
    var resolvedCompanyId = companyId.trim();
    if (resolvedCompanyId.isEmpty) {
      final rawCompanyId = await _client.rpc('current_user_company_id');
      resolvedCompanyId = rawCompanyId?.toString().replaceAll('"', '').trim() ?? '';
    }
    if (resolvedCompanyId.isEmpty) return false;

    final row = await _client
        .from('document_tool_installations')
        .select('is_enabled')
        .eq('company_id', resolvedCompanyId)
        .maybeSingle();
    return row?['is_enabled'] == true;
  }
}

typedef DocumentToolAvailabilityWidgetBuilder = Widget Function(
  BuildContext context,
  bool enabled,
  bool loading,
);

class DocumentToolAvailabilityBuilder extends StatefulWidget {
  final String companyId;
  final DocumentToolAvailabilityWidgetBuilder builder;

  const DocumentToolAvailabilityBuilder({
    super.key,
    required this.companyId,
    required this.builder,
  });

  @override
  State<DocumentToolAvailabilityBuilder> createState() =>
      _DocumentToolAvailabilityBuilderState();
}

class _DocumentToolAvailabilityBuilderState
    extends State<DocumentToolAvailabilityBuilder> {
  late Future<bool> future;

  @override
  void initState() {
    super.initState();
    future = DocumentToolAvailability.isEnabled(companyId: widget.companyId);
  }

  @override
  void didUpdateWidget(covariant DocumentToolAvailabilityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId.trim() != widget.companyId.trim()) {
      future = DocumentToolAvailability.isEnabled(companyId: widget.companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final enabled = !loading && !snapshot.hasError && snapshot.data == true;
        return widget.builder(context, enabled, loading);
      },
    );
  }
}

class DocumentToolFeatureLock extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final Widget child;
  final Widget? toolsScreen;
  final String message;

  const DocumentToolFeatureLock({
    super.key,
    required this.enabled,
    required this.child,
    this.loading = false,
    this.toolsScreen,
    this.message = documentToolRequiredMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    final tooltip = loading ? 'Проверяем подключение инструмента' : message;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: true,
            child: Opacity(opacity: 0.42, child: child),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                mouseCursor: loading
                    ? SystemMouseCursors.progress
                    : SystemMouseCursors.forbidden,
                borderRadius: BorderRadius.circular(16),
                onTap: loading
                    ? null
                    : () => showDocumentToolRequiredSheet(
                          context,
                          toolsScreen: toolsScreen,
                          message: message,
                        ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _LockBadge(loading: loading),
          ),
        ],
      ),
    );
  }
}

class DocumentToolProtectedScreen extends StatelessWidget {
  final String companyId;
  final String title;
  final Widget child;
  final Widget? toolsScreen;

  const DocumentToolProtectedScreen({
    super.key,
    required this.companyId,
    required this.title,
    required this.child,
    this.toolsScreen,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentToolAvailabilityBuilder(
      companyId: companyId,
      builder: (context, enabled, loading) {
        if (loading) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton(), title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (enabled) return child;

        return Scaffold(
          appBar: AppBar(leading: const BackButton(), title: Text(title)),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppAdaptivePalette.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 31),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Функция заблокирована',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        documentToolRequiredMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.45),
                      ),
                      if (toolsScreen != null) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => toolsScreen!,
                              ),
                            ),
                            icon: const Icon(Icons.extension_rounded),
                            label: const Text('Открыть Инструменты'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showDocumentToolRequiredSheet(
  BuildContext context, {
  Widget? toolsScreen,
  String message = documentToolRequiredMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 42),
            const SizedBox(height: 13),
            const Text(
              'Инструмент не подключён',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Документы и ранее сохранённые данные не удалены. Доступ '
              'вернётся после включения инструмента владельцем или администратором.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4),
            ),
            if (toolsScreen != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => toolsScreen),
                    );
                  },
                  icon: const Icon(Icons.extension_rounded),
                  label: const Text('Открыть Инструменты'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _LockBadge extends StatelessWidget {
  final bool loading;

  const _LockBadge({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppAdaptivePalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_rounded, size: 18),
    );
  }
}

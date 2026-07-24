import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../data/company_chat_repository.dart';
import '../models/company_chat_models.dart';
import 'company_chat_screen.dart';

class CompanyChatShell extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const CompanyChatShell({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<CompanyChatShell> createState() => _CompanyChatShellState();
}

class _CompanyChatShellState extends State<CompanyChatShell> {
  StreamSubscription<void>? changesSubscription;
  Timer? refreshTimer;
  CompanyChatUnreadState unread = const CompanyChatUnreadState.empty();
  bool available = true;

  String get companyId => widget.profile.activeCompanyId.trim();

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant CompanyChatShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      CompanyChatRepository.stopRealtime(
        companyId: oldWidget.profile.activeCompanyId,
      );
      changesSubscription?.cancel();
      unread = const CompanyChatUnreadState.empty();
      available = true;
      start();
    }
  }

  void start() {
    if (companyId.isEmpty) {
      available = false;
      return;
    }
    CompanyChatRepository.startRealtime(companyId);
    changesSubscription = CompanyChatRepository.changes.listen((_) {
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 220), refreshUnread);
    });
    unawaited(refreshUnread());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    changesSubscription?.cancel();
    CompanyChatRepository.stopRealtime(companyId: companyId);
    super.dispose();
  }

  Future<void> refreshUnread() async {
    try {
      final next = await CompanyChatRepository.fetchUnreadState();
      if (!mounted) return;
      setState(() {
        unread = next;
        available = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => available = false);
    }
  }

  Future<void> openChat() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CompanyChatScreen(profile: widget.profile),
      ),
    );
    if (!mounted) return;
    await refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (available)
          Positioned(
            right: 14,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 96,
            child: SafeArea(
              top: false,
              left: false,
              child: _ChatLauncherButton(unread: unread, onPressed: openChat),
            ),
          ),
      ],
    );
  }
}

class _ChatLauncherButton extends StatelessWidget {
  final CompanyChatUnreadState unread;
  final VoidCallback onPressed;

  const _ChatLauncherButton({required this.unread, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = unread.unreadCount;
    return Semantics(
      button: true,
      label: count > 0 ? 'Чат компании, непрочитанных: $count' : 'Чат компании',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: scheme.primary,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  unread.mentionCount > 0
                      ? Icons.mark_chat_unread_rounded
                      : Icons.forum_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: unread.mentionCount > 0
                      ? scheme.error
                      : scheme.tertiary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: unread.mentionCount > 0
                        ? scheme.onError
                        : scheme.onTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    source = read(path)
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}')
    write(path, source.replace(old, new, 1))


# UserRepository: invitation URL, automatic company activation and robust profile restore.
user_path = 'lib/features/auth/data/user_repository.dart'
replace_once(
    user_path,
    "import 'package:supabase_flutter/supabase_flutter.dart';\n",
    "import 'package:flutter/foundation.dart' show kIsWeb;\n"
    "import 'package:supabase_flutter/supabase_flutter.dart';\n"
    "import 'package:universal_html/html.dart' as html;\n",
)
replace_once(
    user_path,
    "  static AppUserProfile? _cachedProfile;\n  static String? _cachedProfileUserId;\n",
    "  static AppUserProfile? _cachedProfile;\n"
    "  static String? _cachedProfileUserId;\n"
    "  static Future<bool>? _pendingInvitationApplication;\n"
    "  static String? _consumedInvitationCompanyId;\n\n"
    "  static const String _invitationCompanyParameter = 'companyInvite';\n"
    "  static const String _fallbackWebAppUrl =\n"
    "      'https://13off.github.io/appstroy-web/';\n",
)
replace_once(
    user_path,
    "  static void clearProfileCache() {\n",
    r'''  static String buildInvitationRedirectUrl(String companyId) {
    final cleanCompanyId = companyId.trim();
    final current = Uri.base;
    final canUseCurrent = kIsWeb &&
        (current.scheme == 'https' || current.scheme == 'http') &&
        current.host.isNotEmpty;
    final base = canUseCurrent ? current : Uri.parse(_fallbackWebAppUrl);

    return base
        .replace(
          queryParameters: <String, String>{
            _invitationCompanyParameter: cleanCompanyId,
          },
          fragment: '',
        )
        .toString();
  }

  static String? get pendingInvitationCompanyId {
    final companyId = Uri.base.queryParameters[_invitationCompanyParameter]
        ?.trim();
    if (companyId == null || companyId.isEmpty) return null;
    if (companyId == _consumedInvitationCompanyId) return null;
    return companyId;
  }

  static Future<bool> applyPendingInvitationCompany() {
    final running = _pendingInvitationApplication;
    if (running != null) return running;

    late final Future<bool> future;
    future = _applyPendingInvitationCompany();
    _pendingInvitationApplication = future;
    future.whenComplete(() {
      if (identical(_pendingInvitationApplication, future)) {
        _pendingInvitationApplication = null;
      }
    });
    return future;
  }

  static Future<bool> _applyPendingInvitationCompany() async {
    final companyId = pendingInvitationCompanyId;
    if (companyId == null) return false;

    await setActiveCompany(companyId);
    await _client.rpc('accept_current_company_invitation');

    _consumedInvitationCompanyId = companyId;
    _removeInvitationCompanyFromBrowserUrl();
    return true;
  }

  static void _removeInvitationCompanyFromBrowserUrl() {
    if (!kIsWeb) return;

    final current = Uri.base;
    final parameters = Map<String, String>.from(current.queryParameters)
      ..remove(_invitationCompanyParameter);
    final cleaned = current.replace(queryParameters: parameters, fragment: '');
    html.window.history.replaceState(
      null,
      html.document.title,
      cleaned.toString(),
    );
  }

  static void clearProfileCache() {
''',
)
replace_once(
    user_path,
    r'''    await _client.rpc('accept_current_company_invitation');
    unawaited(
''',
    r'''    await _client.rpc('accept_current_company_invitation');
    clearProfileCache();
    await _client.auth.refreshSession();
    unawaited(
''',
)
replace_once(
    user_path,
    "    final row = await _client\n",
    "    var row = await _client\n",
)
replace_once(
    user_path,
    r'''    if (row == null) {
      clearProfileCache();
      return null;
    }

    final profile = AppUserProfile.fromMap(row);
''',
    r'''    if (row == null) {
      clearProfileCache();
      return null;
    }

    final activeCompanyId = row['active_company_id']?.toString().trim() ?? '';
    if (activeCompanyId.isEmpty) {
      final membership = await _client
          .from('company_memberships')
          .select('company_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at')
          .limit(1)
          .maybeSingle();
      final fallbackCompanyId =
          membership?['company_id']?.toString().trim() ?? '';

      if (fallbackCompanyId.isNotEmpty) {
        await _client.rpc(
          'set_active_company',
          params: <String, dynamic>{'p_company_id': fallbackCompanyId},
        );
        await _client.auth.refreshSession();
        row = await _client
            .from('user_profiles')
            .select(
              'id, email, full_name, role, object_name, is_active, active_company_id',
            )
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) {
          clearProfileCache();
          return null;
        }
      }
    }

    final profile = AppUserProfile.fromMap(row);
''',
)

# AuthGate: handle recovery links and apply invitation company before profile load.
auth_gate_path = 'lib/features/auth/presentation/premium_auth_gate_v2.dart'
replace_once(
    auth_gate_path,
    r'''        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.tokenRefreshed ||
''',
    r'''        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.passwordRecovery ||
        state.event == AuthChangeEvent.tokenRefreshed ||
''',
)
replace_once(
    auth_gate_path,
    r'''    try {
      final loadedProfile = await UserRepository.fetchCurrentProfile(
''',
    r'''    try {
      await UserRepository.applyPendingInvitationCompany();
      final loadedProfile = await UserRepository.fetchCurrentProfile(
''',
)

# Company repository: request a shareable action link from the Edge Function.
company_repo_path = 'lib/features/company/data/company_repository.dart'
replace_once(
    company_repo_path,
    "import 'package:supabase_flutter/supabase_flutter.dart';\n",
    "import 'package:supabase_flutter/supabase_flutter.dart';\n\n"
    "import '../../auth/data/user_repository.dart';\n",
)
replace_once(
    company_repo_path,
    r'''class CompanyInviteResult {
  final bool existingUser;

  const CompanyInviteResult({required this.existingUser});
}
''',
    r'''class CompanyInviteResult {
  final bool existingUser;
  final String inviteUrl;
  final String delivery;

  const CompanyInviteResult({
    required this.existingUser,
    required this.inviteUrl,
    required this.delivery,
  });

  bool get requiresPasswordSetup =>
      delivery == 'invite_link' || delivery == 'password_setup_link';
}
''',
)
replace_once(
    company_repo_path,
    r'''        'role': role,
        'object_id': objectId,
      },
''',
    r'''        'role': role,
        'object_id': objectId,
        'redirect_to': UserRepository.buildInvitationRedirectUrl(companyId),
      },
''',
)
replace_once(
    company_repo_path,
    r'''    return CompanyInviteResult(existingUser: data['existing_user'] == true);
''',
    r'''    final inviteUrl = data['invite_url']?.toString().trim() ?? '';
    if (inviteUrl.isEmpty) {
      throw Exception('Сервис не вернул ссылку приглашения');
    }

    return CompanyInviteResult(
      existingUser: data['existing_user'] == true,
      inviteUrl: inviteUrl,
      delivery: data['delivery']?.toString() ?? 'invite_link',
    );
''',
)

# Admin UI: show, select and copy the link instead of claiming an email was sent.
management_path = 'lib/features/company/presentation/company_management_screen.dart'
replace_once(
    management_path,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
)
replace_once(
    management_path,
    r'''  Future<void> save() async {
''',
    r'''  Future<void> showInvitationLink(
    CompanyInviteResult result,
    String email,
  ) async {
    final description = result.requiresPasswordSetup
        ? 'Пользователь откроет ссылку, войдёт в нужную компанию и задаст пароль.'
        : 'Пользователь уже зарегистрирован. Ссылка выполнит безопасный вход и откроет нужную компанию.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ссылка приглашения готова'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$description\n\nПолучатель: $email',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    result.inviteUrl,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Передайте эту ссылку только приглашённому человеку.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.inviteUrl));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Копировать'),
            ),
          ],
        );
      },
    );
  }

  Future<void> save() async {
''',
)
replace_once(
    management_path,
    r'''        if (!mounted) return;
        Navigator.pop(
          context,
          result.existingUser
              ? 'Доступ добавлен существующему пользователю'
              : 'Приглашение отправлено на email',
        );
''',
    r'''        if (!mounted) return;
        await showInvitationLink(result, email);
        if (!mounted) return;
        Navigator.pop(
          context,
          result.existingUser
              ? 'Ссылка входа создана, доступ к компании добавлен'
              : 'Ссылка приглашения создана',
        );
''',
)
replace_once(
    management_path,
    r'''            icon: isEditing ? Icons.save_outlined : Icons.send_outlined,
            label: isEditing
                ? 'Сохранить права'
                : 'Отправить приглашение',
''',
    r'''            icon: isEditing ? Icons.save_outlined : Icons.link_rounded,
            label: isEditing ? 'Сохранить права' : 'Создать ссылку',
''',
)

# Edge function: create one-time invite/recovery/magic links and return action_link.
edge_path = 'supabase/functions/invite-company-member/index.ts'
replace_once(
    edge_path,
    r'''function cleanEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}
''',
    r'''function cleanEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

const defaultWebAppUrl = "https://13off.github.io/appstroy-web/";

function invitationRedirectUrl(value: unknown, companyId: string) {
  const requested = String(value ?? "").trim() || defaultWebAppUrl;
  let url: URL;

  try {
    url = new URL(requested);
  } catch (_) {
    url = new URL(defaultWebAppUrl);
  }

  const allowedHost =
    url.host === "13off.github.io" ||
    url.hostname === "localhost" ||
    url.hostname === "127.0.0.1";
  const allowedProtocol =
    url.protocol === "https:" ||
    ((url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
      url.protocol === "http:");

  if (!allowedHost || !allowedProtocol) {
    url = new URL(defaultWebAppUrl);
  }

  url.hash = "";
  url.search = "";
  url.searchParams.set("companyInvite", companyId);
  return url.toString();
}
''',
)
replace_once(
    edge_path,
    r'''    const objectId = String(input.object_id ?? "").trim();
''',
    r'''    const objectId = String(input.object_id ?? "").trim();
    const redirectTo = invitationRedirectUrl(input.redirect_to, companyId);
''',
)
old_link_block = r'''    let invitedUser = await findUserByEmail(adminClient, email);
    const existingUser = invitedUser !== null;
    const existingUserId = invitedUser?.id;
    const mustSetPasswordValue =
      invitedUser?.user_metadata?.must_set_password;
    const requiresPasswordSetup =
      existingUser &&
      (
        mustSetPasswordValue === true ||
        String(mustSetPasswordValue).toLowerCase() === "true"
      );

    let existingMembership: { user_id: string } | null = null;
    if (existingUserId) {
      const membershipResult = await adminClient
        .from("company_memberships")
        .select("user_id")
        .eq("company_id", companyId)
        .eq("user_id", existingUserId)
        .eq("is_active", true)
        .maybeSingle();
      if (membershipResult.error) throw membershipResult.error;
      existingMembership = membershipResult.data;
    }

    if (!existingMembership) {
      const membershipCountResult = await adminClient
        .from("company_memberships")
        .select("user_id", { count: "exact", head: true })
        .eq("company_id", companyId)
        .eq("is_active", true);
      if (membershipCountResult.error) throw membershipCountResult.error;
      if ((membershipCountResult.count ?? 0) >= Number(company.seat_limit)) {
        return json({ error: "Достигнут лимит пользователей тарифа" }, 409);
      }
    }

    if (!invitedUser) {
      const { data: inviteData, error: inviteError } =
        await adminClient.auth.admin.inviteUserByEmail(email, {
          data: {
            full_name: fullName,
            invited_company_id: companyId,
            invited_company_name: company.name,
            must_set_password: true,
          },
        });
      if (inviteError) throw inviteError;
      invitedUser = inviteData.user;
    } else if (requiresPasswordSetup) {
      const { error: recoveryError } =
        await adminClient.auth.resetPasswordForEmail(email);
      if (recoveryError) throw recoveryError;
    }
'''
new_link_block = r'''    let invitedUser = await findUserByEmail(adminClient, email);
    const existingUser = invitedUser !== null;
    const existingUserId = invitedUser?.id;
    const mustSetPasswordValue =
      invitedUser?.user_metadata?.must_set_password;
    const requiresPasswordSetup =
      existingUser &&
      (
        mustSetPasswordValue === true ||
        String(mustSetPasswordValue).toLowerCase() === "true"
      );

    let existingMembership: { user_id: string } | null = null;
    if (existingUserId) {
      const membershipResult = await adminClient
        .from("company_memberships")
        .select("user_id")
        .eq("company_id", companyId)
        .eq("user_id", existingUserId)
        .eq("is_active", true)
        .maybeSingle();
      if (membershipResult.error) throw membershipResult.error;
      existingMembership = membershipResult.data;
    }

    if (!existingMembership) {
      const membershipCountResult = await adminClient
        .from("company_memberships")
        .select("user_id", { count: "exact", head: true })
        .eq("company_id", companyId)
        .eq("is_active", true);
      if (membershipCountResult.error) throw membershipCountResult.error;
      if ((membershipCountResult.count ?? 0) >= Number(company.seat_limit)) {
        return json({ error: "Достигнут лимит пользователей тарифа" }, 409);
      }
    }

    let actionLink = "";
    let delivery = "invite_link";

    if (!invitedUser) {
      const { data: linkData, error: linkError } =
        await adminClient.auth.admin.generateLink({
          type: "invite",
          email,
          options: {
            redirectTo,
            data: {
              full_name: fullName,
              invited_company_id: companyId,
              invited_company_name: company.name,
              must_set_password: true,
            },
          },
        });
      if (linkError) throw linkError;
      invitedUser = linkData.user;
      actionLink = linkData.properties?.action_link ?? "";
      delivery = "invite_link";
    } else {
      const linkType = requiresPasswordSetup ? "recovery" : "magiclink";
      const { data: linkData, error: linkError } =
        await adminClient.auth.admin.generateLink({
          type: linkType,
          email,
          options: { redirectTo },
        });
      if (linkError) throw linkError;
      actionLink = linkData.properties?.action_link ?? "";
      delivery = requiresPasswordSetup
        ? "password_setup_link"
        : "sign_in_link";
    }

    if (!actionLink) {
      throw new Error("Supabase не вернул ссылку приглашения");
    }
'''
replace_once(edge_path, old_link_block, new_link_block)
replace_once(
    edge_path,
    r'''        status: existingUser && !requiresPasswordSetup
          ? "accepted"
          : "pending",
        accepted_at: existingUser && !requiresPasswordSetup
          ? new Date().toISOString()
          : null,
''',
    r'''        status: "pending",
        accepted_at: null,
''',
)
replace_once(
    edge_path,
    r'''      delivery: !existingUser
        ? "email_invited"
        : requiresPasswordSetup
        ? "password_setup_resent"
        : "access_granted",
''',
    r'''      delivery,
      invite_url: actionLink,
      redirect_to: redirectTo,
''',
)

# Existing functional contract now expects generated action links.
contract_path = 'test/functional_contract_test.dart'
replace_once(
    contract_path,
    r'''        const [
          'inviteUserByEmail',
          'resetPasswordForEmail',
          '"password_setup_resent"',
        ],
''',
    r'''        const [
          'generateLink',
          'type: "invite"',
          '"recovery"',
          '"magiclink"',
          'invite_url: actionLink',
        ],
''',
)

TEST = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('admin receives a copyable company invitation link', () {
    final screen = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );
    final repository = source(
      'lib/features/company/data/company_repository.dart',
    );

    expect(screen, contains("'Ссылка приглашения готова'"));
    expect(screen, contains('Clipboard.setData'));
    expect(screen, contains("'Создать ссылку'"));
    expect(repository, contains("'redirect_to'"));
    expect(repository, contains("data['invite_url']"));
  });

  test('edge function creates invite recovery and magic action links', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');

    expect(edge, contains('auth.admin.generateLink'));
    expect(edge, contains('type: "invite"'));
    expect(edge, contains('? "recovery" : "magiclink"'));
    expect(edge, contains('invite_url: actionLink'));
    expect(edge, contains('companyInvite'));
    expect(edge, isNot(contains('inviteUserByEmail')));
    expect(edge, isNot(contains('resetPasswordForEmail')));
  });

  test('invitation link activates its company before profile loading', () {
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );

    final applyIndex = gate.indexOf('applyPendingInvitationCompany()');
    final profileIndex = gate.indexOf('fetchCurrentProfile(');
    expect(applyIndex, greaterThan(-1));
    expect(profileIndex, greaterThan(applyIndex));
    expect(gate, contains('AuthChangeEvent.passwordRecovery'));

    expect(repository, contains("_invitationCompanyParameter = 'companyInvite'"));
    expect(repository, contains("await setActiveCompany(companyId)"));
    expect(repository, contains("accept_current_company_invitation"));
    expect(repository, contains('history.replaceState'));
  });

  test('repeat login restores a missing active company from membership', () {
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );

    expect(repository, contains(".from('company_memberships')"));
    expect(repository, contains(".select('company_id')"));
    expect(repository, contains("'set_active_company'"));
    expect(repository, contains('await _client.auth.refreshSession()'));
    expect(repository, contains('static Session? get currentSession'));
  });
}
'''
write('test/invitation_links_session_contract_test.dart', TEST)

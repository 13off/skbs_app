from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    file = ROOT / path
    source = file.read_text(encoding='utf-8')
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/features/auth/data/user_repository.dart',
    """  static String buildInvitationRedirectUrl(String companyId) {
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
""",
    """  static String buildInvitationRedirectUrl(String companyId) {
    final cleanCompanyId = companyId.trim();
    final productionApp = Uri.parse(_fallbackWebAppUrl);

    return productionApp
        .replace(
          queryParameters: <String, String>{
            _invitationCompanyParameter: cleanCompanyId,
          },
          fragment: '',
        )
        .toString();
  }
""",
)

replace_once(
    'supabase/functions/invite-company-member/index.ts',
    """function invitationRedirectUrl(value: unknown, companyId: string) {
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
""",
    """function invitationRedirectUrl(companyId: string) {
  const url = new URL(defaultWebAppUrl);
  url.searchParams.set("companyInvite", companyId);
  return url.toString();
}
""",
)

replace_once(
    'supabase/functions/invite-company-member/index.ts',
    '    const redirectTo = invitationRedirectUrl(input.redirect_to, companyId);\n',
    '    const redirectTo = invitationRedirectUrl(companyId);\n',
)

contract = ROOT / 'test/invitation_redirect_contract_test.dart'
contract.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company invitations always return to the production web app', () {
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );
    final edge = source('supabase/functions/invite-company-member/index.ts');

    final methodStart = repository.indexOf(
      'static String buildInvitationRedirectUrl',
    );
    final methodEnd = repository.indexOf(
      'static String? get pendingInvitationCompanyId',
      methodStart,
    );
    final redirectMethod = repository.substring(methodStart, methodEnd);

    expect(redirectMethod, contains('Uri.parse(_fallbackWebAppUrl)'));
    expect(redirectMethod, isNot(contains('Uri.base')));
    expect(edge, contains('function invitationRedirectUrl(companyId: string)'));
    expect(edge, contains('new URL(defaultWebAppUrl)'));
    expect(edge, contains('invitationRedirectUrl(companyId)'));
    expect(edge, isNot(contains('url.hostname === "localhost"')));
    expect(edge, isNot(contains('input.redirect_to')));
  });
}
""",
    encoding='utf-8',
)

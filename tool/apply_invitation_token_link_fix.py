from pathlib import Path


auth_gate = Path('lib/features/auth/presentation/premium_auth_gate_v2.dart')
text = auth_gate.read_text(encoding='utf-8')
old = """    final token = ++loadToken;
    final session = UserRepository.currentSession;
"""
new = """    final token = ++loadToken;

    try {
      await UserRepository.verifyPendingInvitationLink();
    } catch (error) {
      if (!mounted || token != loadToken) return;
      setState(() {
        profile = null;
        lastLoadedUserId = null;
        errorText = 'Ошибка приглашения: $error';
        isLoading = false;
      });
      return;
    }

    if (!mounted || token != loadToken) return;
    final session = UserRepository.currentSession;
"""
if 'verifyPendingInvitationLink' not in text:
    if old not in text:
        raise RuntimeError('Не найдено начало loadCurrentUser')
    text = text.replace(old, new, 1)
auth_gate.write_text(text, encoding='utf-8')

edge = Path('supabase/functions/invite-company-member/index.ts')
text = edge.read_text(encoding='utf-8')
redirect_helper = """function invitationRedirectUrl(companyId: string) {
  const url = new URL(defaultWebAppUrl);
  url.searchParams.set("companyInvite", companyId);
  return url.toString();
}
"""
action_helper = redirect_helper + """
function invitationActionUrl(
  companyId: string,
  tokenHash: string,
  verificationType: string,
) {
  const url = new URL(defaultWebAppUrl);
  url.searchParams.set("companyInvite", companyId);
  url.searchParams.set("inviteTokenHash", tokenHash);
  url.searchParams.set("inviteType", verificationType);
  return url.toString();
}
"""
if 'function invitationActionUrl(' not in text:
    if redirect_helper not in text:
        raise RuntimeError('Не найден helper invitationRedirectUrl')
    text = text.replace(redirect_helper, action_helper, 1)

action_assignment = '      actionLink = linkData.properties?.action_link ?? "";'
invite_assignment = """      const tokenHash = linkData.properties?.hashed_token ?? "";
      const verificationType =
        linkData.properties?.verification_type ?? "invite";
      if (!tokenHash) {
        throw new Error("Supabase не вернул токен приглашения");
      }
      actionLink = invitationActionUrl(
        companyId,
        tokenHash,
        verificationType,
      );"""
existing_assignment = """      const tokenHash = linkData.properties?.hashed_token ?? "";
      const verificationType =
        linkData.properties?.verification_type ?? linkType;
      if (!tokenHash) {
        throw new Error("Supabase не вернул токен входа");
      }
      actionLink = invitationActionUrl(
        companyId,
        tokenHash,
        verificationType,
      );"""
if action_assignment in text:
    text = text.replace(action_assignment, invite_assignment, 1)
if action_assignment in text:
    text = text.replace(action_assignment, existing_assignment, 1)
if action_assignment in text:
    raise RuntimeError('Осталась выдача action_link Supabase')
if text.count('invitationActionUrl(') < 3:
    raise RuntimeError('Не все ветки переведены на token hash URL')
edge.write_text(text, encoding='utf-8')

contract = Path('test/invitation_token_link_contract_test.dart')
contract.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation link bypasses localhost redirect and verifies token in app', () {
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final edge = source(
      'supabase/functions/invite-company-member/index.ts',
    );

    expect(edge, contains('https://13off.github.io/appstroy-web/'));
    expect(edge, contains('inviteTokenHash'));
    expect(edge, contains('inviteType'));
    expect(edge, contains('properties?.hashed_token'));
    expect(
      edge,
      isNot(contains('actionLink = linkData.properties?.action_link')),
    );

    expect(repository, contains('verifyPendingInvitationLink'));
    expect(repository, contains('verifyOTP('));
    expect(repository, contains('tokenHash: tokenHash'));
    expect(repository, contains('OtpType.invite'));
    expect(repository, contains('OtpType.recovery'));
    expect(repository, contains('OtpType.magiclink'));

    final verifyIndex = gate.indexOf(
      'await UserRepository.verifyPendingInvitationLink()',
    );
    final sessionIndex = gate.indexOf(
      'final session = UserRepository.currentSession;',
    );
    expect(verifyIndex, greaterThanOrEqualTo(0));
    expect(sessionIndex, greaterThan(verifyIndex));
  });
}
""", encoding='utf-8')

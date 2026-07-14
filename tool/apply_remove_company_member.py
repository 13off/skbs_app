from pathlib import Path

repository = Path('lib/features/company/data/company_repository.dart')
text = repository.read_text(encoding='utf-8')
marker = "  static Future<void> updateMemberAccess({"
addition = '''  static Future<void> removeMember({
    required String companyId,
    required CompanyMember member,
  }) async {
    await _client.rpc(
      'remove_company_member',
      params: <String, dynamic>{
        'p_company_id': companyId,
        'p_user_id': member.userId,
      },
    );
  }

'''
if addition.strip() not in text:
    if marker not in text:
        raise RuntimeError('Не найден маркер updateMemberAccess')
    text = text.replace(marker, addition + marker, 1)
repository.write_text(text, encoding='utf-8')

screen = Path('lib/features/company/presentation/company_management_screen.dart')
text = screen.read_text(encoding='utf-8')
save_marker = "  Future<void> save() async {"
removal_method = '''  Future<void> removeMember() async {
    if (!isEditing || isSaving) return;
    final member = widget.member!;
    final displayName = member.fullName.trim().isEmpty
        ? member.email
        : member.fullName.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          '$displayName потеряет доступ к этой компании и назначенному объекту. Его аккаунт и доступ к другим компаниям сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF874540),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });
    try {
      await CompanyRepository.removeMember(
        companyId: widget.companyId,
        member: member,
      );
      if (mounted) Navigator.pop(context, 'Пользователь удалён из компании');
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

'''
if removal_method.strip() not in text:
    if save_marker not in text:
        raise RuntimeError('Не найден маркер save')
    text = text.replace(save_marker, removal_method + save_marker, 1)

button_marker = '''          PremiumActionButton(
            onPressed: isSaving ? null : save,
            icon: isEditing ? Icons.save_outlined : Icons.link_rounded,
            label: isEditing ? 'Сохранить права' : 'Создать ссылку',
            isLoading: isSaving,
          ),'''
replacement = button_marker + '''
          if (isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF874540),
                side: const BorderSide(color: Color(0xFFB88A85)),
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: isSaving ? null : removeMember,
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Удалить из компании'),
            ),
          ],'''
if "label: const Text('Удалить из компании')" not in text:
    if button_marker not in text:
        raise RuntimeError('Не найдена кнопка сохранения')
    text = text.replace(button_marker, replacement, 1)
screen.write_text(text, encoding='utf-8')

test = Path('test/remove_company_member_contract_test.dart')
test.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('admin can remove a non-owner member from one company', () {
    final screen = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );
    final repository = source(
      'lib/features/company/data/company_repository.dart',
    );
    final migration = source(
      'supabase/migrations/20260714093000_add_remove_company_member_rpc.sql',
    );

    expect(screen, contains("'Удалить из компании'"));
    expect(screen, contains("'Удалить пользователя?'"));
    expect(screen, contains('CompanyRepository.removeMember('));
    expect(repository, contains("'remove_company_member'"));
    expect(repository, contains("'p_company_id'"));
    expect(repository, contains("'p_user_id'"));

    expect(migration, contains("v_actor_role not in ('owner', 'admin')"));
    expect(migration, contains("v_target_role = 'owner'"));
    expect(migration, contains('p_user_id = v_actor_id'));
    expect(migration, contains('delete from public.object_memberships'));
    expect(migration, contains('delete from public.company_memberships'));
    expect(migration, contains("status = 'revoked'"));
    expect(migration, contains('grant execute on function'));
  });
}
""", encoding='utf-8')

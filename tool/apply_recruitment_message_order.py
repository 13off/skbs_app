from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found: {label} in {path}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')

repository = 'lib/features/recruitment/data/recruitment_repository.dart'
replace_once(
    repository,
    """    final rows = await _client
        .from('recruitment_messages')
        .select()
        .eq('company_id', companyId.trim())
        .eq('application_id', applicationId.trim())
        .order('created_at');
    return rows
        .map<RecruitmentMessage>(
          (value) => RecruitmentMessage.fromMap(_map(value)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
""",
    """    final rows = await _client
        .from('recruitment_messages')
        .select()
        .eq('company_id', companyId.trim())
        .eq('application_id', applicationId.trim())
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    final messages = rows
        .map<RecruitmentMessage>(
          (value) => RecruitmentMessage.fromMap(_map(value)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((first, second) {
        final byTime = first.createdAt.compareTo(second.createdAt);
        if (byTime != 0) return byTime;
        return first.id.compareTo(second.id);
      });
    return messages;
""",
    'explicit ascending message order',
)

screen = 'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart'
replace_once(
    screen,
    """                  child: ListView.builder(
                    controller: messageScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    itemCount: messages.length,
""",
    """                  child: ListView.builder(
                    controller: messageScrollController,
                    reverse: false,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    itemCount: messages.length,
""",
    'non-reversed chat list',
)

test = 'test/recruitment_documents_chat_contract_test.dart'
replace_once(
    test,
    """    expect(sync, contains(\"case 'recruitment_messages':\"));
  });
}
""",
    """    expect(sync, contains(\"case 'recruitment_messages':\"));
  });

  test('messages are always ordered from oldest to newest', () {
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );
    final detail = source(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    );

    expect(repository, contains(\".order('created_at', ascending: true)\"));
    expect(repository, contains(\".order('id', ascending: true)\"));
    expect(repository, contains('first.createdAt.compareTo(second.createdAt)'));
    expect(detail, contains('reverse: false'));
  });
}
""",
    'message order contract',
)

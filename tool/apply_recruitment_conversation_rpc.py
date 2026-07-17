from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


repository = "lib/features/recruitment/data/recruitment_repository.dart"
replace_once(
    repository,
    """  static Future<void> sendCandidateMessage({
    required String applicationId,
    required String message,
  }) async {
    final response = await _client.functions.invoke(
      'recruitment-candidate-action',
      body: <String, dynamic>{
        'action': 'send_message',
        'application_id': applicationId.trim(),
        'message': message.trim(),
      },
    );
""",
    """  static Future<void> sendCandidateMessage({
    required String applicationId,
    required String message,
  }) async {
    final cleanApplicationId = applicationId.trim();
    await _client.rpc(
      'activate_recruitment_telegram_conversation',
      params: <String, dynamic>{
        'p_application_id': cleanApplicationId,
      },
    );

    final response = await _client.functions.invoke(
      'recruitment-candidate-action',
      body: <String, dynamic>{
        'action': 'send_message',
        'application_id': cleanApplicationId,
        'message': message.trim(),
      },
    );
""",
    "activate conversation before send",
)
replace_once(
    repository,
    """    _notify(applicationId.trim());
  }
""",
    """    _notify(cleanApplicationId);
  }
""",
    "clean conversation notification",
)

test = "test/recruitment_documents_chat_contract_test.dart"
replace_once(
    test,
    """    expect(repository, contains("'action': 'send_message'"));
    expect(repository, contains("'action': 'delete_application'"));
""",
    """    expect(repository, contains("'action': 'send_message'"));
    expect(
      repository,
      contains("'activate_recruitment_telegram_conversation'"),
    );
    expect(repository, contains("'p_application_id': cleanApplicationId"));
    expect(repository, contains("'action': 'delete_application'"));
""",
    "conversation rpc contract",
)

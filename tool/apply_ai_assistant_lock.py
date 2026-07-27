from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f'Не найден маркер в {path}: {old[:120]!r}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


source_path = 'lib/features/company_chat/presentation/company_chat_shell.dart'
test_path = 'test/company_chat_compact_window_contract_test.dart'

replace_once(
    source_path,
    "import '../models/company_chat_models.dart';\n\nclass CompanyChatShell",
    "import '../models/company_chat_models.dart';\n\n"
    "const bool _aiAssistantLocked = true;\n\n"
    "class CompanyChatShell",
)

replace_once(
    source_path,
    '''  Future<void> selectThread(CompanyChatThread thread) async {
    if (selectedThread?.threadKey == thread.threadKey || sending) return;''',
    '''  Future<void> selectThread(CompanyChatThread thread) async {
    if (thread.isAssistant && _aiAssistantLocked) {
      showMessage('ИИ-помощник временно недоступен');
      return;
    }
    if (selectedThread?.threadKey == thread.threadKey || sending) return;''',
)

replace_once(
    source_path,
    '''  Future<void> sendMessage() async {
    final thread = selectedThread;
    final text = messageController.text.trim();
    if (thread == null || sending || (text.isEmpty && pendingFiles.isEmpty)) {
      return;
    }''',
    '''  Future<void> sendMessage() async {
    final thread = selectedThread;
    final text = messageController.text.trim();
    if (thread == null || sending || (text.isEmpty && pendingFiles.isEmpty)) {
      return;
    }
    if (thread.isAssistant && _aiAssistantLocked) {
      showMessage('ИИ-помощник временно недоступен');
      return;
    }''',
)

replace_once(
    source_path,
    '''                      onTap: () => onSelectThread(assistant.first),
                      assistant: true,''',
    '''                      onTap: () => onSelectThread(assistant.first),
                      assistant: true,
                      locked: _aiAssistantLocked,''',
)

replace_once(
    source_path,
    '''class _ThreadTile extends StatelessWidget {
  final CompanyChatThread thread;
  final bool selected;
  final VoidCallback onTap;
  final bool assistant;

  const _ThreadTile({
    required this.thread,
    required this.selected,
    required this.onTap,
    this.assistant = false,
  });''',
    '''class _ThreadTile extends StatelessWidget {
  final CompanyChatThread thread;
  final bool selected;
  final VoidCallback onTap;
  final bool assistant;
  final bool locked;

  const _ThreadTile({
    required this.thread,
    required this.selected,
    required this.onTap,
    this.assistant = false,
    this.locked = false,
  });''',
)

replace_once(
    source_path,
    '''    final subtitle = thread.lastMessagePreview.isNotEmpty
        ? thread.lastMessagePreview
        : thread.isDirect
        ? AppUserProfile.titleForRole(thread.role)
        : thread.isAssistant
        ? 'Помощник AppСтрой'
        : 'Для всей компании';''',
    '''    final subtitle = locked
        ? 'Временно недоступен'
        : thread.lastMessagePreview.isNotEmpty
        ? thread.lastMessagePreview
        : thread.isDirect
        ? AppUserProfile.titleForRole(thread.role)
        : thread.isAssistant
        ? 'Помощник AppСтрой'
        : 'Для всей компании';''',
)

replace_once(
    source_path,
    '''                if (thread.unreadCount > 0) ...[
                  const SizedBox(width: 5),
                  _UnreadBadge(count: thread.unreadCount),
                ],''',
    '''                if (locked) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.lock_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
                if (thread.unreadCount > 0) ...[
                  const SizedBox(width: 5),
                  _UnreadBadge(count: thread.unreadCount),
                ],''',
)

replace_once(
    source_path,
    '''  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assistant = selectedThread?.isAssistant == true;
    return Container(''',
    '''  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assistant = selectedThread?.isAssistant == true;
    final locked = assistant && _aiAssistantLocked;
    return Container(''',
)

replace_once(
    source_path,
    '''                  onPressed: sending || selectedThread == null
                      ? null
                      : onPickFiles,''',
    '''                  onPressed: locked || sending || selectedThread == null
                      ? null
                      : onPickFiles,''',
)

replace_once(
    source_path,
    '''                    enabled: !sending && selectedThread != null,''',
    '''                    enabled: !locked && !sending && selectedThread != null,''',
)

replace_once(
    source_path,
    '''                      hintText: assistant
                          ? 'Сообщение ИИ-помощнику…'
                          : 'Сообщение…',''',
    '''                      hintText: locked
                          ? 'ИИ-помощник временно недоступен'
                          : assistant
                          ? 'Сообщение ИИ-помощнику…'
                          : 'Сообщение…',''',
)

replace_once(
    source_path,
    '''                IconButton.filled(
                  tooltip: assistant ? 'Отправить ИИ' : 'Отправить',
                  onPressed: sending || askingAi || selectedThread == null
                      ? null
                      : onSend,
                  icon: sending || askingAi
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          assistant
                              ? Icons.auto_awesome_rounded
                              : Icons.send_rounded,
                          size: 19,
                        ),
                ),''',
    '''                IconButton.filled(
                  tooltip: locked
                      ? 'ИИ-помощник временно недоступен'
                      : assistant
                      ? 'Отправить ИИ'
                      : 'Отправить',
                  onPressed:
                      locked || sending || askingAi || selectedThread == null
                      ? null
                      : onSend,
                  icon: locked
                      ? const Icon(Icons.lock_rounded, size: 19)
                      : sending || askingAi
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          assistant
                              ? Icons.auto_awesome_rounded
                              : Icons.send_rounded,
                          size: 19,
                        ),
                ),''',
)

replace_once(
    test_path,
    '''  test('photos and files are sent inside the compact workspace', () {''',
    '''  test('assistant is visibly locked and cannot be opened or used', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(source, contains('const bool _aiAssistantLocked = true'));
    expect(source, contains("showMessage('ИИ-помощник временно недоступен')"));
    expect(source, contains("locked ? 'Временно недоступен'"));
    expect(source, contains('Icons.lock_rounded'));
    expect(source, contains('if (thread.isAssistant && _aiAssistantLocked)'));
    expect(source, contains('final locked = assistant && _aiAssistantLocked'));
  });

  test('photos and files are sent inside the compact workspace', () {''',
)

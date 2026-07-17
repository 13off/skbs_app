from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


screen = "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart"
replace_once(
    screen,
    """  Future<void> openStoredFile({
    required String id,
    required String bucket,
    required String path,
  }) async {
    if (openingId != null) return;
    setState(() => openingId = id);
    try {
      final signedUrl = await RecruitmentRepository.createSignedFileUrl(
        bucket: bucket,
        path: path,
      );
      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось открыть файл');
    } catch (error) {
      showError(error.toString());
    } finally {
      if (mounted) setState(() => openingId = null);
    }
  }
""",
    """  Future<void> openStoredFile({
    required String id,
    required String bucket,
    required String path,
    required String title,
    required bool isImage,
  }) async {
    if (openingId != null) return;
    setState(() => openingId = id);
    try {
      if (isImage) {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: bucket,
          path: path,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _RecruitmentImageViewer(
              title: title,
              bytes: bytes,
            ),
          ),
        );
        return;
      }

      final signedUrl = await RecruitmentRepository.createSignedFileUrl(
        bucket: bucket,
        path: path,
      );
      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось открыть файл');
    } catch (error) {
      showError(error.toString());
    } finally {
      if (mounted) setState(() => openingId = null);
    }
  }
""",
    "in-app image viewer method",
)
replace_once(
    screen,
    """                              : () => openStoredFile(
                                  id: document.id,
                                  bucket: document.storageBucket,
                                  path: document.storagePath,
                                ),
""",
    """                              : () => openStoredFile(
                                  id: document.id,
                                  bucket: document.storageBucket,
                                  path: document.storagePath,
                                  title: downloadName(document),
                                  isImage: document.isImage,
                                ),
""",
    "document open action",
)
replace_once(
    screen,
    """                    ? () => openStoredFile(
                        id: message.id,
                        bucket: message.storageBucket,
                        path: message.storagePath,
                      )
""",
    """                    ? () => openStoredFile(
                        id: message.id,
                        bucket: message.storageBucket,
                        path: message.storagePath,
                        title: message.originalName.isEmpty
                            ? 'Вложение кандидата'
                            : message.originalName,
                        isImage: message.mimeType.startsWith('image/'),
                      )
""",
    "message attachment open action",
)
replace_once(
    screen,
    """}

class _DetailPill extends StatelessWidget {
""",
    """}

class _RecruitmentImageViewer extends StatelessWidget {
  final String title;
  final Uint8List bytes;

  const _RecruitmentImageViewer({
    required this.title,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
""",
    "image viewer widget",
)

server = "supabase/functions/recruitment-candidate-action/index.ts"
replace_once(
    server,
    """  external_chat_id: string;
  status: string;
""",
    """  external_chat_id: string;
  external_user_id: string;
  status: string;
""",
    "application external user type",
)
replace_once(
    server,
    '"id,company_id,full_name,source,external_chat_id,status,archived_at",',
    '"id,company_id,full_name,source,external_chat_id,external_user_id,status,archived_at",',
    "application external user select",
)
replace_once(
    server,
    """      if (messageError) throw messageError;

      if (application.status === "new" || application.status === "draft") {
""",
    """      if (messageError) throw messageError;

      const { data: currentSession, error: sessionReadError } = await admin
        .from("recruitment_bot_sessions")
        .select("external_user_id,draft")
        .eq("source", "telegram")
        .eq("external_chat_id", application.external_chat_id)
        .maybeSingle();
      if (sessionReadError) throw sessionReadError;
      const currentDraft = currentSession?.draft && typeof currentSession.draft === "object"
        ? currentSession.draft as JsonMap
        : {};
      const { error: sessionError } = await admin
        .from("recruitment_bot_sessions")
        .upsert({
          source: "telegram",
          external_chat_id: application.external_chat_id,
          external_user_id: String(
            currentSession?.external_user_id
              ?? application.external_user_id
              ?? application.external_chat_id,
          ),
          company_id: application.company_id,
          step: "submitted",
          draft: {
            ...currentDraft,
            full_name: application.full_name,
          },
          application_id: application.id,
          updated_at: new Date().toISOString(),
        }, { onConflict: "source,external_chat_id" });
      if (sessionError) throw sessionError;

      if (application.status === "new" || application.status === "draft") {
""",
    "activate outbound application session",
)

test = "test/recruitment_documents_chat_contract_test.dart"
replace_once(
    test,
    """    expect(detail, isNot(contains('Widget imagePreview(')));
    expect(detail, isNot(contains('InteractiveViewer(')));
    expect(detail, isNot(contains('Image.network(')));
""",
    """    expect(detail, isNot(contains('Widget imagePreview(')));
    expect(detail, isNot(contains('Image.network(')));
    expect(detail, contains('class _RecruitmentImageViewer'));
    expect(detail, contains('InteractiveViewer('));
    expect(detail, contains('Image.memory('));
    expect(detail, contains('downloadStoredFile'));
""",
    "viewer contract",
)
replace_once(
    test,
    """    expect(repository, contains("'action': 'send_message'"));
    expect(repository, contains("'action': 'delete_application'"));
    expect(sync, contains("case 'recruitment_messages':"));
""",
    """    expect(repository, contains("'action': 'send_message'"));
    expect(repository, contains("'action': 'delete_application'"));
    final candidateAction = source(
      'supabase/functions/recruitment-candidate-action/index.ts',
    );
    expect(candidateAction, contains('.from("recruitment_bot_sessions")'));
    expect(candidateAction, contains('application_id: application.id'));
    expect(candidateAction, contains('step: "submitted"'));
    expect(sync, contains("case 'recruitment_messages':"));
""",
    "conversation routing contract",
)

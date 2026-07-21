import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../ai/models/ai_assistant_result.dart';
import '../../ai/presentation/ai_employee_draft_screen.dart';
import '../data/candidate_onboarding_package_service.dart';
import '../data/candidate_onboarding_repository.dart';
import '../models/candidate_onboarding_candidate.dart';
import '../models/candidate_onboarding_models.dart';

class RecruitmentOnboardingScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentOnboardingScreen({super.key, required this.profile});

  @override
  State<RecruitmentOnboardingScreen> createState() =>
      _RecruitmentOnboardingScreenState();
}

class _RecruitmentOnboardingScreenState
    extends State<RecruitmentOnboardingScreen> {
  late Future<List<CandidateOnboardingCandidate>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<CandidateOnboardingCandidate>> load() {
    return CandidateOnboardingRepository.fetchCandidates(
      companyId: widget.profile.activeCompanyId,
    );
  }

  void refresh() {
    setState(() => future = load());
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Оформление',
      subtitle: 'Формы, печать, подписи и перевод кандидата в сотрудника',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<List<CandidateOnboardingCandidate>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageCard(
              icon: Icons.error_outline_rounded,
              text: 'Не удалось загрузить оформление: ${snapshot.error}',
            );
          }
          final candidates = snapshot.data ?? const <CandidateOnboardingCandidate>[];
          if (candidates.isEmpty) {
            return const _MessageCard(
              icon: Icons.assignment_turned_in_outlined,
              text: 'Нет кандидатов на этапе оформления. Здесь появятся одобренные, прибывшие и оформленные сотрудники.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SafetyNotice(),
              const SizedBox(height: 14),
              ...candidates.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: PremiumPressable(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        CupertinoPageRoute<void>(
                          builder: (_) => CandidateOnboardingDetailScreen(
                            profile: widget.profile,
                            candidate: candidate,
                          ),
                        ),
                      );
                      refresh();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: PremiumWorkCard(
                      radius: 22,
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: candidate.isLinkedToEmployee
                                  ? const Color(0xFFE7F4EC)
                                  : const Color(0xFFFFF3DE),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              candidate.isLinkedToEmployee
                                  ? Icons.badge_outlined
                                  : Icons.person_add_alt_1_outlined,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  <String>[
                                    candidate.positionTitle,
                                    candidate.objectName,
                                  ].where((value) => value.trim().isNotEmpty).join(' · '),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  candidate.isLinkedToEmployee
                                      ? 'Карточка сотрудника связана'
                                      : 'Нужно создать или связать сотрудника',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CandidateOnboardingDetailScreen extends StatefulWidget {
  final AppUserProfile profile;
  final CandidateOnboardingCandidate candidate;

  const CandidateOnboardingDetailScreen({
    super.key,
    required this.profile,
    required this.candidate,
  });

  @override
  State<CandidateOnboardingDetailScreen> createState() =>
      _CandidateOnboardingDetailScreenState();
}

class _CandidateOnboardingDetailScreenState
    extends State<CandidateOnboardingDetailScreen> {
  late CandidateOnboardingCandidate candidate;
  late Future<List<CandidateOnboardingForm>> formsFuture;
  bool building = false;
  bool creatingEmployee = false;
  String? busyFormCode;
  List<String> lastWarnings = const <String>[];

  @override
  void initState() {
    super.initState();
    candidate = widget.candidate;
    formsFuture = loadForms();
  }

  Future<List<CandidateOnboardingForm>> loadForms() {
    return CandidateOnboardingRepository.fetchForms(
      companyId: candidate.companyId,
      applicationId: candidate.id,
    );
  }

  Future<void> refreshForms() async {
    final next = loadForms();
    setState(() => formsFuture = next);
    await next;
  }

  CandidateOnboardingCandidate linkedCandidate(String employeeId) {
    return CandidateOnboardingCandidate(
      id: candidate.id,
      companyId: candidate.companyId,
      employeeId: employeeId,
      fullName: candidate.fullName,
      phone: candidate.phone,
      citizenship: candidate.citizenship,
      positionTitle: candidate.positionTitle,
      objectName: candidate.objectName,
      status: 'hired',
      readyDate: candidate.readyDate,
      consentPersonalData: candidate.consentPersonalData,
    );
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }

  Future<void> buildPackage() async {
    if (building) return;
    setState(() => building = true);
    try {
      final result = await CandidateOnboardingPackageService.build(candidate);
      await CandidateOnboardingPackageService.save(result);
      await CandidateOnboardingRepository.recordGenerated(
        candidate: candidate,
        missingFieldsByForm: result.missingFieldsByForm,
      );
      if (!mounted) return;
      setState(() => lastWarnings = result.warnings);
      await refreshForms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Кадровый ZIP сохранён: ${result.includedFiles} файлов. '
            'Предупреждений: ${result.warnings.length}.',
          ),
        ),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => building = false);
    }
  }

  Future<void> createEmployee() async {
    if (creatingEmployee || candidate.isLinkedToEmployee) return;
    if (!candidate.consentPersonalData) {
      showError('Сначала нужно подтвердить согласие на обработку данных');
      return;
    }
    setState(() => creatingEmployee = true);
    try {
      final action = AiAssistantAction(
        id: 'onboarding-${candidate.id}',
        type: 'create_employee_draft',
        title: 'Создать сотрудника из кандидата',
        buttonLabel: 'Проверить карточку',
        confirmationRequired: true,
        payload: <String, dynamic>{
          'fio': candidate.fullName,
          'position': candidate.positionTitle,
          'phone': candidate.phone,
          'object_name': candidate.objectName,
          'daily_rate': 6000,
          'comment': 'Создан из подбора. Заявка: ${candidate.id}',
        },
      );
      if (!mounted) return;
      final employeeId = await Navigator.of(context).push<String>(
        CupertinoPageRoute<String>(
          builder: (_) => AiEmployeeDraftScreen(action: action),
        ),
      );
      if (employeeId == null || employeeId.trim().isEmpty) return;
      await CandidateOnboardingRepository.linkEmployee(
        candidate: candidate,
        employeeId: employeeId,
      );
      if (!mounted) return;
      setState(() => candidate = linkedCandidate(employeeId));
      await refreshForms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сотрудник создан и связан с кандидатом'),
        ),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => creatingEmployee = false);
    }
  }

  Future<void> markPrinted(CandidateOnboardingForm form) async {
    if (busyFormCode != null) return;
    setState(() => busyFormCode = form.formCode);
    try {
      await CandidateOnboardingRepository.markPrinted(form);
      await refreshForms();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busyFormCode = null);
    }
  }

  Future<void> uploadSigned(CandidateOnboardingForm form) async {
    if (busyFormCode != null) return;
    const group = XTypeGroup(
      label: 'Подписанный документ',
      extensions: <String>['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: <String>[
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/webp',
      ],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    if (file == null) return;
    setState(() => busyFormCode = form.formCode);
    try {
      final Uint8List bytes = await file.readAsBytes();
      await CandidateOnboardingRepository.uploadSigned(
        form: form,
        bytes: bytes,
        fileName: file.name,
        mimeType: _mimeType(file.name),
      );
      await refreshForms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подписанный экземпляр загружен')),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busyFormCode = null);
    }
  }

  Future<void> openSigned(CandidateOnboardingForm form) async {
    try {
      final url = await CandidateOnboardingRepository.signedUrl(form);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Не удалось открыть файл');
    } catch (error) {
      showError(error);
    }
  }

  String _mimeType(String name) {
    final value = name.toLowerCase();
    if (value.endsWith('.pdf')) return 'application/pdf';
    if (value.endsWith('.png')) return 'image/png';
    if (value.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Widget candidateCard() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            candidate.fullName,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('${candidate.positionTitle} · ${candidate.objectName}'),
          const SizedBox(height: 5),
          Text(
            candidate.consentPersonalData
                ? 'Согласие на обработку данных подтверждено'
                : 'Согласие на обработку данных не подтверждено',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            candidate.isLinkedToEmployee
                ? 'Связан с карточкой сотрудника'
                : 'Карточка сотрудника ещё не создана',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (!candidate.isLinkedToEmployee)
            FilledButton.tonalIcon(
              onPressed: creatingEmployee ? null : createEmployee,
              icon: creatingEmployee
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Создать сотрудника без повторного ввода'),
            ),
        ],
      ),
    );
  }

  Widget formCard(CandidateOnboardingForm form) {
    final busy = busyFormCode == form.formCode;
    final missingText = form.missingFields
        .map(candidateOnboardingFieldTitle)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  form.isSigned
                      ? Icons.verified_outlined
                      : form.isPrinted
                          ? Icons.draw_outlined
                          : Icons.description_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        form.statusTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (missingText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Перед подписью заполнить: $missingText',
                style: const TextStyle(
                  color: Color(0xFF8A5A12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (form.isGenerated && !form.isPrinted)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => markPrinted(form),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Отметить распечатанным'),
                  ),
                if (form.isGenerated)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => uploadSigned(form),
                    icon: busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(form.isSigned ? 'Заменить файл' : 'Загрузить подпись'),
                  ),
                if (form.hasSignedFile)
                  TextButton.icon(
                    onPressed: () => openSigned(form),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Открыть подписанный'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Кадровый комплект',
      subtitle: 'Один ввод данных, четыре формы и контроль подписей',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Обновить',
        onPressed: refreshForms,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          candidateCard(),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: building ? null : buildPackage,
            icon: building
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_zip_outlined),
            label: Text(
              building ? 'Собираем комплект…' : 'Сформировать полный комплект ZIP',
            ),
          ),
          if (lastWarnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MessageCard(
              icon: Icons.warning_amber_rounded,
              text: lastWarnings.join('\n'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Формы и подписи',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<CandidateOnboardingForm>>(
            future: formsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _MessageCard(
                  icon: Icons.error_outline_rounded,
                  text: 'Не удалось загрузить формы: ${snapshot.error}',
                );
              }
              final forms = snapshot.data ?? const <CandidateOnboardingForm>[];
              if (forms.isEmpty) {
                return const _MessageCard(
                  icon: Icons.description_outlined,
                  text: 'Сначала сформируй полный комплект. После этого появятся статусы печати и подписания.',
                );
              }
              final byCode = <String, CandidateOnboardingForm>{
                for (final form in forms) form.formCode: form,
              };
              return Column(
                children: candidateOnboardingFormCodes
                    .where(byCode.containsKey)
                    .map((code) => formCard(byCode[code]!))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          const _SafetyNotice(),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.privacy_tip_outlined,
      text: 'До открытия production gate используй только обезличенные или тестовые копии. '
          'Согласие и трудовой договор перед реальным подписанием должны пройти юридическое утверждение.',
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

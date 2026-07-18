from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    Path(path).write_text(content, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, got {count}: {old[:100]!r}')
    write(path, content.replace(old, new, 1))


def replace_all(path: str, old: str, new: str, minimum: int = 1) -> None:
    content = read(path)
    count = content.count(old)
    if count < minimum:
        raise RuntimeError(f'{path}: expected at least {minimum} matches, got {count}: {old[:100]!r}')
    write(path, content.replace(old, new))


replace_all(
    'lib/features/auth/data/user_repository.dart',
    "'id, email, full_name, role, object_name, is_active, active_company_id',",
    "'id, email, full_name, role, profession, object_name, is_active, active_company_id',",
    minimum=2,
)

replace_once(
    'lib/screens/profile_screen.dart',
    "import '../features/company/presentation/company_switcher_screen.dart';\n",
    "import '../features/company/presentation/company_switcher_screen.dart';\nimport '../features/developer/presentation/developer_panel_screen.dart';\n",
)
replace_once(
    'lib/screens/profile_screen.dart',
    "  void openRolePreview(BuildContext context) {\n    Navigator.push(\n      context,\n      CupertinoPageRoute(builder: (_) => const RolePreviewScreen()),\n    );\n  }\n",
    "  void openRolePreview(BuildContext context) {\n    Navigator.push(\n      context,\n      CupertinoPageRoute(builder: (_) => const RolePreviewScreen()),\n    );\n  }\n\n  void openDeveloperPanel(BuildContext context) {\n    Navigator.push(\n      context,\n      CupertinoPageRoute(\n        builder: (_) => DeveloperPanelScreen(profile: profile),\n      ),\n    );\n  }\n",
)
replace_once(
    'lib/screens/profile_screen.dart',
    "          buildInfoTile(\n            icon: Icons.person_outline,\n            title: 'ФИО',\n            value: profile.fullName,\n          ),\n",
    "          buildInfoTile(\n            icon: Icons.person_outline,\n            title: 'ФИО',\n            value: profile.fullName,\n          ),\n          buildInfoTile(\n            icon: Icons.work_outline_rounded,\n            title: 'Профессия',\n            value: profile.profession,\n          ),\n",
)
replace_once(
    'lib/screens/profile_screen.dart',
    "          const SizedBox(height: 8),\n          if (profile.isAdmin) ...[\n            buildSectionTitle('Управление компанией'),\n",
    "          const SizedBox(height: 8),\n          if (profile.isAdmin) ...[\n            buildSectionTitle('Для разработчика'),\n            buildActionTile(\n              icon: Icons.developer_mode_rounded,\n              title: 'Панель разработчика',\n              subtitle:\n                  'Ограничения компании и объектов, наследование правил и журнал изменений',\n              onTap: () => openDeveloperPanel(context),\n            ),\n            const SizedBox(height: 8),\n            buildSectionTitle('Управление компанией'),\n",
)

replace_once(
    'lib/features/company/data/company_repository.dart',
    "  bool get isAdmin => role == 'owner' || role == 'admin';",
    "  bool get isAdmin =>\n      role == 'owner' || role == 'admin' || role == 'developer';",
)
replace_all(
    'lib/features/company/data/company_repository.dart',
    "      case 'admin':\n        return 'Администратор';\n",
    "      case 'admin':\n        return 'Администратор';\n      case 'developer':\n        return 'Разработчик';\n",
    minimum=2,
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "  final String role;\n  final bool isActive;\n",
    "  final String role;\n  final String profession;\n  final bool isActive;\n",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "    required this.role,\n    required this.isActive,\n",
    "    required this.role,\n    required this.profession,\n    required this.isActive,\n",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    ".select('id, full_name, email')",
    ".select('id, full_name, email, profession')",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "            role: row['role']?.toString() ?? 'foreman',\n            isActive: row['is_active'] == true,\n",
    "            role: row['role']?.toString() ?? 'foreman',\n            profession: profile['profession']?.toString() ?? '',\n            isActive: row['is_active'] == true,\n",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "    required String role,\n    String? objectId,\n  }) async {",
    "    required String role,\n    String profession = '',\n    String? objectId,\n  }) async {",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "        'role': role,\n        'object_id': objectId,\n",
    "        'role': role,\n        'profession': profession.trim(),\n        'object_id': objectId,\n",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "    required String role,\n    String? objectId,\n  }) async {\n    await _client\n",
    "    required String role,\n    String profession = '',\n    String? objectId,\n  }) async {\n    await _client\n",
)
replace_once(
    'lib/features/company/data/company_repository.dart',
    "    final targetProfile = await _client\n        .from('user_profiles')\n        .select('active_company_id')\n",
    "    await _client\n        .from('user_profiles')\n        .update(<String, dynamic>{\n          'profession': profession.trim(),\n          'updated_at': DateTime.now().toUtc().toIso8601String(),\n        })\n        .eq('id', member.userId);\n\n    final targetProfile = await _client\n        .from('user_profiles')\n        .select('active_company_id')\n",
)

path = 'lib/features/company/presentation/mobile_company_management_screen.dart'
replace_once(path, "  late final TextEditingController emailController;\n  late String role;", "  late final TextEditingController emailController;\n  late final TextEditingController professionController;\n  late String role;")
replace_once(path, "    emailController = TextEditingController(text: widget.member?.email ?? '');\n    const allowedRoles", "    emailController = TextEditingController(text: widget.member?.email ?? '');\n    professionController = TextEditingController(\n      text: widget.member?.profession ?? '',\n    );\n    const allowedRoles")
replace_once(path, "      'admin',\n      'foreman',", "      'admin',\n      'developer',\n      'foreman',")
replace_once(path, "    emailController.dispose();\n    super.dispose();", "    emailController.dispose();\n    professionController.dispose();\n    super.dispose();")
replace_once(path, "    final email = emailController.text.trim();\n", "    final email = emailController.text.trim();\n    final profession = professionController.text.trim();\n")
replace_all(path, "          role: role,\n          objectId:", "          role: role,\n          profession: profession,\n          objectId:", minimum=2)
replace_once(path, "              const SizedBox(height: 12),\n            ] else ...[", "              const SizedBox(height: 12),\n              TextField(\n                controller: professionController,\n                enabled: !isSaving,\n                textInputAction: TextInputAction.next,\n                decoration: const InputDecoration(\n                  labelText: 'Профессия / должность',\n                  prefixIcon: Icon(Icons.work_outline_rounded),\n                ),\n              ),\n              const SizedBox(height: 12),\n            ] else ...[")
replace_once(path, "              const SizedBox(height: 8),\n            ],\n            DropdownButtonFormField<String>(", "              const SizedBox(height: 8),\n              TextField(\n                controller: professionController,\n                enabled: !isSaving,\n                decoration: const InputDecoration(\n                  labelText: 'Профессия / должность',\n                  prefixIcon: Icon(Icons.work_outline_rounded),\n                ),\n              ),\n              const SizedBox(height: 12),\n            ],\n            DropdownButtonFormField<String>(")
replace_once(path, "                DropdownMenuItem(value: 'admin', child: Text('Администратор')),\n                DropdownMenuItem(value: 'foreman', child: Text('Прораб')),", "                DropdownMenuItem(value: 'admin', child: Text('Администратор')),\n                DropdownMenuItem(value: 'developer', child: Text('Разработчик')),\n                DropdownMenuItem(value: 'foreman', child: Text('Прораб')),")
replace_once(path, "      member.roleTitle,\n      if (member.objectName.isNotEmpty)", "      member.roleTitle,\n      if (member.profession.isNotEmpty) member.profession,\n      if (member.objectName.isNotEmpty)")

path = 'lib/features/company/presentation/desktop_company_user_dialogs.dart'
replace_once(path, "  late final TextEditingController emailController;\n  late String role;", "  late final TextEditingController emailController;\n  late final TextEditingController professionController;\n  late String role;")
replace_once(path, "    emailController = TextEditingController(text: widget.member?.email ?? '');\n    const roles", "    emailController = TextEditingController(text: widget.member?.email ?? '');\n    professionController = TextEditingController(\n      text: widget.member?.profession ?? '',\n    );\n    const roles")
replace_once(path, "{'admin', 'foreman', 'lawyer', 'accountant', 'hr'}", "{'admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr'}")
replace_once(path, "    emailController.dispose();\n    super.dispose();", "    emailController.dispose();\n    professionController.dispose();\n    super.dispose();")
replace_once(path, "    final email = emailController.text.trim().toLowerCase();\n", "    final email = emailController.text.trim().toLowerCase();\n    final profession = professionController.text.trim();\n")
replace_all(path, "          role: role,\n          objectId:", "          role: role,\n          profession: profession,\n          objectId:", minimum=2)
replace_once(path, "                    : 'Одна форма для администратора, прораба, юриста, бухгалтера и HR.',", "                    : 'Одна форма для администратора, разработчика, прораба, юриста, бухгалтера и HR.',")
replace_once(path, "                const SizedBox(height: 14),\n              ],\n              Row(", "                const SizedBox(height: 14),\n              ],\n              TextField(\n                controller: professionController,\n                enabled: !isSaving,\n                decoration: const InputDecoration(\n                  labelText: 'Профессия / должность',\n                  prefixIcon: Icon(Icons.work_outline_rounded),\n                ),\n              ),\n              const SizedBox(height: 14),\n              Row(")
replace_once(path, "                        DropdownMenuItem(\n                          value: 'foreman',", "                        DropdownMenuItem(\n                          value: 'developer',\n                          child: Text('Разработчик'),\n                        ),\n                        DropdownMenuItem(\n                          value: 'foreman',")

path = 'lib/features/company/data/company_invitation_repository.dart'
replace_once(path, "  final String role;\n  final String objectId;", "  final String role;\n  final String profession;\n  final String objectId;")
replace_once(path, "    required this.role,\n    required this.objectId,", "    required this.role,\n    required this.profession,\n    required this.objectId,")
replace_once(path, "      case 'admin':\n        return 'Администратор';", "      case 'admin':\n        return 'Администратор';\n      case 'developer':\n        return 'Разработчик';")
replace_once(path, "          'id, company_id, email, role, object_id, invited_user_id, status, expires_at, accepted_at, created_at',", "          'id, company_id, email, role, profession, object_id, invited_user_id, status, expires_at, accepted_at, created_at',")
replace_once(path, ".select('id, full_name')", ".select('id, full_name, profession')")
replace_once(path, "            role: row['role']?.toString() ?? 'foreman',\n            objectId:", "            role: row['role']?.toString() ?? 'foreman',\n            profession: row['profession']?.toString().trim().isNotEmpty == true\n                ? row['profession'].toString().trim()\n                : profile['profession']?.toString() ?? '',\n            objectId:")

path = 'lib/features/company/presentation/desktop_company_management_screen.dart'
replace_once(path, "        role: invitation.role,\n        objectId:", "        role: invitation.role,\n        profession: invitation.profession,\n        objectId:")
replace_once(path, "      case 'owner':\n      case 'admin':\n        return const Color(0xFF4C6076);", "      case 'owner':\n      case 'admin':\n        return const Color(0xFF4C6076);\n      case 'developer':\n        return const Color(0xFF455B75);")
replace_once(path, "        if (member.role == 'admin') return 1;\n        if (member.role == 'foreman') return 2;", "        if (member.role == 'admin') return 1;\n        if (member.role == 'developer') return 2;\n        if (member.role == 'foreman') return 3;")
replace_once(path, "${member.fullName} ${member.email} ${member.roleTitle} ${member.objectName}", "${member.fullName} ${member.email} ${member.roleTitle} ${member.profession} ${member.objectName}")
replace_once(path, "${invitation.fullName} ${invitation.email} ${invitation.roleTitle} ${invitation.objectName} ${invitation.statusTitle}", "${invitation.fullName} ${invitation.email} ${invitation.roleTitle} ${invitation.profession} ${invitation.objectName} ${invitation.statusTitle}")

path = 'supabase/functions/invite-company-member-core/index.ts'
replace_once(path, "    const role = String(input.role ?? \"foreman\").trim();\n    const objectId", "    const role = String(input.role ?? \"foreman\").trim();\n    const profession = String(input.profession ?? \"\").trim();\n    const objectId")
replace_once(path, "new Set([\"admin\", \"foreman\", \"lawyer\", \"accountant\", \"hr\"])", "new Set([\"admin\", \"developer\", \"foreman\", \"lawyer\", \"accountant\", \"hr\"])")
replace_once(path, "               full_name: fullName,\n               invited_company_id:", "               full_name: fullName,\n               profession,\n               invited_company_id:")
replace_once(path, "         full_name: fullName,\n         role,", "         full_name: fullName,\n         role,\n         profession,")
replace_once(path, "           full_name: existingProfile.full_name || fullName,\n           role,", "           full_name: existingProfile.full_name || fullName,\n           role,\n           profession,")
replace_once(path, "         role,\n         object_id: role === \"foreman\" ? objectId : null,", "         role,\n         profession,\n         object_id: role === \"foreman\" ? objectId : null,")

path = 'lib/data/task_repository.dart'
replace_once(path, "import '../models/task_item_data.dart';\n", "import '../features/auth/data/user_repository.dart';\nimport '../features/developer/data/developer_policy_repository.dart';\nimport '../models/task_item_data.dart';\n")
replace_once(path, "  }) async {\n    final row = await _client\n        .from('tasks')", "  }) async {\n    final actorName = await UserRepository.currentActorName();\n    final policy = await DeveloperPolicyRepository.ensurePolicy(objectName);\n    final row = await _client\n        .from('tasks')")
replace_once(path, "          'created_by': 'Илья',", "          'created_by': actorName,")
replace_once(path, "          'photo_requirements_enforced': true,", "          'photo_requirements_enforced': policy.requireBeforePhoto,")
replace_once(path, "  }) async {\n    if (photos.isEmpty) {\n      throw Exception('Добавьте хотя бы одно фото «До»');\n    }\n\n    final createdTask", "  }) async {\n    final policy = await DeveloperPolicyRepository.ensurePolicy(objectName);\n    if (policy.requireBeforePhoto && photos.length < policy.minBeforePhotos) {\n      throw Exception(\n        'Добавьте фото «До»: минимум ${policy.minBeforePhotos}',\n      );\n    }\n\n    final createdTask")

path = 'lib/screens/add_task_screen.dart'
replace_once(path, "import '../features/milestones/presentation/task_milestone_picker.dart';\n", "import '../features/developer/data/developer_policy_repository.dart';\nimport '../features/developer/models/task_policy.dart';\nimport '../features/milestones/presentation/task_milestone_picker.dart';\n")
replace_once(path, "  final String? initialChecklistItemId;\n", "  final String? initialChecklistItemId;\n  final bool allowAnyDate;\n")
replace_once(path, "    this.initialChecklistItemId,\n  });", "    this.initialChecklistItemId,\n    this.allowAnyDate = false,\n  });")
replace_once(path, "  bool isPickingPhotos = false;\n  String? errorText;", "  bool isPickingPhotos = false;\n  bool isLoadingPolicy = true;\n  TaskPolicy policy = TaskPolicy.defaults;\n  String? errorText;")
replace_once(path, "    isGoalTask = selectedMilestoneId?.trim().isNotEmpty == true;\n    loadEmployees();", "    isGoalTask = selectedMilestoneId?.trim().isNotEmpty == true;\n    loadEmployees();\n    loadPolicy();")
replace_once(path, "  Future<void> loadEmployees() async {", "  Future<void> loadPolicy() async {\n    try {\n      final loaded = await DeveloperPolicyRepository.ensurePolicy(\n        widget.objectName,\n      );\n      if (!mounted) return;\n      setState(() {\n        policy = loaded;\n        isLoadingPolicy = false;\n      });\n    } catch (error) {\n      if (!mounted) return;\n      setState(() {\n        isLoadingPolicy = false;\n        errorText = 'Ошибка загрузки ограничений: $error';\n      });\n    }\n  }\n\n  Future<void> loadEmployees() async {")
replace_once(path, "  Future<void> pickDate() async {\n    final pickedDate", "  Future<void> pickDate() async {\n    if (!widget.allowAnyDate) return;\n    final pickedDate")
replace_once(path, "    if (selectedPhotos.isEmpty) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Добавьте хотя бы одно фото «До»')),\n      );\n      return;\n    }", "    if (policy.requireBeforePhoto &&\n        selectedPhotos.length < policy.minBeforePhotos) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text(\n            'Добавьте фото «До»: минимум ${policy.minBeforePhotos}',\n          ),\n        ),\n      );\n      return;\n    }")
replace_once(path, "          const Text(\n            'Фото «До» — обязательно',\n            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),\n          ),", "          Text(\n            policy.requireBeforePhoto\n                ? 'Фото «До» — обязательно'\n                : 'Фото «До» — по желанию',\n            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),\n          ),")
replace_once(path, "          const Text(\n            'Без фото «До» задача не будет создана. Можно прикрепить несколько снимков.',\n          ),", "          Text(\n            policy.requireBeforePhoto\n                ? 'Нужно прикрепить минимум ${policy.minBeforePhotos}. Можно добавить несколько снимков.'\n                : 'На этом объекте задачу можно создать без фотографии.',\n          ),")
replace_once(path, "             onPressed: pickDate,", "             onPressed: widget.allowAnyDate ? pickDate : null,")
replace_once(path, "               onPressed: saveTask,", "               onPressed: isLoadingPolicy ? null : saveTask,")

for path in [
    'lib/screens/mobile_tasks_screen.dart',
    'lib/screens/desktop_tasks_screen.dart',
    'lib/features/foreman/presentation/foreman_desktop_tasks_screen.dart',
]:
    import_marker = "import '../features/tasks/task_edit_policy.dart';\n" if path.startswith('lib/screens/') else "import '../../../features/tasks/task_edit_policy.dart';\n"
    import_new = ("import '../features/developer/data/developer_policy_repository.dart';\n" if path.startswith('lib/screens/') else "import '../../../features/developer/data/developer_policy_repository.dart';\n") + import_marker
    replace_once(path, import_marker, import_new)

path = 'lib/screens/mobile_tasks_screen.dart'
replace_once(path, "    if (!TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)) {", "    await DeveloperPolicyRepository.ensurePolicy(objectName);\n\n    if (!TaskEditPolicy.canCreateForDate(\n      widget.profile,\n      selectedDate,\n      objectName: objectName,\n    )) {")
replace_once(path, "            AddTaskScreen(initialDate: selectedDate, objectName: objectName),", "            AddTaskScreen(\n              initialDate: selectedDate,\n              objectName: objectName,\n              allowAnyDate: widget.profile.isAdmin ||\n                  TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,\n            ),")

path = 'lib/screens/desktop_tasks_screen.dart'
replace_once(path, "    if (!TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)) {", "    await DeveloperPolicyRepository.ensurePolicy(objectName);\n\n    if (!TaskEditPolicy.canCreateForDate(\n      widget.profile,\n      selectedDate,\n      objectName: objectName,\n    )) {")
replace_once(path, "          objectName: objectName,\n        ),", "          objectName: objectName,\n          allowAnyDate: widget.profile.isAdmin ||\n              TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,\n        ),")

path = 'lib/features/foreman/presentation/foreman_desktop_tasks_screen.dart'
replace_once(path, "    if (!TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)) {", "    await DeveloperPolicyRepository.ensurePolicy(objectName);\n\n    if (!TaskEditPolicy.canCreateForDate(\n      widget.profile,\n      selectedDate,\n      objectName: objectName,\n    )) {")
replace_once(path, "          objectName: objectName,\n        ),", "          objectName: objectName,\n          allowAnyDate: TaskEditPolicy.forObject(\n            objectName,\n          ).foremanCanCreateAnyDate,\n        ),")

path = 'lib/screens/task_details_legacy_screen.dart'
replace_once(path, "import '../features/milestones/presentation/task_milestone_picker.dart';\n", "import '../features/developer/data/developer_policy_repository.dart';\nimport '../features/developer/models/task_policy.dart';\nimport '../features/milestones/presentation/task_milestone_picker.dart';\n")
replace_once(path, "  bool isPickingPhotos = false;\n  String? deletingPhotoId;", "  bool isPickingPhotos = false;\n  TaskPolicy policy = TaskPolicy.defaults;\n  String? deletingPhotoId;")
replace_once(path, "  bool get canEdit => TaskEditPolicy.canEditTask(widget.profile, widget.task);", "  bool get canEdit => TaskEditPolicy.canEditTask(widget.profile, widget.task);\n  bool get canEditDate => TaskEditPolicy.canEditDate(widget.profile, widget.task);\n  bool get canEditAxesWork =>\n      TaskEditPolicy.canEditAxesWork(widget.profile, widget.task);\n  bool get canEditAssignees =>\n      TaskEditPolicy.canEditAssignees(widget.profile, widget.task);\n  bool get canEditStatus =>\n      TaskEditPolicy.canEditStatus(widget.profile, widget.task);\n  bool get canDeleteTask =>\n      TaskEditPolicy.canDeleteTask(widget.profile, widget.task);")
replace_once(path, "         TaskRepository.fetchTaskMilestoneLink(taskId),\n       ]);", "         TaskRepository.fetchTaskMilestoneLink(taskId),\n         DeveloperPolicyRepository.ensurePolicy(widget.task.objectName),\n       ]);")
replace_once(path, "       final loadedMilestoneLink = result[3] as TaskMilestoneLinkData?;", "       final loadedMilestoneLink = result[3] as TaskMilestoneLinkData?;\n       final loadedPolicy = result[4] as TaskPolicy;")
replace_once(path, "         isGoalTask = loadedMilestoneLink != null;\n         signedUrlFutures.clear();", "         isGoalTask = loadedMilestoneLink != null;\n         policy = loadedPolicy;\n         signedUrlFutures.clear();")
replace_once(path, "    if (!canEdit) return;\n\n    if (employees.isEmpty)", "    if (!canEditAssignees) return;\n\n    if (employees.isEmpty)")
replace_once(path, "    if (!canEdit || deletingPhotoId != null) return;", "    if (!TaskEditPolicy.canDeletePhoto(\n          widget.profile,\n          widget.task,\n          photo.photoStage,\n        ) ||\n        deletingPhotoId != null) {\n      return;\n    }")
replace_once(path, "    if (selectedStatus == 'Выполнено' &&\n        widget.task.status != 'Выполнено' &&\n        !photos.any((photo) => photo.isAfter)) {", "    final afterCount = photos.where((photo) => photo.isAfter).length;\n    if (policy.requireAfterPhotoOnComplete &&\n        selectedStatus == 'Выполнено' &&\n        widget.task.status != 'Выполнено' &&\n        afterCount < policy.minAfterPhotos) {")
replace_once(path, "        const SnackBar(content: Text('Добавьте хотя бы одно фото «После»')),", "        SnackBar(\n          content: Text(\n            'Добавьте фото «После»: минимум ${policy.minAfterPhotos}',\n          ),\n        ),")
replace_once(path, "    if (selectedStatus != 'Выполнено' &&\n        isPastOrToday &&\n        notDoneComment.isEmpty) {", "    if (policy.requireNotDoneComment &&\n        selectedStatus != 'Выполнено' &&\n        isPastOrToday &&\n        notDoneComment.isEmpty) {")
replace_once(path, "      onTap: isLoading || !canEdit ? null : openAssigneesPicker,", "      onTap: isLoading || !canEditAssignees ? null : openAssigneesPicker,")
replace_once(path, "             if (canEdit)\n               Positioned(", "             if (TaskEditPolicy.canDeletePhoto(\n               widget.profile,\n               widget.task,\n               photo.photoStage,\n             ))\n               Positioned(")
replace_once(path, "             photoStage == 'before'\n                 ? 'Обязательное состояние участка перед началом работ.'\n                 : 'Обязательный результат после завершения работ.',", "             photoStage == 'before'\n                 ? policy.requireBeforePhoto\n                     ? 'Обязательное состояние участка перед началом работ: минимум ${policy.minBeforePhotos}.'\n                     : 'Фотография участка перед началом работ — по желанию.'\n                 : policy.requireAfterPhotoOnComplete\n                     ? 'Обязательный результат после завершения: минимум ${policy.minAfterPhotos}.'\n                     : 'Фотография результата — по желанию.',")
replace_once(path, "           if (widget.profile.isAdmin)\n             IconButton(", "           if (canDeleteTask)\n             IconButton(")
replace_once(path, "             onPressed: isSaving || !widget.profile.isAdmin ? null : pickDate,", "             onPressed: isSaving || !canEditDate ? null : pickDate,")
replace_once(path, "             onChanged: isSaving || !canEdit\n", "             onChanged: isSaving || !canEditStatus\n")
replace_once(path, "                     if (value &&\n                         widget.task.status != 'Выполнено' &&\n                         !photos.any((photo) => photo.isAfter)) {", "                     final afterCount = photos\n                         .where((photo) => photo.isAfter)\n                         .length;\n                     if (value &&\n                         policy.requireAfterPhotoOnComplete &&\n                         widget.task.status != 'Выполнено' &&\n                         afterCount < policy.minAfterPhotos) {")
replace_once(path, "                             'Сначала добавьте хотя бы одно фото «После»',", "                             'Сначала добавьте фото «После»: минимум ${policy.minAfterPhotos}',")
replace_once(path, "               enabled: !isSaving && canEdit,", "               enabled: !isSaving && canEditStatus,")
replace_once(path, "               canSelect: canEdit,", "               canSelect: canEditAxesWork,")
replace_all(path, "             enabled: !isSaving && canEdit,", "             enabled: !isSaving && canEditAxesWork,", minimum=2)
replace_once(path, "             emptyText: 'Обязательное фото «До» пока не прикреплено',", "             emptyText: policy.requireBeforePhoto\n                 ? 'Обязательное фото «До» пока не прикреплено'\n                 : 'Фото «До» не прикреплено',")
replace_once(path, "             emptyText: 'Без фото «После» задачу нельзя выполнить',", "             emptyText: policy.requireAfterPhotoOnComplete\n                 ? 'Без нужного количества фото «После» задачу нельзя выполнить'\n                 : 'Фото «После» не прикреплено',")

print('Developer panel patches applied')

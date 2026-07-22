part of '../employee_details_screen.dart';

extension _EmployeeDetailsSections on _EmployeeDetailsScreenState {
  Widget buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 0,
      color: AppAdaptivePalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right),
        onTap: isLoading ? null : onTap,
      ),
    );
  }

  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final cleanValue = value.trim();
    return Card(
      elevation: 0,
      color: AppAdaptivePalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon),
        title: Text(title),
        subtitle: cleanValue.isEmpty
            ? null
            : Text(cleanValue, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget buildStatusBadge() {
    final isFired = !employee.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isFired
            ? AppAdaptivePalette.disabledSurface
            : AppAdaptivePalette.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isFired ? 'Уволен' : 'Активный',
        style: TextStyle(
          color: isFired
              ? AppAdaptivePalette.disabledText
              : AppAdaptivePalette.success,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildHeader() {
    final isFired = !employee.isActive;
    final comment = employee.comment.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;
        final avatarBlock = Column(
          children: [
            CircleAvatar(
              radius: isMobile ? 58 : 66,
              backgroundColor: isFired
                  ? AppAdaptivePalette.disabledSurface
                  : AppAdaptivePalette.surfaceSoft,
              child: Text(
                firstLetter(employee.name),
                style: TextStyle(
                  fontSize: isMobile ? 42 : 48,
                  fontWeight: FontWeight.w500,
                  color: isFired
                      ? AppAdaptivePalette.disabledText
                      : AppAdaptivePalette.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            buildStatusBadge(),
          ],
        );

        final actionButtons = Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            roundHeaderButton(
              tooltip: 'Редактировать',
              icon: Icons.edit_outlined,
              onPressed: isChangingStatus || isCopyingEmployee
                  ? null
                  : openEditEmployee,
            ),
            if (widget.profile.isAdmin)
              roundHeaderButton(
                tooltip: 'Скопировать в другой объект',
                icon: Icons.content_copy_outlined,
                onPressed: isChangingStatus || isCopyingEmployee
                    ? null
                    : copyEmployeeToOtherObject,
                child: isCopyingEmployee
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            roundHeaderButton(
              tooltip: 'Добавить выплату',
              icon: Icons.add_card_outlined,
              onPressed: isChangingStatus || isCopyingEmployee
                  ? null
                  : openAddPayment,
            ),
            roundHeaderButton(
              tooltip: isFired ? 'Вернуть в активные' : 'Уволить',
              icon: isFired ? Icons.undo : Icons.person_off_outlined,
              onPressed:
                  isChangingStatus || isCopyingEmployee || isArchivingEmployee
                  ? null
                  : toggleFiredStatus,
              child: isChangingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (widget.profile.isAdmin && isFired)
              roundHeaderButton(
                tooltip: 'Архивировать',
                icon: Icons.archive_outlined,
                onPressed:
                    isChangingStatus || isCopyingEmployee || isArchivingEmployee
                    ? null
                    : archiveCurrentEmployee,
                child: isArchivingEmployee
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
          ],
        );

        final infoBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              maxLines: isMobile ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontSize: isMobile ? 28 : 32,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: isFired
                    ? AppAdaptivePalette.disabledText
                    : AppAdaptivePalette.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            buildHeaderInfoLine(
              icon: Icons.badge_outlined,
              title: 'Должность',
              value: employee.position,
            ),
            buildHeaderInfoLine(
              icon: Icons.apartment_outlined,
              title: 'Объект',
              value: employee.objectName,
            ),
            buildHeaderInfoLine(
              icon: Icons.phone_outlined,
              title: 'Телефон',
              value: employee.phone.isEmpty ? 'Не указан' : employee.phone,
            ),
            buildHeaderInfoLine(
              icon: Icons.payments_outlined,
              title: 'Ставка',
              value: formatMoney(employee.dailyRate),
            ),
            buildHeaderInfoLine(
              icon: Icons.notes_outlined,
              title: 'Комментарий',
              value: comment.isEmpty ? 'Нет комментария' : comment,
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppAdaptivePalette.border),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatarBlock,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: actionButtons,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    infoBlock,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatarBlock,
                    const SizedBox(width: 24),
                    Expanded(child: infoBlock),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget roundHeaderButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: child ?? Icon(icon, color: AppAdaptivePalette.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeaderInfoLine({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              title,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

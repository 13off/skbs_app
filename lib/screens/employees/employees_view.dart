part of '../employees_screen.dart';

extension _EmployeesView on _EmployeesScreenState {
  Widget buildEmployeesView() {
    return RepaintBoundary(
      child: PremiumWorkBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: PageStorageKey(
                  'employees-${widget.selectedObjectName ?? 'all'}',
                ),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: content(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

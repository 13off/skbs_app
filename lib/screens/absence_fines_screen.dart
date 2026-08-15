import 'package:flutter/material.dart';

import '../app/app_ui_tokens.dart';
import '../features/payments/presentation/widgets/pending_absence_fines_card.dart';
import '../widgets/premium_ui.dart';

/// Отдельный рабочий экран руководителя для решений по штрафам.
/// Штрафы намеренно не встраиваются поверх экрана выплат: это самостоятельный
/// поток, из которого подтверждённое удержание уже попадает в «Выплаты».
class AbsenceFinesScreen extends StatelessWidget {
  const AbsenceFinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        title: const Text('Штрафы'),
      ),
      body: PremiumWorkBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1120;
            return ListView(
              padding: desktop
                  ? const EdgeInsets.fromLTRB(
                      AppUi.pageDesktopHorizontalPadding,
                      22,
                      AppUi.pageDesktopHorizontalPadding,
                      132,
                    )
                  : const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 1040 : 760,
                    ),
                    child: const PendingAbsenceFinesCard(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

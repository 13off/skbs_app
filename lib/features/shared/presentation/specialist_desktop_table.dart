import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';
import 'specialist_desktop_ui.dart';

class SpecialistTableColumn {
  final String label;
  final int flex;
  final Alignment alignment;

  const SpecialistTableColumn(
    this.label, {
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

class SpecialistTableRowData {
  final List<Widget> cells;
  final VoidCallback? onTap;

  const SpecialistTableRowData({required this.cells, this.onTap});
}

class SpecialistDesktopTable extends StatelessWidget {
  final List<SpecialistTableColumn> columns;
  final List<SpecialistTableRowData> rows;
  final double minWidth;

  const SpecialistDesktopTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 1050,
  });

  Widget cellsRow(List<Widget> cells, {bool header = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List<Widget>.generate(columns.length, (index) {
        final column = columns[index];
        final child = header
            ? Text(
                column.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: specialistMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.55,
                ),
              )
            : cells[index];
        return Expanded(
          flex: column.flex,
          child: Align(alignment: column.alignment, child: child),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(minWidth, constraints.maxWidth).toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
                    child: cellsRow(const <Widget>[], header: true),
                  ),
                  Divider(height: 1, color: specialistLine),
                  ...List<Widget>.generate(rows.length, (index) {
                    final row = rows[index];
                    return Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: row.onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              child: cellsRow(row.cells),
                            ),
                          ),
                        ),
                        if (index != rows.length - 1)
                          Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: specialistLine,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

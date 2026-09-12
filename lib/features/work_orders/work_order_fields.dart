import 'package:flutter/material.dart';

const List<String> workOrderUnits = <String>[
  'м³',
  'м²',
  'т',
  'шт.',
  'м.п.',
  'м',
];

double? parseWorkQuantity(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

bool isValidWorkQuantity(double? value) =>
    value != null && value.isFinite && value > 0 && value <= 1000000000000;

class WorkOrderPlanFields extends StatelessWidget {
  const WorkOrderPlanFields({
    super.key,
    required this.quantityController,
    required this.unit,
    required this.onUnitChanged,
    this.enabled = true,
  });

  final TextEditingController quantityController;
  final String unit;
  final ValueChanged<String?> onUnitChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final quantity = TextField(
      controller: quantityController,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Плановый объём',
        hintText: '0',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    final units = DropdownButtonFormField<String>(
      initialValue: workOrderUnits.contains(unit) ? unit : workOrderUnits.first,
      decoration: InputDecoration(
        labelText: 'Ед. изм.',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final value in workOrderUnits)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: enabled ? onUnitChanged : null,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: quantity),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: units),
      ],
    );
  }
}

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
    required this.withoutVolume,
    required this.onWithoutVolumeChanged,
    this.enabled = true,
  });

  final TextEditingController quantityController;
  final String unit;
  final ValueChanged<String?> onUnitChanged;
  final bool withoutVolume;
  final ValueChanged<bool?> onWithoutVolumeChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final quantity = TextField(
      controller: quantityController,
      enabled: enabled && !withoutVolume,
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
      onChanged: enabled && !withoutVolume ? onUnitChanged : null,
    );
    final checkbox = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => onWithoutVolumeChanged(!withoutVolume) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: withoutVolume,
              onChanged: enabled ? onWithoutVolumeChanged : null,
            ),
            const Text(
              'Без объёма',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
    final fields = Row(
      children: [
        Expanded(flex: 3, child: quantity),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: units),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              Expanded(child: fields),
              const SizedBox(width: 12),
              checkbox,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            checkbox,
            const SizedBox(height: 8),
            fields,
          ],
        );
      },
    );
  }
}

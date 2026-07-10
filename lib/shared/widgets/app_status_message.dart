import 'package:flutter/material.dart';

class AppStatusMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const AppStatusMessage.success({super.key, required this.text})
    : isError = false;

  const AppStatusMessage.error({super.key, required this.text})
    : isError = true;

  @override
  Widget build(BuildContext context) {
    final background = isError ? Colors.red.shade50 : Colors.green.shade50;
    final foreground = isError ? Colors.red.shade900 : Colors.green.shade900;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

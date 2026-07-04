import 'package:flutter/material.dart';

class EmployeeAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const EmployeeAction({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

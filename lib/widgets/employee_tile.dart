import 'package:flutter/material.dart';

import '../models/employee.dart';

class EmployeeTile extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const EmployeeTile({super.key, required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final marked = employee.status == 'работал';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(employee.name[0])),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(employee.position),
        trailing: Text(
          marked ? '✓ работал' : '× не отмечен',
          style: TextStyle(
            color: marked ? Colors.green : Colors.red,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

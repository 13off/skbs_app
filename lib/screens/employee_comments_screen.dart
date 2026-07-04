import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_comments_repository.dart';
import '../models/employee.dart';

class EmployeeCommentsScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeCommentsScreen({super.key, required this.employee});

  @override
  State<EmployeeCommentsScreen> createState() => _EmployeeCommentsScreenState();
}

class _EmployeeCommentsScreenState extends State<EmployeeCommentsScreen> {
  final commentController = TextEditingController();

  List<EmployeeComment> comments = [];

  bool isLoading = false;
  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    loadComments();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  Future<void> loadComments() async {
    final employeeId = widget.employee.id;

    if (employeeId == null) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await EmployeeCommentsRepository.fetchComments(employeeId);

      if (!mounted) return;

      setState(() {
        comments = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки комментариев: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> addComment() async {
    final employeeId = widget.employee.id;
    final text = commentController.text.trim();

    if (employeeId == null) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    if (text.isEmpty) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await EmployeeCommentsRepository.addComment(
        employeeId: employeeId,
        text: text,
      );

      commentController.clear();

      await loadComments();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка сохранения комментария: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildAddCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            controller: commentController,
            enabled: !isSaving,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Новый комментарий',
              hintText: 'Например: документы обещал привезти завтра',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: isSaving ? null : addComment,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_comment_outlined),
              label: const Text('Добавить комментарий'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCommentsList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return const Center(child: Text('Комментариев пока нет'));
    }

    return Column(
      children: comments.map((comment) {
        return Card(
          elevation: 0,
          color: const Color(0xFFFFEEE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.comment_outlined),
            title: Text(comment.text),
            subtitle: Text(
              '${comment.createdBy.isEmpty ? 'Пользователь' : comment.createdBy} • ${formatDate(comment.createdAt)}',
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Комментарии')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('${widget.employee.position} • ${widget.employee.objectName}'),

          const SizedBox(height: 18),

          buildAddCard(),

          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 18),

          buildCommentsList(),
        ],
      ),
    );
  }
}

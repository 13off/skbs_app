import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/employee_comments_repository.dart';
import '../models/employee.dart';
import '../widgets/adaptive_detail_body.dart';

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

  int _loadToken = 0;

  @override
  void initState() {
    super.initState();

    loadComments();
  }

  @override
  void dispose() {
    _loadToken++;
    commentController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  Future<void> loadComments({bool showLoader = true}) async {
    final employeeId = widget.employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    final requestToken = ++_loadToken;

    if (showLoader) {
      setState(() {
        isLoading = true;
        errorText = null;
      });
    } else {
      setState(() {
        errorText = null;
      });
    }

    try {
      final result = await EmployeeCommentsRepository.fetchComments(employeeId);

      if (!mounted || requestToken != _loadToken) return;

      setState(() {
        comments = result;
      });
    } catch (e) {
      if (!mounted || requestToken != _loadToken) return;

      setState(() {
        errorText = 'Ошибка загрузки комментариев: $e';
      });
    } finally {
      if (mounted && requestToken == _loadToken && showLoader) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> addComment() async {
    final employeeId = widget.employee.id;
    final text = commentController.text.trim();

    if (employeeId == null || employeeId.isEmpty) {
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
      final createdComment = await EmployeeCommentsRepository.addComment(
        employeeId: employeeId,
        text: text,
      );

      if (!mounted) return;

      commentController.clear();

      setState(() {
        comments = [createdComment, ...comments];
      });
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: commentController,
            enabled: !isSaving,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Новый комментарий',
              hintText: 'Например: документы обещал привезти завтра',
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: Text(
            'Комментариев пока нет',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: comments.map((comment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppAdaptivePalette.border),
          ),
          child: ListTile(
            leading: Icon(
              Icons.comment_outlined,
              color: AppAdaptivePalette.accent,
            ),
            title: Text(
              comment.text,
              style: TextStyle(color: AppAdaptivePalette.textPrimary),
            ),
            subtitle: Text(
              '${comment.createdBy.isEmpty ? 'Пользователь' : comment.createdBy} • ${formatDate(comment.createdAt)}',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Комментарии'),
      ),
      body: AdaptiveDetailBody(
        onRefresh: () => loadComments(showLoader: false),
        desktopMaxWidth: 1180,
        children: [
          Text(
            widget.employee.name,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final list = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null) ...[
                    Text(
                      errorText!,
                      style: TextStyle(color: AppAdaptivePalette.danger),
                    ),
                    const SizedBox(height: 12),
                  ],
                  buildCommentsList(),
                ],
              );

              if (!desktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [buildAddCard(), const SizedBox(height: 18), list],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 430, child: buildAddCard()),
                  const SizedBox(width: 20),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

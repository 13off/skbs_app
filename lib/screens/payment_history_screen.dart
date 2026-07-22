import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/payment_receipt_repository.dart';
import '../data/payment_repository.dart';
import '../models/employee.dart';
import '../widgets/adaptive_detail_body.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Employee employee;
  final List<String> employeeIds;

  const PaymentHistoryScreen({
    super.key,
    required this.employee,
    this.employeeIds = const [],
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<PaymentRecord> payments = [];
  final Set<String> deletingPaymentIds = {};
  final Set<String> addingReceiptPaymentIds = {};

  bool isLoading = false;
  String? errorText;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();

    loadHistory();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String monthName(int month) {
    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    if (month < 1 || month > 12) return 'Месяц';

    return monthNames[month - 1];
  }

  String periodTitle(PaymentRecord payment) {
    return '${monthName(payment.periodMonth)} ${payment.periodYear}';
  }

  String formatMoney(num value) {
    final text = value.round().toString();

    final formatted = text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$formatted ₽';
  }

  String paymentTypeLabel(String value) {
    switch (value) {
      case 'advance':
        return 'Аванс';
      case 'salary':
        return 'Заработная плата';
      case 'fine':
        return 'Штраф';
      default:
        return 'Другое';
    }
  }

  Color paymentTypeColor(String value) {
    switch (value) {
      case 'fine':
        return AppAdaptivePalette.danger;
      case 'salary':
        return AppAdaptivePalette.success;
      case 'advance':
        return AppAdaptivePalette.warning;
      default:
        return AppAdaptivePalette.textMuted;
    }
  }

  double get totalAmount {
    return payments.fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  List<String> get historyEmployeeIds {
    final ids = widget.employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isNotEmpty) return ids;

    final employeeId = widget.employee.id?.trim();

    if (employeeId == null || employeeId.isEmpty) return <String>[];

    return <String>[employeeId];
  }

  Future<void> loadHistory({bool forceRefresh = false}) async {
    final employeeIds = historyEmployeeIds;

    if (employeeIds.isEmpty) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    final serial = ++_loadSerial;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await PaymentRepository.fetchPaymentsForEmployees(
        employeeIds,
        forceRefresh: forceRefresh,
      );

      if (!mounted || serial != _loadSerial) return;

      setState(() {
        payments = result;
      });
    } catch (e) {
      if (!mounted || serial != _loadSerial) return;

      setState(() {
        errorText = 'Ошибка загрузки истории выплат: $e';
      });
    } finally {
      if (mounted && serial == _loadSerial) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> confirmDeletePayment(PaymentRecord payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить выплату?'),
          content: Text(
            '${paymentTypeLabel(payment.paymentType)} на сумму ${formatMoney(payment.amount)} от ${formatDate(payment.paymentDate)} будет удалена. Чеки этой выплаты тоже удалятся.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await deletePayment(payment);
  }

  Future<void> deletePayment(PaymentRecord payment) async {
    if (payment.id.isEmpty) {
      setState(() {
        errorText = 'Не удалось удалить выплату: нет ID записи';
      });
      return;
    }

    setState(() {
      deletingPaymentIds.add(payment.id);
      errorText = null;
    });

    try {
      await PaymentRepository.deletePayment(
        payment.id,
        employeeId: payment.employeeId,
      );

      if (!mounted) return;

      setState(() {
        payments.removeWhere((item) => item.id == payment.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выплата удалена')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка удаления выплаты: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          deletingPaymentIds.remove(payment.id);
        });
      }
    }
  }

  Future<void> addReceiptsToPayment(PaymentRecord payment) async {
    if (payment.id.isEmpty || payment.employeeId.isEmpty) {
      setState(() {
        errorText = 'Не удалось добавить чек: нет ID выплаты или сотрудника';
      });
      return;
    }

    if (addingReceiptPaymentIds.contains(payment.id)) return;

    setState(() {
      addingReceiptPaymentIds.add(payment.id);
      errorText = null;
    });

    try {
      final pickedFiles = await PaymentReceiptRepository.pickReceiptFiles();

      if (pickedFiles.isEmpty) return;

      final uploadedReceipts = await PaymentRepository.addReceiptsToPayment(
        paymentId: payment.id,
        employeeId: payment.employeeId,
        receiptFiles: pickedFiles,
      );

      if (!mounted) return;

      setState(() {
        payments = payments.map((item) {
          if (item.id != payment.id) return item;

          return item.copyWith(
            receipts: [...item.receipts, ...uploadedReceipts],
          );
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Чеки добавлены: ${uploadedReceipts.length}')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка добавления чека: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          addingReceiptPaymentIds.remove(payment.id);
        });
      }
    }
  }

  Future<void> openReceipt(PaymentReceipt receipt) async {
    try {
      await PaymentReceiptRepository.openReceipt(receipt);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка открытия чека: $e';
      });
    }
  }

  Widget buildEmployeeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Всего по истории: ${formatMoney(totalAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildReceiptsBlock(PaymentRecord payment) {
    final receipts = payment.receipts;
    final isAdding = addingReceiptPaymentIds.contains(payment.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (receipts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                'Чеки: ${receipts.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: receipts.map((receipt) {
              final fileName = receipt.fileName.trim().isEmpty
                  ? 'Чек'
                  : receipt.fileName.trim();

              return OutlinedButton.icon(
                onPressed: () {
                  openReceipt(receipt);
                },
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(fileName, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading || isAdding
                ? null
                : () {
                    addReceiptsToPayment(payment);
                  },
            icon: isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file, size: 18),
            label: Text(
              isAdding
                  ? 'Загрузка...'
                  : receipts.isEmpty
                  ? 'Добавить чек'
                  : 'Добавить ещё чек',
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPaymentCard(PaymentRecord payment) {
    final typeColor = paymentTypeColor(payment.paymentType);
    final comment = payment.comment.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paymentTypeLabel(payment.paymentType),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatMoney(payment.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              deletingPaymentIds.contains(payment.id)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Удалить выплату',
                      onPressed: isLoading
                          ? null
                          : () {
                              confirmDeletePayment(payment);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 6),
              Text(
                formatDate(payment.paymentDate),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.event_note_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  periodTitle(payment),
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          buildReceiptsBlock(payment),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('История выплат'),
      ),
      body: AdaptiveDetailBody(
        onRefresh: () => loadHistory(forceRefresh: true),
        desktopMaxWidth: 1220,
        children: [
          buildEmployeeHeader(),
          const SizedBox(height: 18),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator(),
            ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                errorText!,
                style: TextStyle(color: AppAdaptivePalette.danger),
              ),
            ),
          if (!isLoading && payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'История выплат пустая',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                if (!desktop) {
                  return Column(
                    children: payments.map(buildPaymentCard).toList(),
                  );
                }
                const gap = 14.0;
                final width = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: payments
                      .map(
                        (payment) => SizedBox(
                          width: width,
                          child: buildPaymentCard(payment),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

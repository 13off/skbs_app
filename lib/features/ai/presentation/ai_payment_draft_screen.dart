import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/payment_receipt_repository.dart';
import '../../../data/payment_repository.dart';
import '../models/ai_assistant_result.dart';

class AiPaymentDraftScreen extends StatefulWidget {
  final AiAssistantAction action;

  const AiPaymentDraftScreen({super.key, required this.action});

  @override
  State<AiPaymentDraftScreen> createState() => _AiPaymentDraftScreenState();
}

class _AiPaymentDraftScreenState extends State<AiPaymentDraftScreen> {
  late final TextEditingController amountController;
  late final TextEditingController commentController;
  late DateTime paymentDate;
  late String paymentType;
  final List<PickedPaymentReceiptFile> receipts = [];
  bool saving = false;
  bool picking = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final amount = widget.action.number('amount');
    amountController = TextEditingController(
      text: amount > 0 ? amount.toStringAsFixed(0) : '',
    );
    commentController = TextEditingController(
      text: widget.action.text('comment'),
    );
    paymentDate = widget.action.date('date') ?? DateTime.now();
    final proposedType = widget.action.text('payment_type');
    paymentType = const {'advance', 'salary', 'fine'}.contains(proposedType)
        ? proposedType
        : 'advance';
  }

  @override
  void dispose() {
    amountController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Дата выплаты',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) setState(() => paymentDate = picked);
  }

  Future<void> pickReceipts() async {
    if (picking || saving) return;
    setState(() {
      picking = true;
      errorText = null;
    });
    try {
      final files = await PaymentReceiptRepository.pickReceiptFiles();
      if (!mounted || files.isEmpty) return;
      setState(() => receipts.addAll(files));
    } catch (error) {
      if (mounted) setState(() => errorText = 'Ошибка выбора чека: $error');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving) return;
    final employeeId = widget.action.text('employee_id');
    final amount = double.tryParse(
      amountController.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (employeeId.isEmpty) {
      setState(() => errorText = 'Не найден сотрудник');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => errorText = 'Введите сумму выплаты');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final paymentId = await PaymentRepository.addPayment(
        employeeId: employeeId,
        periodYear: paymentDate.year,
        periodMonth: paymentDate.month,
        paymentDate: paymentDate,
        amount: amount,
        paymentType: paymentType,
        comment: commentController.text.trim(),
        receiptFiles: receipts,
      );
      if (!mounted) return;
      Navigator.pop(context, paymentId ?? 'created');
    } catch (error) {
      if (mounted) setState(() => errorText = 'Ошибка выплаты: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'advance': 'Аванс',
      'salary': 'Заработная плата',
      'fine': 'Штраф',
    };
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Черновик выплаты'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Проверь выплату перед сохранением',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'ИИ ничего не перечисляет. В приложение попадёт только запись, которую ты сохранишь здесь.',
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                widget.action.text('employee_name'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(widget.action.text('object_name')),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: amountController,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Сумма',
              prefixIcon: Icon(Icons.payments_outlined),
              suffixText: '₽',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: paymentType,
            decoration: const InputDecoration(
              labelText: 'Тип выплаты',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: labels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (value) => setState(() => paymentType = value ?? 'advance'),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text(
              'Дата выплаты',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(DateFormat('dd.MM.yyyy').format(paymentDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: saving ? null : pickDate,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: commentController,
            enabled: !saving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Чеки',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    receipts.isEmpty
                        ? 'Чек не прикреплён. Его можно добавить до сохранения.'
                        : 'Прикреплено: ${receipts.length}',
                  ),
                  if (receipts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...receipts.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(entry.value.originalName),
                        trailing: IconButton(
                          tooltip: 'Убрать чек',
                          onPressed: saving
                              ? null
                              : () => setState(
                                  () => receipts.removeAt(entry.key),
                                ),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving || picking ? null : pickReceipts,
                      icon: picking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file),
                      label: Text(
                        picking
                            ? 'Выбираем...'
                            : receipts.isEmpty
                            ? 'Добавить чек'
                            : 'Добавить ещё чек',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(saving ? 'Сохраняем...' : 'Сохранить выплату'),
            ),
          ),
        ],
      ),
    );
  }
}

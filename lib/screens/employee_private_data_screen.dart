import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee_private_data_repository.dart';
import '../data/hr_document_generator.dart';
import '../models/employee.dart';
import '../models/employee_private_data.dart';

class EmployeePrivateDataScreen extends StatefulWidget {
  final Employee employee;

  const EmployeePrivateDataScreen({super.key, required this.employee});

  @override
  State<EmployeePrivateDataScreen> createState() =>
      _EmployeePrivateDataScreenState();
}

class _EmployeePrivateDataScreenState extends State<EmployeePrivateDataScreen> {
  final birthDateController = TextEditingController();
  final birthPlaceController = TextEditingController();
  final phoneController = TextEditingController();
  final passportSeriesController = TextEditingController();
  final passportNumberController = TextEditingController();
  final passportIssuedByController = TextEditingController();
  final passportIssuedDateController = TextEditingController();
  final passportDepartmentCodeController = TextEditingController();
  final snilsController = TextEditingController();
  final innController = TextEditingController();
  final registrationAddressController = TextEditingController();
  final livingAddressController = TextEditingController();
  final clothesSizeController = TextEditingController();
  final shoeSizeController = TextEditingController();
  final bankNameController = TextEditingController();
  final bankCardController = TextEditingController();
  final bankAccountController = TextEditingController();
  final bankBikController = TextEditingController();
  final bankCorrAccountController = TextEditingController();
  final bankInnController = TextEditingController();
  final bankKppController = TextEditingController();
  final bankOkpoController = TextEditingController();
  final bankOgrnController = TextEditingController();
  final bankSwiftController = TextEditingController();
  final bankAddressController = TextEditingController();
  final bankOfficeAddressController = TextEditingController();
  final contractNumberController = TextEditingController();
  final employmentStartDateController = TextEditingController();
  final dismissalDateController = TextEditingController();
  final commentController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? errorText;

  String get employeeId => widget.employee.id ?? '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    birthDateController.dispose();
    birthPlaceController.dispose();
    phoneController.dispose();
    passportSeriesController.dispose();
    passportNumberController.dispose();
    passportIssuedByController.dispose();
    passportIssuedDateController.dispose();
    passportDepartmentCodeController.dispose();
    snilsController.dispose();
    innController.dispose();
    registrationAddressController.dispose();
    livingAddressController.dispose();
    clothesSizeController.dispose();
    shoeSizeController.dispose();
    bankNameController.dispose();
    bankCardController.dispose();
    bankAccountController.dispose();
    bankBikController.dispose();
    bankCorrAccountController.dispose();
    bankInnController.dispose();
    bankKppController.dispose();
    bankOkpoController.dispose();
    bankOgrnController.dispose();
    bankSwiftController.dispose();
    bankAddressController.dispose();
    bankOfficeAddressController.dispose();
    contractNumberController.dispose();
    employmentStartDateController.dispose();
    dismissalDateController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (employeeId.isEmpty) {
      setState(() {
        isLoading = false;
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    try {
      final data = await EmployeePrivateDataRepository.fetchByEmployeeId(
        employeeId,
      );

      fillControllers(data ?? EmployeePrivateData.empty(employeeId));

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorText = 'Ошибка загрузки личных данных: $e';
      });
    }
  }

  void fillControllers(EmployeePrivateData data) {
    birthDateController.text = data.birthDate;
    birthPlaceController.text = data.birthPlace;
    phoneController.text = data.phone.trim().isEmpty
        ? formatRussianPhone(widget.employee.phone)
        : formatRussianPhone(data.phone);
    passportSeriesController.text = data.passportSeries;
    passportNumberController.text = data.passportNumber;
    passportIssuedByController.text = data.passportIssuedBy;
    passportIssuedDateController.text = data.passportIssuedDate;
    passportDepartmentCodeController.text = data.passportDepartmentCode;
    snilsController.text = data.snils;
    innController.text = data.inn;
    registrationAddressController.text = data.registrationAddress;
    livingAddressController.text = data.livingAddress;
    clothesSizeController.text = data.clothesSize;
    shoeSizeController.text = data.shoeSize;
    bankNameController.text = data.bankName;
    bankCardController.text = data.bankCard;
    bankAccountController.text = data.bankAccount;
    bankBikController.text = data.bankBik;
    bankCorrAccountController.text = data.bankCorrAccount;
    bankInnController.text = data.bankInn;
    bankKppController.text = data.bankKpp;
    bankOkpoController.text = data.bankOkpo;
    bankOgrnController.text = data.bankOgrn;
    bankSwiftController.text = data.bankSwift;
    bankAddressController.text = data.bankAddress;
    bankOfficeAddressController.text = data.bankOfficeAddress;
    contractNumberController.text = data.contractNumber;
    employmentStartDateController.text = data.employmentStartDate;
    dismissalDateController.text = data.dismissalDate;
    commentController.text = data.comment;
  }

  EmployeePrivateData dataFromControllers() {
    return EmployeePrivateData(
      employeeId: employeeId,
      birthDate: birthDateController.text.trim(),
      birthPlace: birthPlaceController.text.trim(),
      phone: cleanPhoneForSave(phoneController.text),
      passportSeries: passportSeriesController.text.trim(),
      passportNumber: passportNumberController.text.trim(),
      passportIssuedBy: passportIssuedByController.text.trim(),
      passportIssuedDate: passportIssuedDateController.text.trim(),
      passportDepartmentCode: passportDepartmentCodeController.text.trim(),
      snils: snilsController.text.trim(),
      inn: innController.text.trim(),
      registrationAddress: registrationAddressController.text.trim(),
      livingAddress: livingAddressController.text.trim(),
      clothesSize: clothesSizeController.text.trim(),
      shoeSize: shoeSizeController.text.trim(),
      bankName: bankNameController.text.trim(),
      bankCard: bankCardController.text.trim(),
      bankAccount: bankAccountController.text.trim(),
      bankBik: bankBikController.text.trim(),
      bankCorrAccount: bankCorrAccountController.text.trim(),
      bankInn: bankInnController.text.trim(),
      bankKpp: bankKppController.text.trim(),
      bankOkpo: bankOkpoController.text.trim(),
      bankOgrn: bankOgrnController.text.trim(),
      bankSwift: bankSwiftController.text.trim().toUpperCase(),
      bankAddress: bankAddressController.text.trim(),
      bankOfficeAddress: bankOfficeAddressController.text.trim(),
      contractNumber: contractNumberController.text.trim(),
      employmentStartDate: employmentStartDateController.text.trim(),
      dismissalDate: dismissalDateController.text.trim(),
      comment: commentController.text.trim(),
    );
  }

  String? validateFormats() {
    final checks = <String?>[
      validateExactDigits('Серия паспорта', passportSeriesController.text, 4),
      validateExactDigits('Номер паспорта', passportNumberController.text, 6),
      validateExactDigits('СНИЛС', snilsController.text, 11),
      validateExactDigits('ИНН сотрудника', innController.text, 12),
      validateExactDigits(
        'Код подразделения',
        passportDepartmentCodeController.text,
        6,
      ),
      validatePhone('Телефон', phoneController.text),
      validateExactDigits('БИК', bankBikController.text, 9),
      validateExactDigits('Номер счёта', bankAccountController.text, 20),
      validateExactDigits('Корр. счёт', bankCorrAccountController.text, 20),
      validateExactDigits('ИНН банка', bankInnController.text, 10),
      validateExactDigits('КПП банка', bankKppController.text, 9),
      validateExactDigits('ОГРН банка', bankOgrnController.text, 13),
      validateCard('Номер карты', bankCardController.text),
      validateDate('Дата рождения', birthDateController.text),
      validateDate('Дата выдачи паспорта', passportIssuedDateController.text),
      validateDate('Дата приёма', employmentStartDateController.text),
      validateDate('Дата увольнения', dismissalDateController.text),
    ];

    for (final check in checks) {
      if (check != null) return check;
    }

    return null;
  }

  String? validateExactDigits(String label, String value, int count) {
    final digits = onlyDigits(value);

    if (digits.isEmpty) return null;

    if (digits.length != count) {
      return '$label: должно быть $count цифр';
    }

    return null;
  }

  String? validatePhone(String label, String value) {
    final digits = onlyDigits(value);

    if (digits.length <= 1) return null;

    if (digits.length != 11) {
      return '$label: формат должен быть +7 (999) 999-99-99';
    }

    if (!digits.startsWith('7')) {
      return '$label: должен начинаться с +7';
    }

    return null;
  }

  String? validateCard(String label, String value) {
    final digits = onlyDigits(value);

    if (digits.isEmpty) return null;

    if (digits.length < 16 || digits.length > 19) {
      return '$label: должно быть от 16 до 19 цифр';
    }

    return null;
  }

  String? validateDate(String label, String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    final regex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');

    if (!regex.hasMatch(text)) {
      return '$label: формат должен быть ДД.ММ.ГГГГ';
    }

    final day = int.tryParse(text.substring(0, 2));
    final month = int.tryParse(text.substring(3, 5));
    final year = int.tryParse(text.substring(6, 10));

    if (day == null || month == null || year == null) {
      return '$label: неверная дата';
    }

    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
      return '$label: неверная дата';
    }

    return null;
  }

  Future<EmployeePrivateData?> saveData({bool showMessage = true}) async {
    if (employeeId.isEmpty) return null;

    final formatError = validateFormats();

    if (formatError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatError)));
      return null;
    }

    final data = dataFromControllers();

    setState(() {
      isSaving = true;
    });

    try {
      await EmployeePrivateDataRepository.upsert(data);

      if (!mounted) return data;

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Личные данные сохранены')),
        );
      }

      return data;
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));

      return null;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> downloadDocument(HrDocumentTemplate template) async {
    final data = await saveData(showMessage: false);
    if (data == null) return;

    try {
      await HrDocumentGenerator.downloadDocument(
        template: template,
        employee: widget.employee,
        privateData: data,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${template.title} скачан')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка документа: $e')));
    }
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget buildDocumentButton(HrDocumentTemplate template) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.tonalIcon(
        onPressed: isSaving ? null : () => downloadDocument(template),
        icon: const Icon(Icons.description_outlined),
        label: Text(template.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digitKeyboard = TextInputType.number;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Личные данные')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(widget.employee.position),

          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],

          buildSectionTitle('Кадровые документы'),
          Wrap(
            spacing: 10,
            runSpacing: 0,
            children: HrDocumentGenerator.templates
                .map(buildDocumentButton)
                .toList(),
          ),

          buildSectionTitle('Даты и договор'),
          buildField('Номер трудового договора', contractNumberController),
          buildField(
            'Дата приёма / начала работы',
            employmentStartDateController,
            hint: 'ДД.ММ.ГГГГ',
            keyboardType: digitKeyboard,
            inputFormatters: [DateTextInputFormatter()],
          ),
          buildField(
            'Дата увольнения',
            dismissalDateController,
            hint: 'ДД.ММ.ГГГГ',
            keyboardType: digitKeyboard,
            inputFormatters: [DateTextInputFormatter()],
          ),

          buildSectionTitle('Основные личные данные'),
          buildField(
            'Дата рождения',
            birthDateController,
            hint: 'ДД.ММ.ГГГГ',
            keyboardType: digitKeyboard,
            inputFormatters: [DateTextInputFormatter()],
          ),
          buildField('Место рождения', birthPlaceController),
          buildField(
            'Телефон для кадровых документов',
            phoneController,
            hint: '+7 (999) 999-99-99',
            keyboardType: TextInputType.phone,
            inputFormatters: [RussianPhoneTextInputFormatter()],
          ),

          buildSectionTitle('Паспорт'),
          buildField(
            'Серия паспорта',
            passportSeriesController,
            hint: '0000',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 4)],
          ),
          buildField(
            'Номер паспорта',
            passportNumberController,
            hint: '000000',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 6)],
          ),
          buildField('Кем выдан', passportIssuedByController, maxLines: 3),
          buildField(
            'Дата выдачи',
            passportIssuedDateController,
            hint: 'ДД.ММ.ГГГГ',
            keyboardType: digitKeyboard,
            inputFormatters: [DateTextInputFormatter()],
          ),
          buildField(
            'Код подразделения',
            passportDepartmentCodeController,
            hint: '000-000',
            keyboardType: digitKeyboard,
            inputFormatters: [DepartmentCodeTextInputFormatter()],
          ),

          buildSectionTitle('СНИЛС и ИНН'),
          buildField(
            'СНИЛС',
            snilsController,
            hint: '000-000-000 00',
            keyboardType: digitKeyboard,
            inputFormatters: [SnilsTextInputFormatter()],
          ),
          buildField(
            'ИНН',
            innController,
            hint: '000000000000',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 12)],
          ),

          buildSectionTitle('Адреса'),
          buildField(
            'Адрес регистрации',
            registrationAddressController,
            maxLines: 3,
          ),
          buildField('Адрес проживания', livingAddressController, maxLines: 3),

          buildSectionTitle('Размеры'),
          buildField('Размер одежды', clothesSizeController),
          buildField(
            'Размер обуви',
            shoeSizeController,
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 2)],
          ),

          buildSectionTitle('Банковские реквизиты'),
          buildField('Банк получателя', bankNameController),
          buildField(
            'Номер карты',
            bankCardController,
            hint: '0000 0000 0000 0000',
            keyboardType: digitKeyboard,
            inputFormatters: [BankCardTextInputFormatter()],
          ),
          buildField(
            'Номер счёта',
            bankAccountController,
            hint: '20 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 20)],
          ),
          buildField(
            'БИК',
            bankBikController,
            hint: '9 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 9)],
          ),
          buildField(
            'Корр. счёт',
            bankCorrAccountController,
            hint: '20 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 20)],
          ),
          buildField(
            'ИНН банка',
            bankInnController,
            hint: '10 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 10)],
          ),
          buildField(
            'КПП банка',
            bankKppController,
            hint: '9 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 9)],
          ),
          buildField(
            'ОКПО банка',
            bankOkpoController,
            hint: '8 или 10 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 10)],
          ),
          buildField(
            'ОГРН банка',
            bankOgrnController,
            hint: '13 цифр',
            keyboardType: digitKeyboard,
            inputFormatters: [DigitsOnlyTextInputFormatter(maxDigits: 13)],
          ),
          buildField(
            'SWIFT-код',
            bankSwiftController,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(11),
              UpperCaseTextInputFormatter(),
            ],
          ),
          buildField(
            'Почтовый адрес банка',
            bankAddressController,
            maxLines: 2,
          ),
          buildField(
            'Почтовый адрес доп. офиса',
            bankOfficeAddressController,
            maxLines: 2,
          ),

          buildSectionTitle('Комментарий'),
          buildField('Комментарий', commentController, maxLines: 4),

          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSaving ? null : () => saveData(),
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                isSaving ? 'Сохраняем...' : 'Сохранить личные данные',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String onlyDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String cleanPhoneForSave(String value) {
  final digits = onlyDigits(value);

  if (digits.length <= 1) {
    return '';
  }

  if (digits.length == 11 && digits.startsWith('8')) {
    return formatRussianPhone('7${digits.substring(1)}');
  }

  if (digits.length == 10) {
    return formatRussianPhone('7$digits');
  }

  return formatRussianPhone(digits);
}

String formatRussianPhone(String value) {
  var digits = onlyDigits(value);

  if (digits.isEmpty) {
    return '+7 ';
  }

  if (digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }

  if (!digits.startsWith('7')) {
    digits = '7$digits';
  }

  if (digits.length > 11) {
    digits = digits.substring(0, 11);
  }

  final local = digits.length > 1 ? digits.substring(1) : '';
  final buffer = StringBuffer('+7');

  if (local.isEmpty) {
    buffer.write(' ');
    return buffer.toString();
  }

  buffer.write(' ');

  if (local.isNotEmpty) {
    final end = local.length >= 3 ? 3 : local.length;
    buffer.write('(');
    buffer.write(local.substring(0, end));

    if (local.length >= 3) {
      buffer.write(')');
    }
  }

  if (local.length > 3) {
    final end = local.length >= 6 ? 6 : local.length;
    buffer.write(' ');
    buffer.write(local.substring(3, end));
  }

  if (local.length > 6) {
    final end = local.length >= 8 ? 8 : local.length;
    buffer.write('-');
    buffer.write(local.substring(6, end));
  }

  if (local.length > 8) {
    final end = local.length >= 10 ? 10 : local.length;
    buffer.write('-');
    buffer.write(local.substring(8, end));
  }

  return buffer.toString();
}

class RussianPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatRussianPhone(newValue.text);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class DigitsOnlyTextInputFormatter extends TextInputFormatter {
  final int maxDigits;

  DigitsOnlyTextInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = onlyDigits(newValue.text);

    final limitedDigits = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;

    return TextEditingValue(
      text: limitedDigits,
      selection: TextSelection.collapsed(offset: limitedDigits.length),
    );
  }
}

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = onlyDigits(newValue.text);

    final limitedDigits = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < limitedDigits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('.');
      }

      buffer.write(limitedDigits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class DepartmentCodeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = onlyDigits(newValue.text);

    final limitedDigits = digits.length > 6 ? digits.substring(0, 6) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < limitedDigits.length; i++) {
      if (i == 3) {
        buffer.write('-');
      }

      buffer.write(limitedDigits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class SnilsTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = onlyDigits(newValue.text);

    final limitedDigits = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < limitedDigits.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('-');
      }

      if (i == 9) {
        buffer.write(' ');
      }

      buffer.write(limitedDigits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class BankCardTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = onlyDigits(newValue.text);

    final limitedDigits = digits.length > 19 ? digits.substring(0, 19) : digits;
    final groups = <String>[];

    for (var i = 0; i < limitedDigits.length; i += 4) {
      final end = i + 4 > limitedDigits.length ? limitedDigits.length : i + 4;
      groups.add(limitedDigits.substring(i, end));
    }

    final text = groups.join(' ');

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class UpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

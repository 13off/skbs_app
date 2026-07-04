class EmployeePrivateData {
  final String employeeId;
  final String phone;
  final String birthDate;
  final String birthPlace;
  final String passportSeries;
  final String passportNumber;
  final String passportIssuedBy;
  final String passportIssuedDate;
  final String passportDepartmentCode;
  final String snils;
  final String inn;
  final String registrationAddress;
  final String livingAddress;
  final String clothesSize;
  final String shoeSize;
  final String bankName;
  final String bankCard;
  final String bankAccount;
  final String bankBik;
  final String bankCorrAccount;
  final String bankInn;
  final String bankKpp;
  final String bankOkpo;
  final String bankOgrn;
  final String bankSwift;
  final String bankAddress;
  final String bankOfficeAddress;
  final String contractNumber;
  final String employmentStartDate;
  final String dismissalDate;
  final String comment;

  const EmployeePrivateData({
    required this.employeeId,
    this.phone = '',
    this.birthDate = '',
    this.birthPlace = '',
    this.passportSeries = '',
    this.passportNumber = '',
    this.passportIssuedBy = '',
    this.passportIssuedDate = '',
    this.passportDepartmentCode = '',
    this.snils = '',
    this.inn = '',
    this.registrationAddress = '',
    this.livingAddress = '',
    this.clothesSize = '',
    this.shoeSize = '',
    this.bankName = '',
    this.bankCard = '',
    this.bankAccount = '',
    this.bankBik = '',
    this.bankCorrAccount = '',
    this.bankInn = '',
    this.bankKpp = '',
    this.bankOkpo = '',
    this.bankOgrn = '',
    this.bankSwift = '',
    this.bankAddress = '',
    this.bankOfficeAddress = '',
    this.contractNumber = '',
    this.employmentStartDate = '',
    this.dismissalDate = '',
    this.comment = '',
  });

  factory EmployeePrivateData.empty(String employeeId) {
    return EmployeePrivateData(employeeId: employeeId);
  }

  factory EmployeePrivateData.fromMap(Map<String, dynamic> map) {
    return EmployeePrivateData(
      employeeId: map['employee_id']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      birthDate: map['birth_date']?.toString() ?? '',
      birthPlace: map['birth_place']?.toString() ?? '',
      passportSeries: map['passport_series']?.toString() ?? '',
      passportNumber: map['passport_number']?.toString() ?? '',
      passportIssuedBy: map['passport_issued_by']?.toString() ?? '',
      passportIssuedDate: map['passport_issued_date']?.toString() ?? '',
      passportDepartmentCode: map['passport_department_code']?.toString() ?? '',
      snils: map['snils']?.toString() ?? '',
      inn: map['inn']?.toString() ?? '',
      registrationAddress: map['registration_address']?.toString() ?? '',
      livingAddress: map['living_address']?.toString() ?? '',
      clothesSize: map['clothes_size']?.toString() ?? '',
      shoeSize: map['shoe_size']?.toString() ?? '',
      bankName: map['bank_name']?.toString() ?? '',
      bankCard: map['bank_card']?.toString() ?? '',
      bankAccount: map['bank_account']?.toString() ?? '',
      bankBik: map['bank_bik']?.toString() ?? '',
      bankCorrAccount: map['bank_corr_account']?.toString() ?? '',
      bankInn: map['bank_inn']?.toString() ?? '',
      bankKpp: map['bank_kpp']?.toString() ?? '',
      bankOkpo: map['bank_okpo']?.toString() ?? '',
      bankOgrn: map['bank_ogrn']?.toString() ?? '',
      bankSwift: map['bank_swift']?.toString() ?? '',
      bankAddress: map['bank_address']?.toString() ?? '',
      bankOfficeAddress: map['bank_office_address']?.toString() ?? '',
      contractNumber: map['contract_number']?.toString() ?? '',
      employmentStartDate: map['employment_start_date']?.toString() ?? '',
      dismissalDate: map['dismissal_date']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'employee_id': employeeId,
      'phone': phone.trim(),
      'birth_date': birthDate.trim(),
      'birth_place': birthPlace.trim(),
      'passport_series': passportSeries.trim(),
      'passport_number': passportNumber.trim(),
      'passport_issued_by': passportIssuedBy.trim(),
      'passport_issued_date': passportIssuedDate.trim(),
      'passport_department_code': passportDepartmentCode.trim(),
      'snils': snils.trim(),
      'inn': inn.trim(),
      'registration_address': registrationAddress.trim(),
      'living_address': livingAddress.trim(),
      'clothes_size': clothesSize.trim(),
      'shoe_size': shoeSize.trim(),
      'bank_name': bankName.trim(),
      'bank_card': bankCard.trim(),
      'bank_account': bankAccount.trim(),
      'bank_bik': bankBik.trim(),
      'bank_corr_account': bankCorrAccount.trim(),
      'bank_inn': bankInn.trim(),
      'bank_kpp': bankKpp.trim(),
      'bank_okpo': bankOkpo.trim(),
      'bank_ogrn': bankOgrn.trim(),
      'bank_swift': bankSwift.trim(),
      'bank_address': bankAddress.trim(),
      'bank_office_address': bankOfficeAddress.trim(),
      'contract_number': contractNumber.trim(),
      'employment_start_date': employmentStartDate.trim(),
      'dismissal_date': dismissalDate.trim(),
      'comment': comment.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String get passportFull {
    final parts = [
      passportSeries.trim(),
      passportNumber.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.join(' ');
  }
}

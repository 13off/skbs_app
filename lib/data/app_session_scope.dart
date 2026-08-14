class AppSessionScope {
  AppSessionScope._();

  static String _userId = '';
  static String _companyId = '';
  static int _generation = 0;

  static String get userId => _userId;
  static String get companyId => _companyId;
  static int get generation => _generation;

  static String get cachePrefix =>
      '$_generation::${_userId.isEmpty ? '__guest__' : _userId}::'
      '${_companyId.isEmpty ? '__no_company__' : _companyId}';

  static bool configure({required String userId, required String companyId}) {
    final cleanUserId = userId.trim();
    final cleanCompanyId = companyId.trim();
    if (_userId == cleanUserId && _companyId == cleanCompanyId) return false;

    _userId = cleanUserId;
    _companyId = cleanCompanyId;
    _generation++;
    return true;
  }

  static void reset() {
    if (_userId.isEmpty && _companyId.isEmpty) return;
    _userId = '';
    _companyId = '';
    _generation++;
  }

  static String cacheKey(String key) => '$cachePrefix::$key';

  static bool isCurrent(int generation) => generation == _generation;
}

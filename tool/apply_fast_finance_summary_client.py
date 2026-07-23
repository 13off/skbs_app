from pathlib import Path
import re

path = Path('lib/data/finance_summary_repository.dart')
text = path.read_text(encoding='utf-8')

text = text.replace("import 'dart:math' as math;\n\n", '')
text = text.replace("import '../models/employee.dart';\n", '')
text = text.replace("import 'employee_repository.dart';\n", '')
text = text.replace("import 'object_repository.dart';\n", '')
text = text.replace('  static const int _employeeChunkSize = 80;\n\n', '')

helpers_pattern = re.compile(
    r"  static DateTime _firstDateOfMonth\(FinancePeriod period\) \{.*?\n"
    r"  static Future<FinanceSummaryData> fetchSummary\(",
    re.DOTALL,
)
helpers_replacement = "  static Future<FinanceSummaryData> fetchSummary("
text, helper_count = helpers_pattern.subn(helpers_replacement, text, count=1)
if helper_count != 1:
    raise SystemExit('finance helper anchor not found')

loader_pattern = re.compile(
    r"  static Future<FinanceSummaryData> _loadSummary\(\{.*?\n  \}\n\}",
    re.DOTALL,
)
loader_replacement = """  static Future<FinanceSummaryData> _loadSummary({
    required FinancePeriod period,
    String? objectName,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_finance_summary_fast',
      params: <String, dynamic>{
        'p_year': period.year,
        'p_month': period.month,
        'p_object_name': _cleanObjectName(objectName),
      },
    );
    if (response is! List || response.isEmpty) {
      return FinanceSummaryData.empty;
    }

    final row = Map<String, dynamic>.from(response.first as Map);
    return FinanceSummaryData(
      accrued: _toDouble(row['accrued']),
      paid: _toDouble(row['paid']),
    );
  }
}"""
text, loader_count = loader_pattern.subn(loader_replacement, text, count=1)
if loader_count != 1:
    raise SystemExit('finance loader anchor not found')

path.write_text(text, encoding='utf-8')

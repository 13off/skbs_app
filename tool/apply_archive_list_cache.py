from pathlib import Path

object_path = Path('lib/data/object_repository.dart')
objects = object_path.read_text(encoding='utf-8')

old_fields = '''  static List<ConstructionObject>? _cachedObjects;
  static DateTime? _cachedObjectsAt;
  static Future<List<ConstructionObject>>? _objectsInFlight;
  static int _cacheGeneration = 0;'''
new_fields = '''  static List<ConstructionObject>? _cachedObjects;
  static DateTime? _cachedObjectsAt;
  static Future<List<ConstructionObject>>? _objectsInFlight;
  static List<String>? _cachedArchivedObjectNames;
  static DateTime? _cachedArchivedObjectsAt;
  static Future<List<String>>? _archivedObjectsInFlight;
  static int _cacheGeneration = 0;'''
if objects.count(old_fields) != 1:
    raise SystemExit('object cache fields anchor not found')
objects = objects.replace(old_fields, new_fields, 1)

old_clear = '''    _cachedObjects = null;
    _cachedObjectsAt = null;
    _objectsInFlight = null;
    _cacheGeneration++;'''
new_clear = '''    _cachedObjects = null;
    _cachedObjectsAt = null;
    _objectsInFlight = null;
    _cachedArchivedObjectNames = null;
    _cachedArchivedObjectsAt = null;
    _archivedObjectsInFlight = null;
    _cacheGeneration++;'''
if objects.count(old_clear) != 1:
    raise SystemExit('object clear cache anchor not found')
objects = objects.replace(old_clear, new_clear, 1)

old_archive = '''  static Future<List<String>> fetchArchivedObjectNames({
    bool forceRefresh = false,
  }) async {
    final rows = await _client
        .from('objects')
        .select('name')
        .eq('is_active', false)
        .order('name', ascending: true);

    return rows
        .map<String>((row) => row['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }'''
new_archive = '''  static Future<List<String>> fetchArchivedObjectNames({
    bool forceRefresh = false,
  }) async {
    final cachedAt = _cachedArchivedObjectsAt;
    if (!forceRefresh &&
        _cachedArchivedObjectNames != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _objectsCacheTtl) {
      return List<String>.from(_cachedArchivedObjectNames!);
    }

    final running = _archivedObjectsInFlight;
    if (running != null) return List<String>.from(await running);

    final generation = _cacheGeneration;
    final request = _loadArchivedObjectNames();
    _archivedObjectsInFlight = request;
    try {
      final result = await request;
      if (generation == _cacheGeneration) {
        _cachedArchivedObjectNames = List<String>.from(result);
        _cachedArchivedObjectsAt = DateTime.now();
      }
      return List<String>.from(result);
    } finally {
      if (identical(_archivedObjectsInFlight, request)) {
        _archivedObjectsInFlight = null;
      }
    }
  }

  static Future<List<String>> _loadArchivedObjectNames() async {
    final rows = await _client
        .from('objects')
        .select('name')
        .eq('is_active', false)
        .order('name', ascending: true);

    return rows
        .map<String>((row) => row['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }'''
if objects.count(old_archive) != 1:
    raise SystemExit('archived object loader anchor not found')
objects = objects.replace(old_archive, new_archive, 1)
object_path.write_text(objects, encoding='utf-8')

permanent_path = Path('lib/data/permanent_deletion_repository.dart')
permanent = permanent_path.read_text(encoding='utf-8')
old_import = "import 'employee_repository.dart';\n"
new_import = "import 'employee_archive_repository.dart';\nimport 'employee_repository.dart';\n"
if permanent.count(old_import) != 1:
    raise SystemExit('permanent deletion import anchor not found')
permanent = permanent.replace(old_import, new_import, 1)
old_clear_permanent = '''  static void _clearCaches() {
    EmployeeRepository.clearCache();
    ObjectRepository.clearCache();'''
new_clear_permanent = '''  static void _clearCaches() {
    EmployeeArchiveRepository.clearCache();
    EmployeeRepository.clearCache();
    ObjectRepository.clearCache();'''
if permanent.count(old_clear_permanent) != 1:
    raise SystemExit('permanent deletion cache anchor not found')
permanent = permanent.replace(old_clear_permanent, new_clear_permanent, 1)
permanent_path.write_text(permanent, encoding='utf-8')

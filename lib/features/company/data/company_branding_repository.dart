import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyBranding {
  final String companyId;
  final String name;
  final String? logoPath;
  final DateTime? updatedAt;

  const CompanyBranding({
    required this.companyId,
    required this.name,
    required this.logoPath,
    required this.updatedAt,
  });

  bool get hasLogo => logoPath != null && logoPath!.trim().isNotEmpty;
}

class CompanyBrandingRepository {
  CompanyBrandingRepository._();

  static const bucket = 'company-branding';
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<CompanyBranding> fetch(String companyId) async {
    final row = await _client
        .from('companies')
        .select('id,name,logo_path,updated_at')
        .eq('id', companyId)
        .single();

    return CompanyBranding(
      companyId: row['id']?.toString() ?? companyId,
      name: row['name']?.toString().trim().isNotEmpty == true
          ? row['name'].toString().trim()
          : 'Компания',
      logoPath: _nullableText(row['logo_path']),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  static String? publicLogoUrl(CompanyBranding branding) {
    final path = branding.logoPath?.trim() ?? '';
    if (path.isEmpty) return null;
    final raw = _client.storage.from(bucket).getPublicUrl(path);
    final version = branding.updatedAt?.millisecondsSinceEpoch;
    if (version == null) return raw;
    return '$raw?v=$version';
  }

  static Future<CompanyBranding> updateName({
    required String companyId,
    required String name,
  }) async {
    final normalized = name.trim();
    if (normalized.length < 2) {
      throw Exception('Название компании слишком короткое');
    }
    if (normalized.length > 120) {
      throw Exception('Название компании слишком длинное');
    }

    await _client.from('companies').update(<String, dynamic>{
      'name': normalized,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', companyId);
    return fetch(companyId);
  }

  static Future<CompanyBranding> uploadLogo({
    required String companyId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw Exception('Файл логотипа пустой');
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('Логотип должен быть не больше 5 МБ');
    }
    if (!const <String>{'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
      throw Exception('Поддерживаются JPG, PNG и WEBP');
    }

    final path = '$companyId/logo';
    await _client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        cacheControl: '300',
        contentType: contentType,
      ),
    );
    await _client.from('companies').update(<String, dynamic>{
      'logo_path': path,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', companyId);
    return fetch(companyId);
  }

  static Future<CompanyBranding> removeLogo(String companyId) async {
    final current = await fetch(companyId);
    final path = current.logoPath?.trim() ?? '';
    if (path.isNotEmpty) {
      try {
        await _client.storage.from(bucket).remove(<String>[path]);
      } catch (_) {
        // Карточку компании всё равно очищаем, даже если файл уже отсутствует.
      }
    }
    await _client.from('companies').update(<String, dynamic>{
      'logo_path': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', companyId);
    return fetch(companyId);
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

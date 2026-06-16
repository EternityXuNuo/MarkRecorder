import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../models/template.dart';
import '../models/tombstone.dart';

/// 本地优先存储。
/// 原生平台（Android/iOS/Windows）以 JSON 文件形式保存在应用文档目录：
///   - template.json  当前模板
///   - data.json      学年与活动记录
///   - attachments/   附件文件
/// Web 平台没有文件系统访问，改用 SharedPreferences 保存 JSON 字符串（用于预览）。
class StorageService {
  static const _kTemplate = 'storage_template_json';
  static const _kData = 'storage_data_json';

  Directory? _baseDir;

  Future<Directory> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'mark_recoder'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _baseDir = dir;
    return dir;
  }

  Future<File> _file(String name) async =>
      File(p.join((await baseDir).path, name));

  Future<Directory> attachmentsDir() async {
    final dir = Directory(p.join((await baseDir).path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ---- 底层读写（按平台分流）----
  Future<String?> _read(String fileName, String webKey) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(webKey);
    }
    final f = await _file(fileName);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  Future<void> _write(String fileName, String webKey, String content) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(webKey, content);
      return;
    }
    final f = await _file(fileName);
    await f.writeAsString(content);
  }

  // ---- 模板 ----
  Future<Template?> loadTemplate() async {
    final raw = await _read('template.json', _kTemplate);
    if (raw == null) return null;
    try {
      return Template.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTemplate(Template template) async {
    await _write('template.json', _kTemplate,
        const JsonEncoder.withIndent('  ').convert(template.toJson()));
  }

  // ---- 数据（学年 + 记录 + 删除墓碑）----
  Future<DataBundle> loadData() async {
    final raw = await _read('data.json', _kData);
    if (raw == null) return const DataBundle.empty();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DataBundle.fromJson(json);
    } catch (_) {
      return const DataBundle.empty();
    }
  }

  Future<void> saveData(
    List<AcademicYear> years,
    List<ActivityRecord> records, {
    List<Tombstone> deletedYears = const [],
    List<Tombstone> deletedRecords = const [],
  }) async {
    final json = {
      'years': years.map((e) => e.toJson()).toList(),
      'records': records.map((e) => e.toJson()).toList(),
      'deletedYears': deletedYears.map((e) => e.toJson()).toList(),
      'deletedRecords': deletedRecords.map((e) => e.toJson()).toList(),
    };
    await _write(
        'data.json', _kData, const JsonEncoder.withIndent('  ').convert(json));
  }

  /// 导出全部数据（模板 + 数据 + 墓碑）为单个 JSON 字符串。
  Future<String> exportAllJson() async {
    final template = await loadTemplate();
    final data = await loadData();
    return const JsonEncoder.withIndent('  ').convert({
      'template': template?.toJson(),
      'years': data.years.map((e) => e.toJson()).toList(),
      'records': data.records.map((e) => e.toJson()).toList(),
      'deletedYears': data.deletedYears.map((e) => e.toJson()).toList(),
      'deletedRecords': data.deletedRecords.map((e) => e.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }
}

/// 从 data.json 读出的数据包：学年、记录与删除墓碑。
class DataBundle {
  final List<AcademicYear> years;
  final List<ActivityRecord> records;
  final List<Tombstone> deletedYears;
  final List<Tombstone> deletedRecords;

  const DataBundle({
    required this.years,
    required this.records,
    required this.deletedYears,
    required this.deletedRecords,
  });

  const DataBundle.empty()
      : years = const [],
        records = const [],
        deletedYears = const [],
        deletedRecords = const [];

  factory DataBundle.fromJson(Map<String, dynamic> json) => DataBundle(
        years: (json['years'] as List<dynamic>? ?? [])
            .map((e) => AcademicYear.fromJson(e as Map<String, dynamic>))
            .toList(),
        records: (json['records'] as List<dynamic>? ?? [])
            .map((e) => ActivityRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        deletedYears: (json['deletedYears'] as List<dynamic>? ?? [])
            .map((e) => Tombstone.fromJson(e as Map<String, dynamic>))
            .toList(),
        deletedRecords: (json['deletedRecords'] as List<dynamic>? ?? [])
            .map((e) => Tombstone.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

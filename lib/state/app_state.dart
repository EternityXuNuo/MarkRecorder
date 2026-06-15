import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../models/template.dart';
import '../services/default_template.dart';
import '../services/scoring.dart';
import '../services/storage_service.dart';

/// 应用核心状态：模板、学年、活动记录。负责持久化与计分。
class AppState extends ChangeNotifier {
  AppState(this._storage);

  final StorageService _storage;
  final _uuid = const Uuid();

  Template _template = buildDefaultTemplate();
  List<AcademicYear> _years = [];
  List<ActivityRecord> _records = [];
  bool _loaded = false;

  /// 当前默认学年 id（记录默认添加到此学年）。
  String? _currentYearId;

  Template get template => _template;
  bool get loaded => _loaded;
  Scoring get scoring => Scoring(_template);

  List<AcademicYear> get activeYears =>
      (_years.where((y) => !y.archived).toList())
        ..sort((a, b) => b.order.compareTo(a.order));

  List<AcademicYear> get archivedYears =>
      (_years.where((y) => y.archived).toList())
        ..sort((a, b) => b.order.compareTo(a.order));

  String? get currentYearId =>
      _currentYearId ?? (activeYears.isNotEmpty ? activeYears.first.id : null);

  set currentYearId(String? id) {
    _currentYearId = id;
    notifyListeners();
  }

  AcademicYear? yearById(String id) {
    for (final y in _years) {
      if (y.id == id) return y;
    }
    return null;
  }

  // ---- 加载 / 保存 ----
  Future<void> load() async {
    final t = await _storage.loadTemplate();
    if (t != null) {
      _template = t;
    } else {
      await _storage.saveTemplate(_template);
    }
    final data = await _storage.loadData();
    _years = data.years;
    _records = data.records;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistData() async {
    await _storage.saveData(_years, _records);
    notifyListeners();
  }

  Future<void> _persistTemplate() async {
    await _storage.saveTemplate(_template);
    notifyListeners();
  }

  // ---- 记录查询 ----
  /// 某学年的全部记录，按时间倒序（最新在前）。
  List<ActivityRecord> recordsOfYear(String yearId) {
    final list = _records.where((r) => r.yearId == yearId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 某学年记录按时间升序（用于累计分计算）。
  List<ActivityRecord> recordsOfYearAsc(String yearId) {
    final list = _records.where((r) => r.yearId == yearId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ---- 学年操作 ----
  Future<AcademicYear> addYear(String name) async {
    final maxOrder = _years.fold<int>(
        0, (prev, y) => y.order > prev ? y.order : prev);
    final year = AcademicYear(
      id: _uuid.v4(),
      name: name,
      order: maxOrder + 1,
      createdAt: DateTime.now(),
    );
    _years = [..._years, year];
    _currentYearId ??= year.id;
    await _persistData();
    return year;
  }

  Future<void> updateYear(AcademicYear year) async {
    _years = _years.map((y) => y.id == year.id ? year : y).toList();
    await _persistData();
  }

  Future<void> setArchived(String yearId, bool archived) async {
    final y = yearById(yearId);
    if (y == null) return;
    await updateYear(y.copyWith(archived: archived));
    if (archived && _currentYearId == yearId) {
      _currentYearId = activeYears.isNotEmpty ? activeYears.first.id : null;
    }
  }

  Future<void> deleteYear(String yearId) async {
    _years = _years.where((y) => y.id != yearId).toList();
    _records = _records.where((r) => r.yearId != yearId).toList();
    if (_currentYearId == yearId) _currentYearId = null;
    await _persistData();
  }

  // ---- 记录操作 ----
  Future<ActivityRecord> addRecord(ActivityRecord record) async {
    _records = [..._records, record];
    await _persistData();
    return record;
  }

  Future<void> updateRecord(ActivityRecord record) async {
    _records = _records.map((r) => r.id == record.id ? record : r).toList();
    await _persistData();
  }

  Future<void> deleteRecord(String id) async {
    _records = _records.where((r) => r.id != id).toList();
    await _persistData();
  }

  String newId() => _uuid.v4();

  // ---- 模板操作 ----
  Future<void> replaceTemplate(Template template) async {
    _template = template;
    await _persistTemplate();
  }

  Future<void> updateTemplate(Template template) async {
    _template = template;
    await _persistTemplate();
  }

  // ---- 全量数据导入/导出 ----
  Future<String> exportAll() => _storage.exportAllJson();

  /// 从导出 JSON 全量导入（覆盖模板、学年与记录）。
  Future<void> importAll(Map<String, dynamic> json) async {
    if (json['template'] != null) {
      _template = Template.fromJson(json['template'] as Map<String, dynamic>);
      await _storage.saveTemplate(_template);
    }
    _years = (json['years'] as List<dynamic>? ?? [])
        .map((e) => AcademicYear.fromJson(e as Map<String, dynamic>))
        .toList();
    _records = (json['records'] as List<dynamic>? ?? [])
        .map((e) => ActivityRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    _currentYearId = null;
    await _persistData();
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../models/template.dart';
import 'scoring.dart';
import 'storage_service.dart';

/// 导出为 Excel 表格 + 附件压缩包。
/// 表格中附件列仅列出文件名；附件文件本体单独打包为 zip 导出。
class ExcelExportService {
  ExcelExportService(this._storage);

  final StorageService _storage;

  /// 构建 .xlsx 字节：明细表「活动记录」+「学年汇总」表。
  Uint8List buildWorkbook({
    required Template template,
    required List<AcademicYear> years,
    required List<ActivityRecord> records,
  }) {
    final scoring = Scoring(template);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    // 年份按 order 倒序（最新在前）。
    final sortedYears = [...years]..sort((a, b) => b.order.compareTo(a.order));

    // ---- 明细表 ----
    final detail = excel['活动记录'];
    const header = [
      '学年', '活动名称', '分类', '是否获奖', '获奖等级', '名次',
      '团队荣誉', '角色', '本条得分', '分类累计/上限', '添加日期', '附件', '备注',
    ];
    detail.appendRow([for (final h in header) TextCellValue(h)]);

    for (final y in sortedYears) {
      final asc = records.where((r) => r.yearId == y.id).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final r in asc) {
        final cat = template.categoryById(r.categoryId);
        final delta = scoring.scoreOf(r);
        final cumText = cat == null
            ? ''
            : '${formatScore(scoring.categoryCumulativeUpTo(asc, r))}'
                '/${formatScore(cat.yearCap)}';
        // 附件仅列出文件名。
        final attachNames = r.attachments.map((a) => a.displayName).join('; ');
        detail.appendRow(<CellValue?>[
          TextCellValue(y.name),
          TextCellValue(r.name),
          TextCellValue(cat?.name ?? '未分类'),
          TextCellValue(r.awarded ? '是' : '否'),
          TextCellValue(r.awardLevel ?? ''),
          TextCellValue(r.rank ?? ''),
          TextCellValue(r.isTeam ? '是' : '否'),
          TextCellValue(r.role ?? ''),
          DoubleCellValue(delta),
          TextCellValue(cumText),
          TextCellValue(df.format(r.createdAt)),
          TextCellValue(attachNames),
          TextCellValue(r.note ?? ''),
        ]);
      }
    }

    // ---- 学年汇总表 ----
    final summary = excel['学年汇总'];
    summary.appendRow(<CellValue?>[
      TextCellValue('学年'),
      for (final c in template.categories) TextCellValue(c.name),
      TextCellValue('未分类'),
      TextCellValue('学年总分'),
      TextCellValue('学年上限'),
    ]);
    for (final y in sortedYears) {
      final recs = records.where((r) => r.yearId == y.id).toList();
      double uncategorized = 0;
      for (final r in recs) {
        if (r.categoryId == null) uncategorized += scoring.scoreOf(r);
      }
      summary.appendRow(<CellValue?>[
        TextCellValue(y.name),
        for (final c in template.categories)
          DoubleCellValue(_capped(scoring.categoryCumulative(recs, c.id), c.yearCap)),
        DoubleCellValue(uncategorized),
        DoubleCellValue(scoring.yearTotal(recs)),
        DoubleCellValue(template.yearScoreCap),
      ]);
    }

    // 删除 createExcel 自带的空白默认表。
    if (defaultSheet != null &&
        defaultSheet != '活动记录' &&
        defaultSheet != '学年汇总') {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? const <int>[]);
  }

  static double _capped(double v, double cap) => v > cap ? cap : v;

  /// 构建综合导出 zip：根目录放 [xlsxName] 表格，附件放在
  /// 「附件/学年/活动名称/原文件名」下（重名自动追加序号）。
  /// 返回 zip 字节与打包的附件数量。Web 平台无文件系统，附件数为 0。
  ///
  /// 之所以把表格与附件合并到同一个 zip、只弹一次保存框：Android 的
  /// 文件保存（SAF）不能可靠地连续弹出两次对话框，分两次保存会丢失第二个。
  Future<({Uint8List bytes, int attachmentCount})> buildExportZip({
    required String xlsxName,
    required Uint8List xlsxBytes,
    required List<AcademicYear> years,
    required List<ActivityRecord> records,
  }) async {
    final archive = Archive()
      ..addFile(ArchiveFile(xlsxName, xlsxBytes.length, xlsxBytes));
    var count = 0;

    if (!kIsWeb) {
      final dir = await _storage.attachmentsDir();
      final yearName = {for (final y in years) y.id: y.name};
      final used = <String>{};
      for (final r in records) {
        if (r.attachments.isEmpty) continue;
        final folder =
            '附件/${_safe(yearName[r.yearId] ?? '未归档')}/${_safe(r.name)}';
        for (final a in r.attachments) {
          final src = File(p.join(dir.path, a.storedName));
          if (!await src.exists()) continue;
          final bytes = await src.readAsBytes();
          var entry = '$folder/${_safe(a.displayName)}';
          if (used.contains(entry)) {
            final base = p.basenameWithoutExtension(entry);
            final ext = p.extension(entry);
            final parent = p.dirname(entry);
            var i = 1;
            do {
              entry = '$parent/$base($i)$ext';
              i++;
            } while (used.contains(entry));
          }
          used.add(entry);
          archive.addFile(ArchiveFile(entry, bytes.length, bytes));
          count++;
        }
      }
    }

    final encoded = ZipEncoder().encode(archive);
    return (
      bytes: Uint8List.fromList(encoded ?? const <int>[]),
      attachmentCount: count,
    );
  }

  /// 文件/文件夹名安全化：替换 Windows 等系统的非法字符。
  static String _safe(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? '未命名' : cleaned;
  }

  /// 保存字节到用户选择位置，返回路径（取消或 Web 下载则为 null）。
  static Future<String?> saveBytes(
      String fileName, String ext, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes,
    );
    if (path == null) return null;
    // 仅桌面端：saveFile 只返回路径、不写内容，需自行写入。
    // 移动端（Android/iOS）插件已通过 bytes 写好，且返回的多为 SAF 的
    // 非文件系统路径（如 /document/4753），不能再用 dart:io 打开/写入，否则
    // 会抛 PathNotFoundException。
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final f = File(path);
      if (!await f.exists() || (await f.length()) == 0) {
        await f.writeAsBytes(bytes);
      }
    }
    return path;
  }
}

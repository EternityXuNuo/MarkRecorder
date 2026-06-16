import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../models/template.dart';
import '../models/tombstone.dart';

/// 一份完整的可同步数据快照：模板 + 学年 + 记录 + 删除墓碑。
/// 用于多设备同步（WebDAV 恢复、局域网传输）的输入与输出。
class SyncSnapshot {
  final Template template;
  final List<AcademicYear> years;
  final List<ActivityRecord> records;
  final List<Tombstone> deletedYears;
  final List<Tombstone> deletedRecords;

  const SyncSnapshot({
    required this.template,
    required this.years,
    required this.records,
    this.deletedYears = const [],
    this.deletedRecords = const [],
  });

  Map<String, dynamic> toJson() => {
        'template': template.toJson(),
        'years': years.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'deletedYears': deletedYears.map((e) => e.toJson()).toList(),
        'deletedRecords': deletedRecords.map((e) => e.toJson()).toList(),
      };

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) => SyncSnapshot(
        template: Template.fromJson(json['template'] as Map<String, dynamic>),
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

/// 合并结果：合并后的快照、变更计数、以及合并后数据集引用到的附件文件名集合
/// （传输层据此补齐本地缺失的附件二进制）。
class MergeResult {
  final SyncSnapshot snapshot;

  /// 相对本地：新增、更新、删除的记录数（用于给用户一个概要提示）。
  final int added;
  final int updated;
  final int deleted;

  /// 合并后所有存活记录引用到的附件 storedName 集合。
  final Set<String> neededAttachments;

  const MergeResult({
    required this.snapshot,
    required this.added,
    required this.updated,
    required this.deleted,
    required this.neededAttachments,
  });
}

/// 双向合并引擎（纯函数，无副作用、不依赖 IO，便于单测）。
///
/// 规则：
/// - 实体按 [id] 对齐，取 `updatedAt` 较新者（同一条两端都改 → 新的胜）。
/// - 墓碑按 id 取较新 `deletedAt` 后求并集；若某 id 的墓碑 `deletedAt` 不早于
///   该实体的 `updatedAt`，则判定为已删除、从结果中剔除。
/// - 学年删除会连带删除其下记录；合并后剔除指向不存在学年的"孤儿"记录。
/// - 模板整体按 `updatedAt` 较新者胜。
/// - 墓碑过期清理：早于 [tombstoneTtl] 的墓碑在合并结果中丢弃。
class MergeService {
  static const Duration tombstoneTtl = Duration(days: 180);

  static MergeResult merge(
    SyncSnapshot local,
    SyncSnapshot remote, {
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();

    // ---- 墓碑并集（按 id 取较新 deletedAt），并按 TTL 清理 ----
    final yearTomb = _mergeTombstones(local.deletedYears, remote.deletedYears);
    final recTomb =
        _mergeTombstones(local.deletedRecords, remote.deletedRecords);
    final cutoff = ts.subtract(tombstoneTtl);

    // ---- 学年：按 id 取较新者，剔除被墓碑压制的 ----
    final years = _mergeById<AcademicYear>(
      local.years,
      remote.years,
      id: (y) => y.id,
      updatedAt: (y) => y.updatedAt,
    );
    final survivingYears = <AcademicYear>[];
    for (final y in years.values) {
      final t = yearTomb[y.id];
      if (t != null && !t.deletedAt.isBefore(y.updatedAt)) continue;
      survivingYears.add(y);
    }
    final yearIds = {for (final y in survivingYears) y.id};

    // ---- 记录：按 id 取较新者，剔除被墓碑压制的与孤儿记录 ----
    final localRecIds = {for (final r in local.records) r.id};
    final records = _mergeById<ActivityRecord>(
      local.records,
      remote.records,
      id: (r) => r.id,
      updatedAt: (r) => r.updatedAt,
    );
    var added = 0, updated = 0, deleted = 0;
    final survivingRecords = <ActivityRecord>[];
    for (final r in records.values) {
      final t = recTomb[r.id];
      final tombstoned = t != null && !t.deletedAt.isBefore(r.updatedAt);
      final orphan = !yearIds.contains(r.yearId);
      if (tombstoned || orphan) {
        if (localRecIds.contains(r.id)) deleted++;
        continue;
      }
      survivingRecords.add(r);
      if (!localRecIds.contains(r.id)) {
        added++;
      } else {
        final localRec = local.records.firstWhere((e) => e.id == r.id);
        if (r.updatedAt.isAfter(localRec.updatedAt)) updated++;
      }
    }

    // ---- 模板：整体较新者胜 ----
    final template = remote.template.updatedAt.isAfter(local.template.updatedAt)
        ? remote.template
        : local.template;

    // ---- 附件需求集合 ----
    final needed = <String>{};
    for (final r in survivingRecords) {
      for (final a in r.attachments) {
        needed.add(a.storedName);
      }
    }

    return MergeResult(
      snapshot: SyncSnapshot(
        template: template,
        years: survivingYears,
        records: survivingRecords,
        deletedYears: _prune(yearTomb.values, cutoff),
        deletedRecords: _prune(recTomb.values, cutoff),
      ),
      added: added,
      updated: updated,
      deleted: deleted,
      neededAttachments: needed,
    );
  }

  static Map<String, T> _mergeById<T>(
    List<T> a,
    List<T> b, {
    required String Function(T) id,
    required DateTime Function(T) updatedAt,
  }) {
    final out = <String, T>{};
    for (final e in [...a, ...b]) {
      final key = id(e);
      final cur = out[key];
      // 取较新者；时间相同则保留先放入的（local 先于 remote），避免无谓抖动。
      if (cur == null || updatedAt(e).isAfter(updatedAt(cur))) {
        out[key] = e;
      }
    }
    return out;
  }

  static Map<String, Tombstone> _mergeTombstones(
      List<Tombstone> a, List<Tombstone> b) {
    final out = <String, Tombstone>{};
    for (final t in [...a, ...b]) {
      final cur = out[t.id];
      if (cur == null || t.deletedAt.isAfter(cur.deletedAt)) {
        out[t.id] = t;
      }
    }
    return out;
  }

  static List<Tombstone> _prune(Iterable<Tombstone> tombs, DateTime cutoff) =>
      [for (final t in tombs) if (t.deletedAt.isAfter(cutoff)) t];
}

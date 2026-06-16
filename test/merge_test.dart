import 'package:flutter_test/flutter_test.dart';

import 'package:mark_recoder/models/academic_year.dart';
import 'package:mark_recoder/models/activity_record.dart';
import 'package:mark_recoder/models/attachment.dart';
import 'package:mark_recoder/models/tombstone.dart';
import 'package:mark_recoder/services/default_template.dart';
import 'package:mark_recoder/services/merge_service.dart';

void main() {
  // 所有事件时间集中在 now 附近几天内，避免墓碑 TTL（180 天）误清理。
  final now = DateTime(2024, 6, 10);
  DateTime at(int dayOffset) => now.add(Duration(days: dayOffset));

  AcademicYear yr(String id, {required DateTime updated, String name = 'y'}) =>
      AcademicYear(
          id: id, name: name, order: 0, createdAt: updated, updatedAt: updated);

  ActivityRecord rec(
    String id, {
    required String yearId,
    required DateTime updated,
    String name = 'r',
    List<Attachment> attachments = const [],
  }) =>
      ActivityRecord(
        id: id,
        name: name,
        yearId: yearId,
        attachments: attachments,
        createdAt: updated,
        updatedAt: updated,
      );

  SyncSnapshot snap({
    List<AcademicYear> years = const [],
    List<ActivityRecord> records = const [],
    List<Tombstone> deletedYears = const [],
    List<Tombstone> deletedRecords = const [],
  }) =>
      SyncSnapshot(
        template: buildDefaultTemplate(),
        years: years,
        records: records,
        deletedYears: deletedYears,
        deletedRecords: deletedRecords,
      );

  test('对方新增的记录被合并进来', () {
    final y = yr('y1', updated: at(-5));
    final local = snap(years: [y], records: [rec('r1', yearId: 'y1', updated: at(-4))]);
    final remote = snap(years: [y], records: [rec('r2', yearId: 'y1', updated: at(-3))]);

    final result = MergeService.merge(local, remote, now: now);
    final ids = result.snapshot.records.map((r) => r.id).toSet();
    expect(ids, {'r1', 'r2'});
    expect(result.added, 1);
  });

  test('同一条两端都改，updatedAt 较新者胜', () {
    final y = yr('y1', updated: at(-5));
    final local = snap(
        years: [y],
        records: [rec('r1', yearId: 'y1', updated: at(-4), name: '旧')]);
    final remote = snap(
        years: [y],
        records: [rec('r1', yearId: 'y1', updated: at(-2), name: '新')]);

    final result = MergeService.merge(local, remote, now: now);
    final r1 = result.snapshot.records.single;
    expect(r1.name, '新');
    expect(result.updated, 1);
  });

  test('本地已删除的记录不会被对方复活（墓碑早于对方编辑则压制）', () {
    final y = yr('y1', updated: at(-5));
    final local = snap(
      years: [y],
      deletedRecords: [Tombstone('r1', at(-1))],
    );
    // 对方那条的编辑时间早于删除时间 -> 应保持删除。
    final remote =
        snap(years: [y], records: [rec('r1', yearId: 'y1', updated: at(-3))]);

    final result = MergeService.merge(local, remote, now: now);
    expect(result.snapshot.records, isEmpty);
  });

  test('删除后对方又编辑（编辑更晚）则记录复活', () {
    final y = yr('y1', updated: at(-5));
    final local = snap(
      years: [y],
      deletedRecords: [Tombstone('r1', at(-3))],
    );
    final remote =
        snap(years: [y], records: [rec('r1', yearId: 'y1', updated: at(-1))]);

    final result = MergeService.merge(local, remote, now: now);
    expect(result.snapshot.records.map((r) => r.id), ['r1']);
  });

  test('学年被删后，对方该学年下的记录作为孤儿被剔除', () {
    final local = snap(deletedYears: [Tombstone('y1', at(-1))]);
    final remote = snap(
      years: [yr('y1', updated: at(-3))],
      records: [rec('r1', yearId: 'y1', updated: at(-2))],
    );

    final result = MergeService.merge(local, remote, now: now);
    expect(result.snapshot.years, isEmpty);
    expect(result.snapshot.records, isEmpty);
  });

  test('模板按整体 updatedAt 较新者胜', () {
    final older = buildDefaultTemplate()
        .copyWith(name: '旧模板', updatedAt: at(-5));
    final newer = buildDefaultTemplate()
        .copyWith(name: '新模板', updatedAt: at(-1));
    final local = SyncSnapshot(template: older, years: const [], records: const []);
    final remote = SyncSnapshot(template: newer, years: const [], records: const []);

    final result = MergeService.merge(local, remote, now: now);
    expect(result.snapshot.template.name, '新模板');
  });

  test('合并结果汇总存活记录引用的附件文件名', () {
    final y = yr('y1', updated: at(-5));
    final att = Attachment(
      id: 'a1',
      storedName: 'abc.png',
      displayName: '证书.png',
      extension: 'png',
      sizeBytes: 10,
      addedAt: at(-4),
    );
    final local = snap(years: [y]);
    final remote = snap(
        years: [y],
        records: [rec('r1', yearId: 'y1', updated: at(-3), attachments: [att])]);

    final result = MergeService.merge(local, remote, now: now);
    expect(result.neededAttachments, {'abc.png'});
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_record.dart';
import '../state/app_state.dart';
import 'attachment_chip.dart';
import 'score_badge.dart';

/// 以卡片形式弹出活动记录详情。
Future<void> showRecordDetail(BuildContext context, ActivityRecord record) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RecordDetailCard(record: record),
  );
}

class _RecordDetailCard extends StatelessWidget {
  const _RecordDetailCard({required this.record});

  final ActivityRecord record;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final template = app.template;
    final cat = template.categoryById(record.categoryId);
    final scoring = app.scoring;
    final year = app.yearById(record.yearId);
    final ascRecords = app.recordsOfYearAsc(record.yearId);

    final delta = scoring.scoreOf(record);
    final cumulative = record.categoryId == null
        ? delta
        : scoring.categoryCumulativeUpTo(ascRecords, record);
    final cap = cat?.yearCap ?? 0;

    final color = cat != null ? Color(cat.color) : const Color(0xFF9AA0A6);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  Text(
                    cat?.name ?? '未分类',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                record.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 16),
              if (record.categoryId != null && cat != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScoreBadge(
                    cumulative: cumulative,
                    delta: delta,
                    cap: cap,
                    color: color,
                  ),
                ),
              _row('学年', year?.name ?? '—'),
              _row('获奖情况', record.awarded ? '已获奖' : '未获奖'),
              if (record.awarded) ...[
                _row('获奖等级', record.awardLevel ?? '—'),
                _row('名次', record.rank ?? '—'),
              ],
              if (record.isTeam) _row('团队角色', record.role ?? '—'),
              _row('添加日期',
                  DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)),
              if (record.note != null && record.note!.isNotEmpty)
                _row('备注', record.note!),
              if (record.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('附件',
                    style: TextStyle(
                        color: Color(0xFF5F6368),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in record.attachments)
                      AttachmentChip(attachment: a),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF9AA0A6), fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

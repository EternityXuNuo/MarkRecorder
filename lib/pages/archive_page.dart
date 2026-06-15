import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/academic_year.dart';
import '../state/app_state.dart';
import '../widgets/record_detail_sheet.dart';
import '../widgets/year_section.dart';

/// 归档页面：展示已归档学年，只读查看，左滑可取消归档。
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final years = app.archivedYears;

    return Scaffold(
      appBar: AppBar(title: const Text('归档')),
      body: years.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
              children: [
                for (final y in years)
                  YearSection(
                    year: y,
                    recordsDesc: app.recordsOfYear(y.id),
                    recordsAsc: app.recordsOfYearAsc(y.id),
                    template: app.template,
                    scoring: app.scoring,
                    readOnly: true,
                    expanded: _expanded.contains(y.id),
                    onToggle: () => setState(() {
                      if (!_expanded.remove(y.id)) _expanded.add(y.id);
                    }),
                    onRecordTap: (r) => showRecordDetail(context, r),
                    swipeLabel: '取消归档',
                    swipeIcon: Icons.unarchive_outlined,
                    swipeColor: const Color(0xFF34A853),
                    onSwipe: () => app.setArchived(y.id, false),
                    onYearDelete: () => _confirmDeleteYear(context, app, y),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteYear(
      BuildContext context, AppState app, AcademicYear y) async {
    final count = app.recordsOfYear(y.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除学年'),
        content: Text(count > 0
            ? '确定删除"${y.name}"吗？该学年下的 $count 条记录也会一并删除，此操作不可恢复。'
            : '确定删除"${y.name}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await app.deleteYear(y.id);
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFCBD2DD)),
          SizedBox(height: 16),
          Text('暂无归档学年',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('在记录页左滑学年即可归档',
              style: TextStyle(color: Color(0xFF9AA0A6))),
        ],
      ),
    );
  }
}

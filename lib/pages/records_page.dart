import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../state/app_state.dart';
import '../widgets/add_record_sheet.dart';
import '../widgets/record_detail_sheet.dart';
import '../widgets/year_section.dart';
import 'year_editor.dart';

/// 记录页面：按 学年 > 活动类型 两级分类展示活动记录。
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final Set<String> _expanded = {};
  bool _initialExpandDone = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final years = app.activeYears;

    // 默认展开最新（当前）学年。
    if (!_initialExpandDone && years.isNotEmpty) {
      _expanded.add(years.first.id);
      _initialExpandDone = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录'),
        actions: [
          IconButton(
            tooltip: '新建学年',
            onPressed: () => _addYear(context),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButtonLocation: const _FractionalFabLocation(0.30),
      floatingActionButton: years.isEmpty
          ? null
          : Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    showRecordSheet(context, initialYearId: app.currentYearId),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Color(0x40000000), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.add,
                      size: 30, color: Color(0xFF1A1C1E)),
                ),
              ),
            ),
      body: years.isEmpty
          ? _buildEmpty(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              children: [
                for (final y in years) _buildYear(context, app, y),
              ],
            ),
    );
  }

  Widget _buildYear(BuildContext context, AppState app, AcademicYear y) {
    return YearSection(
      year: y,
      recordsDesc: app.recordsOfYear(y.id),
      recordsAsc: app.recordsOfYearAsc(y.id),
      template: app.template,
      scoring: app.scoring,
      expanded: _expanded.contains(y.id),
      onToggle: () => setState(() {
        if (!_expanded.remove(y.id)) _expanded.add(y.id);
      }),
      onRecordTap: (r) => showRecordDetail(context, r),
      onRecordEdit: (r) => showRecordSheet(context, record: r),
      onRecordDelete: (r) => _confirmDelete(context, app, r),
      swipeLabel: '归档',
      swipeIcon: Icons.archive_outlined,
      swipeColor: const Color(0xFFF5A55E),
      onSwipe: () => app.setArchived(y.id, true),
      onYearDelete: () => _confirmDeleteYear(context, app, y),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 64, color: Color(0xFFCBD2DD)),
          const SizedBox(height: 16),
          const Text('还没有学年',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('先创建一个学年，再开始记录活动',
              style: TextStyle(color: Color(0xFF9AA0A6))),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _addYear(context),
            icon: const Icon(Icons.add),
            label: const Text('新建学年'),
          ),
        ],
      ),
    );
  }

  Future<void> _addYear(BuildContext context) async {
    final app = context.read<AppState>();
    final name = await showYearEditor(context);
    if (name != null && name.isNotEmpty) {
      final created = await app.addYear(name);
      app.currentYearId = created.id;
      setState(() => _expanded.add(created.id));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState app, ActivityRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除"${r.name}"吗？此操作不可恢复。'),
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
    if (ok == true) await app.deleteRecord(r.id);
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
}

/// 将悬浮按钮固定在右侧、距屏幕底部 [bottomFraction]（如 0.30 即 30%）高度处。
class _FractionalFabLocation extends FloatingActionButtonLocation {
  const _FractionalFabLocation(this.bottomFraction);

  /// 按钮垂直中心距底部的比例（0~1）。
  final double bottomFraction;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final fab = geometry.floatingActionButtonSize;
    final x = geometry.scaffoldSize.width -
        fab.width -
        kFloatingActionButtonMargin -
        geometry.minInsets.right;
    final y = geometry.scaffoldSize.height * (1 - bottomFraction) -
        fab.height / 2;
    return Offset(x, y);
  }
}

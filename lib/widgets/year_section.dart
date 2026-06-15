import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/academic_year.dart';
import '../models/activity_record.dart';
import '../models/template.dart';
import '../services/scoring.dart';
import 'record_tile.dart';

/// 一级分类：学年。白色卡片为学年头部，展开后显示分类筛选与彩色记录卡片。
/// 收起状态下可左滑触发归档/取消归档操作（参考 Figma 风格）。
class YearSection extends StatefulWidget {
  const YearSection({
    super.key,
    required this.year,
    required this.recordsDesc,
    required this.recordsAsc,
    required this.template,
    required this.scoring,
    required this.expanded,
    required this.onToggle,
    required this.onRecordTap,
    this.onRecordEdit,
    this.onRecordDelete,
    this.swipeLabel,
    this.swipeIcon,
    this.swipeColor,
    this.onSwipe,
    this.onYearDelete,
    this.readOnly = false,
  });

  final AcademicYear year;
  final List<ActivityRecord> recordsDesc;
  final List<ActivityRecord> recordsAsc;
  final Template template;
  final Scoring scoring;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(ActivityRecord) onRecordTap;
  final void Function(ActivityRecord)? onRecordEdit;
  final void Function(ActivityRecord)? onRecordDelete;

  final String? swipeLabel;
  final IconData? swipeIcon;
  final Color? swipeColor;
  final VoidCallback? onSwipe;

  /// 左滑删除该学年（连同其下记录）。为空则不显示删除按钮。
  final VoidCallback? onYearDelete;
  final bool readOnly;

  @override
  State<YearSection> createState() => _YearSectionState();
}

class _YearSectionState extends State<YearSection> {
  String? _filterCategoryId;
  bool _filterActive = false;

  @override
  Widget build(BuildContext context) {
    final yearTotal = widget.scoring.yearTotal(widget.recordsDesc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildHeaderWithSwipe(context, yearTotal),
        ),
        if (widget.expanded) ...[
          _buildCategoryLegend(),
          _buildRecordList(),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildHeaderWithSwipe(BuildContext context, double yearTotal) {
    final header = _buildHeader(context, yearTotal);
    final hasSwipe = widget.onSwipe != null;
    final hasDelete = widget.onYearDelete != null;
    if ((!hasSwipe && !hasDelete) || widget.expanded) return header;

    const radius = Radius.circular(16);
    final actions = <Widget>[];
    if (hasSwipe) {
      actions.add(_yearAction(
        onPressed: widget.onSwipe!,
        color: widget.swipeColor ?? const Color(0xFF4C7EF3),
        icon: widget.swipeIcon ?? Icons.archive_outlined,
        label: widget.swipeLabel ?? '归档',
        // 仅最右侧按钮需要右侧圆角。
        borderRadius: hasDelete
            ? BorderRadius.zero
            : const BorderRadius.horizontal(right: radius),
      ));
    }
    if (hasDelete) {
      actions.add(_yearAction(
        onPressed: widget.onYearDelete!,
        color: const Color(0xFFEA4335),
        icon: Icons.delete_outline,
        label: '删除',
        borderRadius: const BorderRadius.horizontal(right: radius),
      ));
    }

    // 圆角与阴影都在头部卡片本体上，左滑时整张卡片整体平移露出按钮（BehindMotion）。
    // 底衬与最左侧按钮同色，填补卡片右侧圆角缺口，避免出现“空隙”。
    final fillerColor = hasSwipe
        ? (widget.swipeColor ?? const Color(0xFF4C7EF3))
        : const Color(0xFFEA4335);
    final extentRatio = actions.length >= 2 ? 0.5 : 0.3;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fillerColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Slidable(
          key: ValueKey('year_${widget.year.id}'),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: extentRatio,
            children: actions,
          ),
          child: header,
        ),
      ],
    );
  }

  /// 横向排列的学年左滑操作按钮（图标 + 文字）。
  Widget _yearAction({
    required VoidCallback onPressed,
    required Color color,
    required IconData icon,
    required String label,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: color,
      borderRadius: borderRadius,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double yearTotal) {
    final scoreCap = widget.template.yearScoreCap;
    final overCap = yearTotal > scoreCap;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 4),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
            children: [
              AnimatedRotation(
                turns: widget.expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                child:
                    const Icon(Icons.chevron_right, color: Color(0xFFB0B6C0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.year.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: formatScore(yearTotal),
                      style: TextStyle(
                        fontSize: 18,
                        color: overCap
                            ? const Color(0xFFEA4335)
                            : const Color(0xFF1A1C1E),
                      ),
                    ),
                    TextSpan(
                      text: '/${formatScore(scoreCap)}',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF9AA0A6)),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    final usedIds = <String>{
      for (final r in widget.recordsDesc)
        if (r.categoryId != null) r.categoryId!
    };
    final cats =
        widget.template.categories.where((c) => usedIds.contains(c.id)).toList();
    if (cats.isEmpty) return const SizedBox(height: 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in cats)
            _LegendChip(
              label: c.name,
              color: Color(c.color),
              selected: _filterActive && _filterCategoryId == c.id,
              onTap: () => setState(() {
                if (_filterActive && _filterCategoryId == c.id) {
                  _filterActive = false;
                  _filterCategoryId = null;
                } else {
                  _filterActive = true;
                  _filterCategoryId = c.id;
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    var records = widget.recordsDesc;
    if (_filterActive) {
      records =
          records.where((r) => r.categoryId == _filterCategoryId).toList();
    }

    if (records.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('暂无活动记录',
            style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 13)),
      );
    }

    return Column(
      children: [
        for (final r in records)
          Builder(builder: (context) {
            final cat = widget.template.categoryById(r.categoryId);
            final delta = widget.scoring.scoreOf(r);
            final cumulative = r.categoryId == null
                ? delta
                : widget.scoring.categoryCumulativeUpTo(widget.recordsAsc, r);
            return RecordTile(
              record: r,
              category: cat,
              cumulative: cumulative,
              delta: delta,
              readOnly: widget.readOnly,
              onTap: () => widget.onRecordTap(r),
              onEdit: () => widget.onRecordEdit?.call(r),
              onDelete: () => widget.onRecordDelete?.call(r),
            );
          }),
      ],
    );
  }
}

/// 分类筛选小药丸：浅色底 + 分类色描边/文字，选中时填充分类色。
class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x26000000), blurRadius: 3),
          ],
          border: selected
              ? Border.all(color: const Color(0xCC1A1A1A), width: 1.4)
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

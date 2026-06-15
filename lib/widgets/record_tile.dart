import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../models/activity_record.dart';
import '../models/category.dart';
import 'score_badge.dart';

/// 单条活动记录展示：整行为分类色彩的圆角卡片（参考 Figma 风格）。
/// 左侧附件图标、活动名称，中部日期，右侧分数。
/// 左滑显示编辑/删除（仅记录页），点击查看详情。
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.category,
    required this.cumulative,
    required this.delta,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.readOnly = false,
  });

  final ActivityRecord record;
  final ActivityCategory? category;
  final double cumulative;
  final double delta;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final bg =
        category != null ? Color(category!.color) : const Color(0xFFE6EAF0);
    const textColor = Color(0xFF1A1A1A);

    // 圆角 / 阴影 / 背景色都加在卡片本体上：左滑时整张卡片整体平移露出按钮，
    // 而不是内容在固定外框里滑动。按钮位于卡片之后（BehindMotion）。
    final card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    if (record.hasAttachment) ...[
                      const Icon(Icons.attach_file, size: 18, color: textColor),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (record.awarded)
                      const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child:
                            Icon(Icons.emoji_events, size: 15, color: textColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 添加日期居中显示。
              Text(
                DateFormat('yyyy/MM/dd').format(record.createdAt),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: category != null
                      ? ScoreBadge(
                          cumulative: cumulative,
                          delta: delta,
                          cap: category!.yearCap,
                          color: textColor,
                          plain: true,
                        )
                      : const Text('未计分',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );

    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 与最左侧按钮同色的圆角底衬：卡片左滑后，其右侧圆角缺口处露出的
          // 是此底色而非页面底色，从而消除卡片圆角与按钮之间的“空隙”。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF4C7EF3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Slidable(
            key: ValueKey(record.id),
            endActionPane: ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.5,
              children: [
                _action(
                    onEdit, const Color(0xFF4C7EF3), Icons.edit_outlined, '编辑'),
                _action(onDelete, const Color(0xFFEA4335),
                    Icons.delete_outline, '删除',
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12))),
              ],
            ),
            child: card,
          ),
        ],
      ),
    );
  }

  /// 横向排列的左滑操作按钮（图标 + 文字），区别于默认的竖向排列。
  /// [borderRadius] 用于让最右侧按钮的右侧圆角与卡片一致。
  Widget _action(
      VoidCallback? onPressed, Color color, IconData icon, String label,
      {BorderRadius borderRadius = BorderRadius.zero}) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed?.call(),
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
}

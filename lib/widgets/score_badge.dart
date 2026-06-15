import 'package:flutter/material.dart';

import '../services/scoring.dart';

/// 分数展示徽标，格式：当前总分(变动)/学年总分，例如 8(+3)/25。
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.cumulative,
    required this.delta,
    required this.cap,
    this.color,
    this.plain = false,
  });

  /// 截止该记录的分类累计分。
  final double cumulative;

  /// 本条记录的分数变动。
  final double delta;

  /// 该类活动学年总分上限。
  final double cap;

  final Color? color;

  /// 平铺模式：整串使用同一深色（用于彩色卡片背景上的展示，参考 Figma）。
  final bool plain;

  @override
  Widget build(BuildContext context) {
    if (plain) {
      final c = color ?? const Color(0xFF1A1C1E);
      return Text(
        '${formatScore(cumulative)}(${formatDelta(delta)})/${formatScore(cap)}',
        style: TextStyle(
          color: c,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    final c = color ?? Theme.of(context).colorScheme.primary;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        children: [
          TextSpan(
            text: formatScore(cumulative),
            style: TextStyle(color: c, fontSize: 17),
          ),
          TextSpan(
            text: '(${formatDelta(delta)})',
            style: TextStyle(
              color:
                  delta >= 0 ? const Color(0xFF34A853) : const Color(0xFFEA4335),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '/${formatScore(cap)}',
            style: const TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

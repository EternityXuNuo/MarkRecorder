/// 活动分类。由模板作者定义，带颜色、学年总分上限与提示信息。
class ActivityCategory {
  final String id;
  final String name;

  /// 分类颜色（ARGB 整数）。用于在记录页区分不同活动类型。
  final int color;

  /// 该类活动的学年总分上限（用于分数展示 8(+3)/25 中的 25）。
  final double yearCap;

  /// 模板作者为该分类设置的提示信息。
  final String? hint;

  const ActivityCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.yearCap,
    this.hint,
  });

  ActivityCategory copyWith({
    String? name,
    int? color,
    double? yearCap,
    String? hint,
  }) {
    return ActivityCategory(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      yearCap: yearCap ?? this.yearCap,
      hint: hint ?? this.hint,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'yearCap': yearCap,
        if (hint != null) 'hint': hint,
      };

  factory ActivityCategory.fromJson(Map<String, dynamic> json) =>
      ActivityCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int,
        yearCap: (json['yearCap'] as num).toDouble(),
        hint: json['hint'] as String?,
      );
}

/// 计分规则。每条规则描述一种活动情形对应的分数。
///
/// 匹配逻辑：规则中所有非 null 字段必须与活动记录对应字段相等，规则才适用。
/// 在所有适用的规则中，选择"指定字段最多"（最具体）的规则作为该活动的分数。
class ScoreRule {
  /// 所属活动分类 id（必填）。
  final String categoryId;

  /// 该规则是否针对"已获奖"的活动。
  final bool awarded;

  /// 获奖级别（国家级/省级/校级/院级…），仅在 awarded 为 true 时有意义。
  final String? awardLevel;

  /// 名次（一等奖/二等奖…），仅在 awarded 为 true 时有意义。
  final String? rank;

  /// 角色（队长/第一队员…）。仅在模板区分角色且为团队荣誉时有意义。
  final String? role;

  /// 该情形对应分数。
  final double points;

  const ScoreRule({
    required this.categoryId,
    required this.awarded,
    this.awardLevel,
    this.rank,
    this.role,
    required this.points,
  });

  /// 指定（非 null / 非默认）字段数量，用于挑选最具体的规则。
  int get specificity {
    var count = 1; // categoryId 必有
    count++; // awarded 总是参与匹配
    if (awardLevel != null) count++;
    if (rank != null) count++;
    if (role != null) count++;
    return count;
  }

  ScoreRule copyWith({
    String? categoryId,
    bool? awarded,
    String? awardLevel,
    String? rank,
    String? role,
    double? points,
  }) {
    return ScoreRule(
      categoryId: categoryId ?? this.categoryId,
      awarded: awarded ?? this.awarded,
      awardLevel: awardLevel ?? this.awardLevel,
      rank: rank ?? this.rank,
      role: role ?? this.role,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'awarded': awarded,
        if (awardLevel != null) 'awardLevel': awardLevel,
        if (rank != null) 'rank': rank,
        if (role != null) 'role': role,
        'points': points,
      };

  factory ScoreRule.fromJson(Map<String, dynamic> json) => ScoreRule(
        categoryId: json['categoryId'] as String,
        awarded: json['awarded'] as bool? ?? false,
        awardLevel: json['awardLevel'] as String?,
        rank: json['rank'] as String?,
        role: json['role'] as String?,
        points: (json['points'] as num).toDouble(),
      );
}

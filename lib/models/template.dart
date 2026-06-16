import 'category.dart';
import 'score_rule.dart';

/// 综测模板。定义分类、获奖级别、名次、角色及其对应分数。
/// 模板是软件的核心配置，记录功能完全依赖模板进行计分。
class Template {
  final String id;
  final String name;
  final int version;

  /// 是否对不同角色进行区分（团队荣誉时是否需要选择角色）。
  final bool distinguishRoles;

  final List<ActivityCategory> categories;

  /// 获奖级别列表：国家级、省级、校级、院级…
  final List<String> awardLevels;

  /// 名次列表：一等奖、二等奖、三等奖…
  final List<String> ranks;

  /// 角色列表：队长、第一队员、第二队员…
  final List<String> roles;

  final List<ScoreRule> scoreRules;

  /// 最后修改时间。多设备同步时整模板按"较新者胜"。
  final DateTime updatedAt;

  Template({
    required this.id,
    required this.name,
    this.version = 1,
    this.distinguishRoles = false,
    this.categories = const [],
    this.awardLevels = const [],
    this.ranks = const [],
    this.roles = const [],
    this.scoreRules = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 学年分数上限 = 各分类活动上限之和。学年不再单独存储上限，统一由模板派生。
  double get yearScoreCap =>
      categories.fold<double>(0, (sum, c) => sum + c.yearCap);

  ActivityCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Template copyWith({
    String? name,
    int? version,
    bool? distinguishRoles,
    List<ActivityCategory>? categories,
    List<String>? awardLevels,
    List<String>? ranks,
    List<String>? roles,
    List<ScoreRule>? scoreRules,
    DateTime? updatedAt,
  }) {
    return Template(
      id: id,
      name: name ?? this.name,
      version: version ?? this.version,
      distinguishRoles: distinguishRoles ?? this.distinguishRoles,
      categories: categories ?? this.categories,
      awardLevels: awardLevels ?? this.awardLevels,
      ranks: ranks ?? this.ranks,
      roles: roles ?? this.roles,
      scoreRules: scoreRules ?? this.scoreRules,
      // copyWith 视为一次编辑，默认刷新修改时间。
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'distinguishRoles': distinguishRoles,
        'categories': categories.map((e) => e.toJson()).toList(),
        'awardLevels': awardLevels,
        'ranks': ranks,
        'roles': roles,
        'scoreRules': scoreRules.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Template.fromJson(Map<String, dynamic> json) => Template(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as int? ?? 1,
        distinguishRoles: json['distinguishRoles'] as bool? ?? false,
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => ActivityCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        awardLevels: (json['awardLevels'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        ranks: (json['ranks'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        scoreRules: (json['scoreRules'] as List<dynamic>? ?? [])
            .map((e) => ScoreRule.fromJson(e as Map<String, dynamic>))
            .toList(),
        // 旧模板无 updatedAt：回退到 epoch，使带真实时间戳的模板在合并时胜出。
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
}

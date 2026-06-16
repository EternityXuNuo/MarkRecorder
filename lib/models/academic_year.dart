/// 学年。一级分类，包含归档状态。
/// 学年分数上限不再存储于此，而是由模板派生（各分类活动上限之和）。
class AcademicYear {
  final String id;
  final String name;

  /// 是否已归档。归档后不在记录页显示，仅在归档页显示。
  final bool archived;

  /// 排序值，越大越新，最新的学年显示在最上方。
  final int order;

  final DateTime createdAt;

  /// 最后修改时间。用于多设备同步时按"较新者胜"合并。
  final DateTime updatedAt;

  AcademicYear({
    required this.id,
    required this.name,
    this.archived = false,
    required this.order,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  AcademicYear copyWith({
    String? name,
    bool? archived,
    int? order,
    DateTime? updatedAt,
  }) {
    return AcademicYear(
      id: id,
      name: name ?? this.name,
      archived: archived ?? this.archived,
      order: order ?? this.order,
      createdAt: createdAt,
      // copyWith 视为一次编辑，默认刷新修改时间。
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'archived': archived,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AcademicYear.fromJson(Map<String, dynamic> json) => AcademicYear(
        id: json['id'] as String,
        name: json['name'] as String,
        archived: json['archived'] as bool? ?? false,
        order: json['order'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}

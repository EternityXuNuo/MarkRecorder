import 'attachment.dart';

/// 活动记录。
class ActivityRecord {
  final String id;

  /// 活动名称（必填）。
  final String name;

  /// 所属学年 id。
  final String yearId;

  /// 活动分类 id；为 null 表示"未分类"。
  final String? categoryId;

  /// 是否获奖。
  final bool awarded;

  /// 获奖级别（国家级/省级…），仅 awarded 为 true 时有值。
  final String? awardLevel;

  /// 名次（一等奖/二等奖…），仅 awarded 为 true 时有值。
  final String? rank;

  /// 是否团队荣誉。
  final bool isTeam;

  /// 团队角色（队长/第一队员…），仅 isTeam 且模板区分角色时有值。
  final String? role;

  final List<Attachment> attachments;

  /// 备注。
  final String? note;

  final DateTime createdAt;

  /// 最后修改时间。用于多设备同步时按"较新者胜"合并。
  /// 旧数据缺该字段时回退为 [createdAt]。
  final DateTime updatedAt;

  ActivityRecord({
    required this.id,
    required this.name,
    required this.yearId,
    this.categoryId,
    this.awarded = false,
    this.awardLevel,
    this.rank,
    this.isTeam = false,
    this.role,
    this.attachments = const [],
    this.note,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  bool get hasAttachment => attachments.isNotEmpty;

  ActivityRecord copyWith({
    String? name,
    String? yearId,
    String? categoryId,
    bool clearCategory = false,
    bool? awarded,
    String? awardLevel,
    bool clearAwardLevel = false,
    String? rank,
    bool clearRank = false,
    bool? isTeam,
    String? role,
    bool clearRole = false,
    List<Attachment>? attachments,
    String? note,
    DateTime? updatedAt,
  }) {
    return ActivityRecord(
      id: id,
      name: name ?? this.name,
      yearId: yearId ?? this.yearId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      awarded: awarded ?? this.awarded,
      awardLevel: clearAwardLevel ? null : (awardLevel ?? this.awardLevel),
      rank: clearRank ? null : (rank ?? this.rank),
      isTeam: isTeam ?? this.isTeam,
      role: clearRole ? null : (role ?? this.role),
      attachments: attachments ?? this.attachments,
      note: note ?? this.note,
      createdAt: createdAt,
      // copyWith 视为一次编辑，默认刷新修改时间。
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'yearId': yearId,
        if (categoryId != null) 'categoryId': categoryId,
        'awarded': awarded,
        if (awardLevel != null) 'awardLevel': awardLevel,
        if (rank != null) 'rank': rank,
        'isTeam': isTeam,
        if (role != null) 'role': role,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        if (note != null) 'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ActivityRecord.fromJson(Map<String, dynamic> json) => ActivityRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        yearId: json['yearId'] as String,
        categoryId: json['categoryId'] as String?,
        awarded: json['awarded'] as bool? ?? false,
        awardLevel: json['awardLevel'] as String?,
        rank: json['rank'] as String?,
        isTeam: json['isTeam'] as bool? ?? false,
        role: json['role'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}

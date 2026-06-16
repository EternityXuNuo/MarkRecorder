/// 删除墓碑：记录"某实体（学年 / 活动记录）在某时刻被删除"。
/// 双向合并时用它压制已删实体的"复活"——否则一端删除、另一端仍存在，
/// 合并后会被重新加回来。
class Tombstone {
  final String id;
  final DateTime deletedAt;

  const Tombstone(this.id, this.deletedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': deletedAt.toIso8601String(),
      };

  factory Tombstone.fromJson(Map<String, dynamic> json) => Tombstone(
        json['id'] as String,
        DateTime.parse(json['at'] as String),
      );
}

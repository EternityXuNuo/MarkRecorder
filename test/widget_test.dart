import 'package:flutter_test/flutter_test.dart';

import 'package:mark_recoder/models/activity_record.dart';
import 'package:mark_recoder/services/default_template.dart';
import 'package:mark_recoder/services/scoring.dart';

void main() {
  test('计分引擎按规则匹配分数', () {
    final template = buildDefaultTemplate();
    final scoring = Scoring(template);
    final innov = template.categories.firstWhere((c) => c.name == '创新素养');

    final record = ActivityRecord(
      id: '1',
      name: '挑战杯',
      yearId: 'y1',
      categoryId: innov.id,
      awarded: true,
      awardLevel: '国家级',
      rank: '一等奖',
      createdAt: DateTime.now(),
    );

    expect(scoring.scoreOf(record), 10);
  });

  test('未分类记录计分为 0', () {
    final scoring = Scoring(buildDefaultTemplate());
    final record = ActivityRecord(
      id: '2',
      name: '随手记',
      yearId: 'y1',
      createdAt: DateTime.now(),
    );
    expect(scoring.scoreOf(record), 0);
  });

  test('学年总分按分类上限截断', () {
    final template = buildDefaultTemplate();
    final scoring = Scoring(template);
    final phys = template.categories.firstWhere((c) => c.name == '身心素养');

    // 身心素养上限 15，未获奖每条 1 分，造 30 条 -> 截断到 15。
    final records = [
      for (var i = 0; i < 30; i++)
        ActivityRecord(
          id: 'r$i',
          name: '打卡$i',
          yearId: 'y1',
          categoryId: phys.id,
          createdAt: DateTime.now(),
        )
    ];
    expect(scoring.yearTotal(records), 15);
  });
}

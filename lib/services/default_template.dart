import '../models/category.dart';
import '../models/score_rule.dart';
import '../models/template.dart';

/// 内置默认模板，便于首次启动即可使用，也可作为编辑模板的范例。
/// 配色参考 Figma 设计：柔和饱和的卡片色。
Template buildDefaultTemplate() {
  const physId = 'cat_physical'; // 身心素养
  const artId = 'cat_art'; // 文艺素养
  const laborId = 'cat_labor'; // 劳动素养
  const innovId = 'cat_innov'; // 创新素养

  final categories = <ActivityCategory>[
    const ActivityCategory(
      id: physId,
      name: '身心素养',
      color: 0xFF90D8FF, // 蓝（Figma）
      yearCap: 25,
      hint: '体育锻炼、心理健康、健康打卡等',
    ),
    const ActivityCategory(
      id: artId,
      name: '文艺素养',
      color: 0xFFFF9092, // 红（Figma）
      yearCap: 25,
      hint: '文艺比赛、演出、艺术类活动',
    ),
    const ActivityCategory(
      id: laborId,
      name: '劳动素养',
      color: 0xFF909BFF, // 靛蓝（Figma）
      yearCap: 25,
      hint: '社会实践、志愿服务、劳动周等',
    ),
    const ActivityCategory(
      id: innovId,
      name: '创新素养',
      color: 0xFFF290FF, // 紫（Figma）
      yearCap: 25,
      hint: '学科竞赛、创新创业、科研活动',
    ),
  ];

  const awardLevels = ['国家级', '省级', '校级', '院级'];
  const ranks = ['一等奖', '二等奖', '三等奖', '优秀奖'];
  const roles = ['队长', '第一队员', '第二队员', '其他成员'];

  final rules = <ScoreRule>[
    // 创新素养——获奖
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '国家级', rank: '一等奖', points: 10),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '国家级', rank: '二等奖', points: 8),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '省级', rank: '一等奖', points: 6),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '省级', rank: '二等奖', points: 4),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '校级', rank: '一等奖', points: 3),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '校级', rank: '二等奖', points: 2),
    const ScoreRule(categoryId: innovId, awarded: false, points: 1),
    // 文艺素养
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '校级', rank: '一等奖', points: 3),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '校级', rank: '二等奖', points: 2),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '院级', points: 1.5),
    const ScoreRule(categoryId: artId, awarded: false, points: 1),
    // 劳动素养
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '校级', points: 3),
    const ScoreRule(categoryId: laborId, awarded: false, points: 2),
    // 身心素养
    const ScoreRule(categoryId: physId, awarded: true, points: 3),
    const ScoreRule(categoryId: physId, awarded: false, points: 1),
  ];

  return Template(
    id: 'default',
    name: '默认综测模板',
    distinguishRoles: true,
    categories: categories,
    awardLevels: awardLevels,
    ranks: ranks,
    roles: roles,
    scoreRules: rules,
  );
}

import '../models/category.dart';
import '../models/score_rule.dart';
import '../models/template.dart';

/// 内置默认模板，便于首次启动即可使用，也可作为编辑模板的范例。
///
/// 框架对齐《山东大学本科生综合评价办法（试行）》附件 1.2「本科生素质能力
/// 评价实施细则」：素质能力评价成绩（100 分）= 身心素养(15) + 文艺素养(15)
/// + 劳动素养(25) + 创新素养(45)。各维度均含「基础性评价 + 成果性/突破提升」。
///
/// 注意：办法中各维度的具体赋分（赛事分级、名次、团队人数折算等）属“参照标准、
/// 由各学院根据学科特点自定”，下方分值为依据附件 1.2 参照值给出的代表性默认，
/// 实际可在「设置 > 模板设置」中按本学院实施细则调整。
/// 配色参考 Figma 设计：柔和饱和的卡片色。
Template buildDefaultTemplate() {
  const physId = 'cat_physical'; // 身心素养
  const artId = 'cat_art'; // 文艺素养
  const laborId = 'cat_labor'; // 劳动素养
  const innovId = 'cat_innov'; // 创新素养

  // 各分类上限即办法规定的维度分值；学年总分上限 = 四者之和 = 100。
  final categories = <ActivityCategory>[
    const ActivityCategory(
      id: physId,
      name: '身心素养',
      color: 0xFF90D8FF, // 蓝（Figma）
      yearCap: 15,
      hint: '体育锻炼、卫生健康等（基础性）+ 体育竞赛获奖（成果性）',
    ),
    const ActivityCategory(
      id: artId,
      name: '文艺素养',
      color: 0xFFFF9092, // 红（Figma）
      yearCap: 15,
      hint: '文艺爱好与艺术实践（基础性）+ 文艺展演/比赛获奖（成果性）',
    ),
    const ActivityCategory(
      id: laborId,
      name: '劳动素养',
      color: 0xFF909BFF, // 靛蓝（Figma）
      yearCap: 25,
      hint: '社会工作、社会实践、志愿服务、生涯发展、宿舍劳动等',
    ),
    const ActivityCategory(
      id: innovId,
      name: '创新素养',
      color: 0xFFF290FF, // 紫（Figma）
      yearCap: 45,
      hint: '科技竞赛、创新创业、科研成果、论文专利（基础）+ 学科竞赛获奖（突破提升）',
    ),
  ];

  // 等级体系取办法各表的并集：身心/文艺为国家级/省级/校级，劳动社会工作含
  // 省部级/地市级/院级，创新竞赛含国家级/省级/校级。
  const awardLevels = ['国家级', '省部级', '省级', '地市级', '校级', '院级'];
  const ranks = ['一等奖', '二等奖', '三等奖'];
  const roles = ['负责人', '主要成员', '参与成员'];

  final rules = <ScoreRule>[
    // ── 创新素养（上限 45）：突破提升——学科竞赛获奖（代表性参照值）──
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '国家级', rank: '一等奖', points: 10),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '国家级', rank: '二等奖', points: 8),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '国家级', rank: '三等奖', points: 6),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '省级', rank: '一等奖', points: 6),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '省级', rank: '二等奖', points: 4),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '省级', rank: '三等奖', points: 3),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '校级', rank: '一等奖', points: 3),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '校级', rank: '二等奖', points: 2),
    const ScoreRule(categoryId: innovId, awarded: true, awardLevel: '校级', rank: '三等奖', points: 1),
    // 基础素养：科研论文/专利/创新创业项目等参与
    const ScoreRule(categoryId: innovId, awarded: false, points: 1),

    // ── 劳动素养（上限 25）：社会工作任职/项目（按级别，参照附件 1.2）──
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '国家级', points: 10),
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '省部级', points: 8.5),
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '地市级', points: 7),
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '校级', points: 5.5),
    const ScoreRule(categoryId: laborId, awarded: true, awardLevel: '院级', points: 4),
    // 基础性：社会实践、志愿服务、生涯发展、宿舍劳动等参与
    const ScoreRule(categoryId: laborId, awarded: false, points: 2),

    // ── 文艺素养（上限 15）：成果性——文艺展演/比赛获奖（参照附件 1.2）──
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '国家级', rank: '一等奖', points: 6),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '国家级', rank: '二等奖', points: 4.5),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '省级', rank: '一等奖', points: 4.5),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '省级', rank: '二等奖', points: 3),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '校级', rank: '一等奖', points: 2.25),
    const ScoreRule(categoryId: artId, awarded: true, awardLevel: '校级', rank: '二等奖', points: 1.5),
    // 基础性：艺术爱好与文艺实践参与
    const ScoreRule(categoryId: artId, awarded: false, points: 1),

    // ── 身心素养（上限 15）：成果性——体育竞赛获奖（参照附件 1.2）──
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '国家级', rank: '一等奖', points: 6),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '国家级', rank: '二等奖', points: 5.25),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '国家级', rank: '三等奖', points: 4.5),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '省级', rank: '一等奖', points: 4.5),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '省级', rank: '二等奖', points: 3.75),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '省级', rank: '三等奖', points: 3),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '校级', rank: '一等奖', points: 2.25),
    const ScoreRule(categoryId: physId, awarded: true, awardLevel: '校级', rank: '二等奖', points: 1.5),
    // 基础性：体育锻炼、卫生健康活动参与
    const ScoreRule(categoryId: physId, awarded: false, points: 1),
  ];

  return Template(
    id: 'default',
    name: '山东大学综合评价模板',
    distinguishRoles: true,
    categories: categories,
    awardLevels: awardLevels,
    ranks: ranks,
    roles: roles,
    scoreRules: rules,
  );
}

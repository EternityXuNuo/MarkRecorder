import '../models/activity_record.dart';
import '../models/score_rule.dart';
import '../models/template.dart';

/// 计分引擎：根据模板规则计算单条记录分数、分类累计分、学年总分。
class Scoring {
  final Template template;
  const Scoring(this.template);

  /// 计算单条记录的分数（"变动"值）。
  double scoreOf(ActivityRecord r) {
    if (r.categoryId == null) return 0;
    ScoreRule? best;
    for (final rule in template.scoreRules) {
      if (rule.categoryId != r.categoryId) continue;
      if (rule.awarded != r.awarded) continue;
      if (r.awarded) {
        if (rule.awardLevel != null && rule.awardLevel != r.awardLevel) {
          continue;
        }
        if (rule.rank != null && rule.rank != r.rank) continue;
      }
      // 角色匹配：仅当规则指定了角色时才要求相等。
      if (rule.role != null) {
        if (!r.isTeam || rule.role != r.role) continue;
      }
      if (best == null || rule.specificity > best.specificity) {
        best = rule;
      }
    }
    return best?.points ?? 0;
  }

  /// 某学年内某分类的累计分（未截断，用于记录条目展示的 "8" ）。
  double categoryCumulative(
    List<ActivityRecord> recordsInYear,
    String categoryId,
  ) {
    double sum = 0;
    for (final r in recordsInYear) {
      if (r.categoryId == categoryId) sum += scoreOf(r);
    }
    return sum;
  }

  /// 截止到某条记录（含）的分类累计分。recordsInYear 需已按时间升序排列。
  double categoryCumulativeUpTo(
    List<ActivityRecord> recordsInYearAsc,
    ActivityRecord target,
  ) {
    double sum = 0;
    for (final r in recordsInYearAsc) {
      if (r.categoryId == target.categoryId) {
        sum += scoreOf(r);
      }
      if (r.id == target.id) break;
    }
    return sum;
  }

  /// 学年当前总分：各分类累计分按该分类上限截断后求和；未分类记录直接累加。
  /// 该值允许超过学年分数上限。
  double yearTotal(List<ActivityRecord> recordsInYear) {
    final byCategory = <String, double>{};
    double uncategorized = 0;
    for (final r in recordsInYear) {
      final s = scoreOf(r);
      if (r.categoryId == null) {
        uncategorized += s;
      } else {
        byCategory[r.categoryId!] = (byCategory[r.categoryId!] ?? 0) + s;
      }
    }
    double total = uncategorized;
    byCategory.forEach((catId, sum) {
      final cat = template.categoryById(catId);
      if (cat != null) {
        total += sum > cat.yearCap ? cat.yearCap : sum;
      } else {
        total += sum;
      }
    });
    return total;
  }
}

/// 格式化分数为去除多余小数的字符串：3 -> "3"，3.5 -> "3.5"。
String formatScore(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// 带符号的变动值："+3"、"-2"、"0"。
String formatDelta(double v) {
  final s = formatScore(v.abs());
  if (v > 0) return '+$s';
  if (v < 0) return '-$s';
  return '+0';
}

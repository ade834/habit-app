import 'daily_records.dart';
import 'habit.dart';

enum HabitCategory { normal, periodic, starred }

HabitCategory habitCategory(String habitId, Set<String> starredHabitIds) =>
    starredHabitIds.contains(habitId)
    ? HabitCategory.starred
    : isPeriodicHabit(habitId)
    ? HabitCategory.periodic
    : HabitCategory.normal;

class MonthlyReflection {
  const MonthlyReflection({
    required this.completionCounts,
    required this.observedDays,
    required this.totalCompletions,
    required this.totalPoints,
    required this.bestHabitIds,
    required this.hardHabitIds,
    required this.progressAreas,
    required this.encouragement,
    required this.categoryAverages,
    required this.categoryInsight,
  });

  final Map<String, int> completionCounts;
  final int observedDays;
  final int totalCompletions;
  final int totalPoints;
  final List<String> bestHabitIds;
  final List<String> hardHabitIds;
  final List<String> progressAreas;
  final String encouragement;
  final Map<HabitCategory, double> categoryAverages;
  final String categoryInsight;
}

const habitProgressAreas = {
  'H1': '觉察与决策',
  'H2': '专注与思考',
  'H3': '勇气与行动',
  'H4': '边界与休息',
};

MonthlyReflection buildMonthlyReflection({
  required List<DailyRecordSummary> summaries,
  required Set<String> selectedHabitIds,
  required DateTime month,
  DateTime? today,
  Set<String> starredHabitIds = const {},
}) {
  final current = today ?? DateTime.now();
  final lastDay = DateTime(month.year, month.month + 1, 0);
  final observedEnd = month.year == current.year && month.month == current.month
      ? DateTime(current.year, current.month, current.day)
      : lastDay;
  final observedDays = observedEnd.day;
  final counts = <String, int>{
    for (final habitId in selectedHabitIds) habitId: 0,
  };
  var totalPoints = 0;
  var totalCompletions = 0;
  for (final summary in summaries) {
    if (summary.date.isAfter(observedEnd)) continue;
    totalPoints += summary.points;
    for (final habitId in summary.completedHabitIds) {
      if (!selectedHabitIds.contains(habitId)) continue;
      counts[habitId] = (counts[habitId] ?? 0) + 1;
      totalCompletions++;
    }
  }
  if (counts.isEmpty) {
    return const MonthlyReflection(
      completionCounts: {},
      observedDays: 0,
      totalCompletions: 0,
      totalPoints: 0,
      bestHabitIds: [],
      hardHabitIds: [],
      progressAreas: [],
      encouragement: '先选择一个想照顾的习惯，这个月就从今天开始。',
      categoryAverages: {},
      categoryInsight: '先积累几次完成记录，再比较自己更稳定的习惯类型。',
    );
  }
  final highest = counts.values.reduce((a, b) => a > b ? a : b);
  final best = counts.entries
      .where((entry) => entry.value == highest)
      .map((entry) => entry.key)
      .toList();
  final closedMonth =
      month.year < current.year ||
      (month.year == current.year && month.month < current.month);
  final hardCandidates = counts.entries.where(
    (entry) =>
        !starredHabitIds.contains(entry.key) &&
        (!isPeriodicHabit(entry.key) || closedMonth),
  );
  final hardLowest = hardCandidates.isEmpty
      ? null
      : hardCandidates
            .map((entry) => entry.value)
            .reduce((a, b) => a < b ? a : b);
  final hard = hardCandidates
      .where((entry) => entry.value == hardLowest)
      .map((entry) => entry.key)
      .toList();
  final areas = best
      .map((habitId) => habitProgressAreas[habitId])
      .whereType<String>()
      .toSet()
      .toList();
  final categoryTotals = <HabitCategory, int>{};
  final categoryHabitCounts = <HabitCategory, int>{};
  for (final entry in counts.entries) {
    final category = habitCategory(entry.key, starredHabitIds);
    categoryTotals[category] = (categoryTotals[category] ?? 0) + entry.value;
    categoryHabitCounts[category] = (categoryHabitCounts[category] ?? 0) + 1;
  }
  final categoryAverages = {
    for (final category in categoryTotals.keys)
      category: categoryTotals[category]! / categoryHabitCounts[category]!,
  };
  final strongestCategory = categoryAverages.entries
      .fold<MapEntry<HabitCategory, double>?>(
        null,
        (best, entry) =>
            best == null || entry.value > best.value ? entry : best,
      );
  final categoryInsight = totalCompletions == 0
      ? '还没有完成记录，先从一个最容易开始的动作建立样本。'
      : switch (strongestCategory?.key) {
          HabitCategory.normal =>
            '普通习惯的平均完成次数最高，说明你更擅长稳定的日常节律；优先把这类节律复制到较难的习惯。',
          HabitCategory.periodic =>
            '周期习惯的平均完成次数最高，说明你擅长安排阶段性事项；继续提前预留本周或本月的执行时间。',
          HabitCategory.starred =>
            '星标习惯的平均完成次数最高，说明你能守住长期优先项；它们不加积分，依然值得作为稳定锚点。',
          null => '继续积累记录，才能形成可靠的类型比较。',
        };
  final encouragement = switch (totalCompletions) {
    0 => '这个月还没有留下完成记录，不用责怪自己。挑一个最小动作，今天重新开始。',
    <= 3 => '你已经开始留下证据了。小小的重复，会慢慢变成更稳的自己。',
    <= 10 => '你正在把坚持变成日常。下个月继续守住最容易做到的那一步。',
    _ => '这份记录很有分量。你不是靠某一天的冲劲，而是在给生活持续加一点复利。',
  };
  return MonthlyReflection(
    completionCounts: counts,
    observedDays: observedDays,
    totalCompletions: totalCompletions,
    totalPoints: totalPoints,
    bestHabitIds: best,
    hardHabitIds: hard,
    progressAreas: areas,
    encouragement: encouragement,
    categoryAverages: categoryAverages,
    categoryInsight: categoryInsight,
  );
}

class HabitDefinition {
  const HabitDefinition({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

const firstHabits = [
  HabitDefinition(id: 'H1', name: '每天100字复盘', description: '写下一个决定、一个结果、一个改进。'),
  HabitDefinition(id: 'H2', name: '30分钟深度思考', description: '给自己30分钟不被打断的时间。'),
  HabitDefinition(id: 'H3', name: '做一件不舒服的事', description: '舒适区外一小步，才是真正的成长区。'),
  HabitDefinition(id: 'H4', name: '睡前断网', description: '给大脑一个真正安静的收尾。'),
];

const laterHabits = [
  HabitDefinition(id: 'H5', name: '每周联系一位旧友', description: '真诚联系一位久未联系的人。'),
  HabitDefinition(id: 'H6', name: '管理信息摄入', description: '清理一个低价值信息源。'),
  HabitDefinition(id: 'H7', name: '每周财务盘点', description: '看清本周的资产投入与消费消耗。'),
  HabitDefinition(id: 'H8', name: '勇敢说不', description: '为重要的事守住一次边界。'),
  HabitDefinition(id: 'H9', name: '建立知识输出', description: '把一个概念讲成别人能听懂的话。'),
  HabitDefinition(
    id: 'H10',
    name: '每月读一本跨界硬核书',
    description: '用跨界知识拓宽自己的认知边界。',
  ),
  HabitDefinition(id: 'H11', name: '每年一次独自旅行', description: '独自走进陌生环境，重新看见自己。'),
  HabitDefinition(id: 'H12', name: '每天一句冷酷真话', description: '诚实面对今天正在逃避的事。'),
];

const allHabits = [...firstHabits, ...laterHabits];

const periodicHabitIds = {'H5', 'H7', 'H10', 'H11'};

bool exceedsStarredHabitLimit(Set<String> habitIds, int limit) =>
    habitIds.length > limit;

bool canStarHabit(Set<String> starredHabitIds, String habitId, int limit) =>
    starredHabitIds.contains(habitId) || starredHabitIds.length < limit;

bool isSamePeriodicCycle(String habitId, DateTime first, DateTime second) {
  if (habitId == 'H10') {
    return first.year == second.year && first.month == second.month;
  }
  if (habitId == 'H11') return first.year == second.year;
  if (habitId == 'H5' || habitId == 'H7') {
    DateTime monday(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      return day.subtract(Duration(days: day.weekday - 1));
    }

    return monday(first) == monday(second);
  }
  return false;
}

bool isPeriodicHabit(String habitId) => periodicHabitIds.contains(habitId);

bool countsTowardsRegularQuota({
  required String habitId,
  required bool isStarred,
  required DateTime? activeOn,
  required DateTime now,
}) {
  if (isStarred) return false;
  return !isPeriodicHabit(habitId) ||
      activeOn == null ||
      !isSamePeriodicCycle(habitId, activeOn, now);
}

HabitDefinition habitById(String id) => allHabits.firstWhere(
  (habit) => habit.id == id,
  orElse: () => HabitDefinition(id: id, name: id, description: ''),
);

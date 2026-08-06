enum GrowthStage { seed, sprout, growing, flowering, flourishing }

class GrowthStageDefinition {
  const GrowthStageDefinition({
    required this.stage,
    required this.label,
    required this.threshold,
    required this.description,
  });

  final GrowthStage stage;
  final String label;
  final int threshold;
  final String description;
}

const growthStages = [
  GrowthStageDefinition(
    stage: GrowthStage.seed,
    label: '种子',
    threshold: 0,
    description: '一颗还没发芽的种子，在等你第一次坚持。',
  ),
  GrowthStageDefinition(
    stage: GrowthStage.sprout,
    label: '发芽',
    threshold: 3,
    description: '冒出了第一片叶子，是你这几天攒下来的。',
  ),
  GrowthStageDefinition(
    stage: GrowthStage.growing,
    label: '成长',
    threshold: 10,
    description: '长出了茎干，能感觉到它在往上够。',
  ),
  GrowthStageDefinition(
    stage: GrowthStage.flowering,
    label: '开花',
    threshold: 25,
    description: '开花了。这是你陪它走过25次的样子。',
  ),
  GrowthStageDefinition(
    stage: GrowthStage.flourishing,
    label: '繁茂',
    threshold: 60,
    description: '枝繁叶茂，像极了坚持很久之后的你。',
  ),
];

class HabitCompletionEvent {
  const HabitCompletionEvent({required this.habitId, required this.localDate});

  final String habitId;
  final DateTime localDate;
}

class HabitGrowthState {
  const HabitGrowthState({
    required this.habitId,
    required this.historicalCompletions,
    required this.currentProgress,
    required this.stageIndex,
    required this.isDormant,
    required this.recoveryDays,
    required this.inactivityDay,
  });

  final String habitId;
  final int historicalCompletions;
  final int currentProgress;
  final int stageIndex;
  final bool isDormant;
  final int recoveryDays;
  final int inactivityDay;

  GrowthStageDefinition get stage => growthStages[stageIndex];
  GrowthStageDefinition? get nextStage => stageIndex + 1 < growthStages.length
      ? growthStages[stageIndex + 1]
      : null;

  int get remainingToNext => nextStage == null
      ? 0
      : (nextStage!.threshold - currentProgress).clamp(0, 1 << 31);

  double get stageProgress {
    final next = nextStage;
    if (next == null) return 1;
    final width = next.threshold - stage.threshold;
    return ((currentProgress - stage.threshold) / width).clamp(0.0, 1.0);
  }

  bool get shouldWarnDormancy => !isDormant && inactivityDay >= 6;
}

class GrowthSnapshot {
  const GrowthSnapshot({
    required this.habits,
    required this.chapterTwoUnlocked,
  });

  final Map<String, HabitGrowthState> habits;
  final bool chapterTwoUnlocked;
}

GrowthSnapshot calculateGrowthSnapshot({
  required Map<String, DateTime> enabledAtByHabit,
  required List<HabitCompletionEvent> completions,
  required DateTime today,
}) {
  final day = _dateOnly(today);
  final habitIds = enabledAtByHabit.keys.toSet();
  final progress = {for (final id in habitIds) id: 0};
  final historical = {for (final id in habitIds) id: 0};
  final eventsByDay = <DateTime, List<HabitCompletionEvent>>{};
  for (final event in completions) {
    final eventDay = _dateOnly(event.localDate);
    eventsByDay.putIfAbsent(eventDay, () => []).add(event);
    if (habitIds.contains(event.habitId)) {
      historical[event.habitId] = (historical[event.habitId] ?? 0) + 1;
    }
  }

  final chapterTwoUnlocked = completions.length >= 6;
  if (habitIds.isEmpty) {
    return GrowthSnapshot(
      habits: const {},
      chapterTwoUnlocked: chapterTwoUnlocked,
    );
  }

  var cursor = enabledAtByHabit.values
      .map(_dateOnly)
      .reduce((first, next) => first.isBefore(next) ? first : next);
  if (eventsByDay.isNotEmpty) {
    final firstEvent = eventsByDay.keys.reduce(
      (first, next) => first.isBefore(next) ? first : next,
    );
    if (firstEvent.isBefore(cursor)) cursor = firstEvent;
  }

  var dormant = false;
  var recovering = false;
  var recoveryDays = 0;
  var inactivityDays = 0;
  var decayDay = 0;
  var isInitialDay = true;

  while (!cursor.isAfter(day)) {
    final events = eventsByDay[cursor] ?? const <HabitCompletionEvent>[];
    final hasActivity = events.isNotEmpty;

    for (final event in events) {
      if (!habitIds.contains(event.habitId)) continue;
      progress[event.habitId] = (progress[event.habitId] ?? 0) + 1;
    }

    if (hasActivity) {
      inactivityDays = 0;
      if (dormant) {
        recovering = true;
        recoveryDays++;
        if (recoveryDays >= 3) {
          dormant = false;
          recovering = false;
          recoveryDays = 0;
          decayDay = 0;
        }
      }
    } else if (cursor.isBefore(day) && !isInitialDay) {
      inactivityDays++;
      if (recovering && inactivityDays >= 7) {
        recovering = false;
        recoveryDays = 0;
        dormant = true;
        decayDay = 0;
      } else if (!dormant && inactivityDays >= 7) {
        dormant = true;
        decayDay = 0;
      } else if (dormant && !recovering) {
        decayDay++;
        final deduction = decayDay.isOdd ? 1 : 2;
        for (final id in habitIds) {
          progress[id] = ((progress[id] ?? 0) - deduction).clamp(0, 1 << 31);
        }
      }
    }

    isInitialDay = false;
    cursor = cursor.add(const Duration(days: 1));
  }

  final currentDayHasActivity = (eventsByDay[day] ?? const []).isNotEmpty;
  final warningDay = currentDayHasActivity || dormant
      ? 0
      : (inactivityDays + 1).clamp(0, 7);
  final states = <String, HabitGrowthState>{};
  for (final id in habitIds) {
    final value = progress[id] ?? 0;
    states[id] = HabitGrowthState(
      habitId: id,
      historicalCompletions: historical[id] ?? 0,
      currentProgress: value,
      stageIndex: _stageIndex(value),
      isDormant: dormant,
      recoveryDays: recovering ? recoveryDays : 0,
      inactivityDay: warningDay,
    );
  }
  return GrowthSnapshot(habits: states, chapterTwoUnlocked: chapterTwoUnlocked);
}

int _stageIndex(int progress) {
  for (var index = growthStages.length - 1; index >= 0; index--) {
    if (progress >= growthStages[index].threshold) return index;
  }
  return 0;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

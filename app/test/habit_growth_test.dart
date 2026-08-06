import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/domain/habit_growth.dart';

void main() {
  GrowthSnapshot snapshotFor(
    int completionCount, {
    DateTime? today,
    List<HabitCompletionEvent>? completions,
  }) {
    final start = DateTime(2026, 1, 1);
    return calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': start},
      completions:
          completions ??
          [
            for (var index = 0; index < completionCount; index++)
              HabitCompletionEvent(
                habitId: 'H1',
                localDate: start.add(Duration(days: index)),
              ),
          ],
      today: today ?? start.add(Duration(days: completionCount)),
    );
  }

  test('成长阶段按0/3/10/25/60推进', () {
    final cases = {
      0: GrowthStage.seed,
      2: GrowthStage.seed,
      3: GrowthStage.sprout,
      9: GrowthStage.sprout,
      10: GrowthStage.growing,
      24: GrowthStage.growing,
      25: GrowthStage.flowering,
      59: GrowthStage.flowering,
      60: GrowthStage.flourishing,
      61: GrowthStage.flourishing,
    };

    for (final entry in cases.entries) {
      expect(snapshotFor(entry.key).habits['H1']!.stage.stage, entry.value);
    }
  });

  test('全局连续7个完整未完成日后进入休眠并提前预警', () {
    final enabled = DateTime(2026, 8, 1);
    final day6 = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': enabled},
      completions: const [],
      today: DateTime(2026, 8, 7),
    ).habits['H1']!;
    final day7 = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': enabled},
      completions: const [],
      today: DateTime(2026, 8, 8),
    ).habits['H1']!;
    final dormant = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': enabled},
      completions: const [],
      today: DateTime(2026, 8, 9),
    ).habits['H1']!;

    expect(day6.inactivityDay, 6);
    expect(day6.shouldWarnDormancy, isTrue);
    expect(day7.inactivityDay, 7);
    expect(day7.isDormant, isFalse);
    expect(dormant.isDormant, isTrue);
  });

  test('完成任一习惯会重置全局休眠倒计数', () {
    final snapshot = calculateGrowthSnapshot(
      enabledAtByHabit: {
        'H1': DateTime(2026, 8, 1),
        'H2': DateTime(2026, 8, 1),
      },
      completions: [
        HabitCompletionEvent(habitId: 'H2', localDate: DateTime(2026, 8, 7)),
      ],
      today: DateTime(2026, 8, 10),
    );

    expect(snapshot.habits['H1']!.isDormant, isFalse);
    expect(snapshot.habits['H1']!.inactivityDay, 3);
  });

  test('休眠衰减按1/2循环且恢复首日立即冻结', () {
    final events = [
      for (var index = 0; index < 10; index++)
        HabitCompletionEvent(
          habitId: 'H1',
          localDate: DateTime(2026, 7, 1 + index),
        ),
    ];
    final firstDecay = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': DateTime(2026, 7, 1)},
      completions: events,
      today: DateTime(2026, 7, 19),
    ).habits['H1']!;
    final secondDecay = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': DateTime(2026, 7, 1)},
      completions: events,
      today: DateTime(2026, 7, 20),
    ).habits['H1']!;
    final recoveryEvents = [
      ...events,
      HabitCompletionEvent(habitId: 'H2', localDate: DateTime(2026, 7, 20)),
    ];
    final recovering = calculateGrowthSnapshot(
      enabledAtByHabit: {
        'H1': DateTime(2026, 7, 1),
        'H2': DateTime(2026, 7, 1),
      },
      completions: recoveryEvents,
      today: DateTime(2026, 7, 24),
    ).habits['H1']!;

    expect(firstDecay.currentProgress, 9);
    expect(secondDecay.currentProgress, 7);
    expect(recovering.currentProgress, 7);
    expect(recovering.recoveryDays, 1);
    expect(recovering.isDormant, isTrue);
  });

  test('3个不同自然日恢复且已衰减进度不返还', () {
    final events = [
      for (var index = 0; index < 10; index++)
        HabitCompletionEvent(
          habitId: 'H1',
          localDate: DateTime(2026, 7, 1 + index),
        ),
      for (final day in [20, 22, 24])
        HabitCompletionEvent(habitId: 'H1', localDate: DateTime(2026, 7, day)),
    ];
    final state = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': DateTime(2026, 7, 1)},
      completions: events,
      today: DateTime(2026, 7, 24),
    ).habits['H1']!;

    expect(state.isDormant, isFalse);
    expect(state.recoveryDays, 0);
    expect(state.historicalCompletions, 13);
    expect(state.currentProgress, 10);
  });

  test('恢复期再断档7天会清零恢复并重启衰减', () {
    final events = [
      for (var index = 0; index < 10; index++)
        HabitCompletionEvent(
          habitId: 'H1',
          localDate: DateTime(2026, 7, 1 + index),
        ),
      HabitCompletionEvent(habitId: 'H1', localDate: DateTime(2026, 7, 20)),
    ];
    final state = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': DateTime(2026, 7, 1)},
      completions: events,
      today: DateTime(2026, 7, 29),
    ).habits['H1']!;

    expect(state.isDormant, isTrue);
    expect(state.recoveryDays, 0);
    expect(state.currentProgress, 7);
  });

  test('所有习惯历史完成合计6次后永久解锁第二章', () {
    final completions = [
      for (var day = 1; day <= 2; day++)
        for (final habitId in ['H1', 'H2', 'H3'])
          HabitCompletionEvent(
            habitId: habitId,
            localDate: DateTime(2026, 8, day),
          ),
    ];
    final snapshot = calculateGrowthSnapshot(
      enabledAtByHabit: {'H1': DateTime(2026, 8, 1)},
      completions: completions,
      today: DateTime(2026, 8, 20),
    );

    expect(snapshot.chapterTwoUnlocked, isTrue);
    expect(snapshot.habits['H1']!.currentProgress, lessThan(2));
  });
}

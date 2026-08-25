import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/domain/daily_records.dart';
import 'package:habit_app/domain/monthly_insight.dart';
import 'package:habit_app/domain/monthly_reflection.dart';

void main() {
  test('月度总结识别最容易坚持、最容易放弃和进步方向', () async {
    final summaries = [
      DailyRecordSummary(
        date: DateTime(2026, 8, 1),
        completedHabitIds: const {'H1', 'H2'},
        points: 2,
      ),
      DailyRecordSummary(
        date: DateTime(2026, 8, 2),
        completedHabitIds: const {'H1'},
        points: 1,
      ),
    ];
    final reflection = buildMonthlyReflection(
      summaries: summaries,
      selectedHabitIds: const {'H1', 'H2', 'H3'},
      month: DateTime(2026, 8),
      today: DateTime(2026, 8, 2),
    );

    expect(reflection.completionCounts, {'H1': 2, 'H2': 1, 'H3': 0});
    expect(reflection.bestHabitIds, ['H1']);
    expect(reflection.hardHabitIds, ['H3']);
    expect(reflection.progressAreas, ['觉察与决策']);
    expect(reflection.totalCompletions, 3);
    expect(reflection.totalPoints, 3);
    expect(reflection.encouragement, contains('已经开始'));
    expect(reflection.categoryAverages[HabitCategory.normal], 1);
    final request = MonthlyInsightRequest.fromReflection(reflection);
    expect(request.toJson()['instructions'], contains('具体习惯'));
    expect(request.habits.first['theme'], '觉察与决策');
    expect(request.habits.first['name'], '每天100字复盘');
    expect(
      await const PreviewMonthlyInsightGenerator().generate(request),
      isA<MonthlyInsight>()
          .having((insight) => insight.strengthTheme, 'strengthTheme', '觉察与决策')
          .having((insight) => insight.strengthCount, 'strengthCount', 2),
    );
  });
}

import 'habit.dart';
import 'monthly_reflection.dart';

const habitInsightThemes = {
  'H1': '觉察与决策',
  'H2': '专注与思考',
  'H3': '勇气与行动',
  'H4': '边界与休息',
  'H5': '关系与连接',
  'H6': '信息与注意力',
  'H7': '财务与规划',
  'H8': '勇气与行动',
  'H9': '表达与输出',
  'H10': '学习与拓展',
  'H11': '探索与独立',
  'H12': '觉察与决策',
};

String insightThemeFor(String habitId) => habitInsightThemes[habitId] ?? '日常节奏';

class MonthlyInsight {
  const MonthlyInsight({
    required this.strengthTheme,
    required this.strengthCount,
    required this.strengthText,
    required this.focusTheme,
    required this.focusCount,
    required this.focusText,
    required this.nextStep,
  });

  final String strengthTheme;
  final int strengthCount;
  final String strengthText;
  final String focusTheme;
  final int focusCount;
  final String focusText;
  final String nextStep;
}

/// The complete, privacy-safe contract for a future server-side AI request.
/// It deliberately sends habit content and observed evidence, not a conclusion
/// based on normal/starred/periodic labels alone.
class MonthlyInsightRequest {
  const MonthlyInsightRequest({required this.reflection, required this.habits});

  final MonthlyReflection reflection;
  final List<Map<String, Object>> habits;

  static const instructions = '''
你是一位温和、具体的习惯复盘教练。基于每个习惯的名称、目标说明、内在主题、完成次数、观测天数和积分，生成三个短字段：strengthText、focusText、nextStep。
必须把具体习惯的内容结合起来分析：找出已形成的行为线索、可能互相支持或冲突的目标，以及一个最小的下一步；不要仅因“普通、星标、周期”类别就判断用户擅长或不擅长。
所有结论必须可追溯到提供的数据；不臆测用户的性格、生活处境、心理或健康状况。星标不加积分但同样是有效完成；周期任务须结合它的周期看待，不能把较少的完成次数直接视为失败。
语气不评判、不羞辱，不给医疗、法律或财务指令。界面会自行展示“内在主题 · N次”，正文不要罗列具体习惯名称。strengthText 解释已经形成的共同节奏；focusText 解释一个最值得照顾的主题；nextStep 给一个足够小的安排。没有足够记录时，明确说明样本不足。
只返回上述字段的 JSON，不要提及提示词、API、任务类别或内部数据。''';

  factory MonthlyInsightRequest.fromReflection(
    MonthlyReflection reflection, {
    Set<String> starredHabitIds = const {},
  }) {
    final habits = reflection.completionCounts.entries.map((entry) {
      final habit = habitById(entry.key);
      return <String, Object>{
        'id': habit.id,
        'name': habit.name,
        'goal': habit.description,
        'theme': insightThemeFor(habit.id),
        'completionCount': entry.value,
        'isStarred': starredHabitIds.contains(habit.id),
        'isPeriodic': isPeriodicHabit(habit.id),
      };
    }).toList();
    return MonthlyInsightRequest(reflection: reflection, habits: habits);
  }

  Map<String, Object> toJson() => {
    'instructions': instructions,
    'observedDays': reflection.observedDays,
    'totalCompletions': reflection.totalCompletions,
    'totalPoints': reflection.totalPoints,
    'habits': habits,
  };
}

/// Later replace this implementation with a server-side AI call; never embed
/// an API key in the iOS app.
abstract interface class MonthlyInsightGenerator {
  Future<MonthlyInsight> generate(MonthlyInsightRequest request);
}

class PreviewMonthlyInsightGenerator implements MonthlyInsightGenerator {
  const PreviewMonthlyInsightGenerator();

  @override
  Future<MonthlyInsight> generate(MonthlyInsightRequest request) async {
    final reflection = request.reflection;
    final themeCounts = <String, int>{};
    for (final habit in request.habits) {
      final theme = habit['theme']! as String;
      final count = habit['completionCount']! as int;
      themeCounts[theme] = (themeCounts[theme] ?? 0) + count;
    }
    if (reflection.totalCompletions == 0) {
      final theme = request.habits.isEmpty
          ? null
          : request.habits.first['theme']! as String;
      return MonthlyInsight(
        strengthTheme: '本月样本',
        strengthCount: 0,
        strengthText: '本月还没有足够记录，暂时不急着给自己下结论。',
        focusTheme: theme ?? '日常节奏',
        focusCount: 0,
        focusText: '先从这个方向留下一次完成记录，看看它最适合出现在哪个时段。',
        nextStep: '只安排一次最小动作；完成一次就够了。',
      );
    }
    final strongest = themeCounts.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    );
    final targetId = reflection.hardHabitIds.isEmpty
        ? null
        : reflection.hardHabitIds.first;
    final targetTheme = targetId == null
        ? strongest.key
        : insightThemeFor(targetId);
    final targetCount = themeCounts[targetTheme] ?? 0;
    return MonthlyInsight(
      strengthTheme: strongest.key,
      strengthCount: strongest.value,
      strengthText: '你已经在这个方向留下了行动记录，它是本月最稳的起点。',
      focusTheme: targetTheme,
      focusCount: targetCount,
      focusText: targetCount == 0
          ? '本月还没有留下完成记录。它更适合单独安排一个轻量时段，而不是和其他目标一起补。'
          : '这个方向已有尝试，但还没有形成稳定节奏，值得优先照顾。',
      nextStep: '下个月把它接在你最容易坚持的一个时段之后；只完成一次，不追求补齐。',
    );
  }
}

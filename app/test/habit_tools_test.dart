import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/domain/habit_tools.dart';

void main() {
  test('H1去除标点和空格后计数', () {
    expect(reviewCharacterCount('你 好，世界！'), 4);
    expect(reviewMeetsTarget([List.filled(99, '我').join(), '。']), isFalse);
    expect(reviewMeetsTarget([List.filled(100, '我').join(), '。']), isTrue);
  });

  test('H1只允许今天和前3个自然日', () {
    final now = DateTime(2026, 8, 5, 23, 30);
    expect(isAllowedReviewDate(DateTime(2026, 8, 2), now), isTrue);
    expect(isAllowedReviewDate(DateTime(2026, 8, 1), now), isFalse);
    expect(isAllowedReviewDate(DateTime(2026, 8, 6), now), isFalse);
  });

  test('H2时间戳计时扣除暂停时长', () {
    final progress = timerProgress(
      startedAt: DateTime(2026, 8, 5, 10),
      now: DateTime(2026, 8, 5, 10, 35),
      accumulatedPauseSeconds: 5 * 60,
    );
    expect(progress.focusSeconds, 30 * 60);
    expect(progress.pauseSeconds, 5 * 60);
    expect(progress.meetsFocusTarget(30 * 60), isTrue);
  });

  test('H2暂停超过5分钟不达标', () {
    final progress = timerProgress(
      startedAt: DateTime(2026, 8, 5, 10),
      now: DateTime(2026, 8, 5, 10, 36),
      accumulatedPauseSeconds: 5 * 60 + 1,
    );
    expect(progress.meetsFocusTarget(30 * 60), isFalse);
  });

  test('H3挑战库包含500条不重复的安全成长小事', () {
    expect(challengeCards, hasLength(500));
    expect(challengeCards.toSet(), hasLength(500));
  });

  test('H2思考库包含365条不重复且不超过15字的议题', () {
    expect(thinkingTopicCorpus, hasLength(365));
    expect(thinkingTopicCorpus.toSet(), hasLength(365));
    expect(
      thinkingTopicCorpus.every((topic) => topic.runes.length <= 15),
      isTrue,
    );
  });

  test('H2每日稳定推荐3个不同议题', () {
    final date = DateTime(2026, 8, 5);
    final topics = dailyThinkingTopics(date);
    expect(topics, hasLength(3));
    expect(topics.toSet(), hasLength(3));
    expect(dailyThinkingTopics(date), topics);
  });
}

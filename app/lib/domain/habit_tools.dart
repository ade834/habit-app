int reviewCharacterCount(String text) {
  final punctuationOrSpace = RegExp(r'[\s\p{P}]', unicode: true);
  return text.runes
      .map(String.fromCharCode)
      .where((character) => !punctuationOrSpace.hasMatch(character))
      .length;
}

bool reviewMeetsTarget(Iterable<String> sections) =>
    reviewCharacterCount(sections.join()) >= 100;

bool isAllowedReviewDate(DateTime target, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(target.year, target.month, target.day);
  final daysAgo = today.difference(date).inDays;
  return daysAgo >= 0 && daysAgo <= 3;
}

class TimerProgress {
  const TimerProgress({required this.focusSeconds, required this.pauseSeconds});

  final int focusSeconds;
  final int pauseSeconds;

  bool meetsFocusTarget(int targetSeconds) =>
      focusSeconds >= targetSeconds && pauseSeconds <= 300;
}

TimerProgress timerProgress({
  required DateTime startedAt,
  required DateTime now,
  required int accumulatedPauseSeconds,
  DateTime? pausedAt,
}) {
  final currentPause = pausedAt == null
      ? 0
      : now.difference(pausedAt).inSeconds.clamp(0, 1 << 31);
  final pauseSeconds = accumulatedPauseSeconds + currentPause;
  final elapsedSeconds = now.difference(startedAt).inSeconds.clamp(0, 1 << 31);
  return TimerProgress(
    focusSeconds: (elapsedSeconds - pauseSeconds).clamp(0, 1 << 31),
    pauseSeconds: pauseSeconds,
  );
}

const challengeCards = [
  '给一个很久没联系的人发条消息。',
  '在会议/群里说出一个不一样的意见。',
  '拒绝一件你其实不想做的事。',
  '走一条没走过的路回家。',
  '对着镜子说一句你一直不敢承认的真话。',
];

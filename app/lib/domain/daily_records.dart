class DailyRecordSummary {
  const DailyRecordSummary({
    required this.date,
    required this.completedHabitIds,
    required this.points,
    this.review,
    this.focus,
    this.challengeCardIndex,
    this.disconnect,
    this.activities = const [],
  });

  final DateTime date;
  final Set<String> completedHabitIds;
  final int points;
  final ReviewRecord? review;
  final FocusRecord? focus;
  final int? challengeCardIndex;
  final DisconnectRecord? disconnect;
  final List<HabitActivityRecord> activities;

  bool get hasAnyRecord =>
      completedHabitIds.isNotEmpty ||
      points > 0 ||
      review != null ||
      focus != null ||
      challengeCardIndex != null ||
      disconnect != null ||
      activities.isNotEmpty;
}

class HabitActivityRecord {
  const HabitActivityRecord({
    required this.habitId,
    required this.primaryText,
    required this.secondaryText,
    this.firstValue,
    this.secondValue,
  });

  final String habitId;
  final String primaryText;
  final String secondaryText;
  final double? firstValue;
  final double? secondValue;

  String get brief =>
      secondaryText.isEmpty ? primaryText : '$primaryText · $secondaryText';

  String get shortTitle {
    final title = primaryText.trim();
    if (title.length <= 6) return title;
    return '${title.substring(0, 6)}…';
  }
}

class ReviewRecord {
  const ReviewRecord({
    required this.decision,
    required this.result,
    required this.improvement,
  });

  final String decision;
  final String result;
  final String improvement;
}

class FocusRecord {
  const FocusRecord({
    required this.focusMinutes,
    required this.status,
    required this.topic,
  });

  final int focusMinutes;
  final String status;
  final String? topic;
}

class DisconnectRecord {
  const DisconnectRecord({required this.minutes, required this.status});

  final int minutes;
  final String status;
}

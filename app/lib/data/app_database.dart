import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/habit_growth.dart';
import '../domain/habit_tools.dart';
import '../domain/daily_records.dart';
import '../domain/habit.dart';

part 'app_database.g.dart';

class HabitSelections extends Table {
  TextColumn get habitId => text()();
  TextColumn get commitmentNote => text().withDefault(const Constant(''))();
  DateTimeColumn get enabledAt => dateTime()();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  DateTimeColumn get activeOn => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {habitId};
}

class HabitLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get habitId => text()();
  TextColumn get localDate => text()();
  IntColumn get timezoneOffsetMinutes => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {habitId, localDate},
  ];
}

class PointTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitLogId => integer().references(HabitLogs, #id).unique()();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class ReviewEntries extends Table {
  TextColumn get localDate => text()();
  TextColumn get decision => text()();
  TextColumn get result => text()();
  TextColumn get improvement => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localDate};
}

class TimerSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get habitId => text()();
  IntColumn get targetSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  IntColumn get accumulatedPauseSeconds =>
      integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('running'))();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get focusTopic => text().nullable()();
}

class ChallengeDraws extends Table {
  TextColumn get localDate => text()();
  IntColumn get cardIndex => integer()();
  BoolColumn get swapUsed => boolean().withDefault(const Constant(false))();
  IntColumn get swapCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {localDate};
}

class HabitActivityEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get habitId => text()();
  TextColumn get periodKey => text()();
  TextColumn get primaryText => text()();
  TextColumn get secondaryText => text().withDefault(const Constant(''))();
  RealColumn get firstValue => real().nullable()();
  RealColumn get secondValue => real().nullable()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {habitId, periodKey},
  ];
}

class TravelPlans extends Table {
  IntColumn get year => integer()();
  TextColumn get destination => text()();
  IntColumn get days => integer()();
  TextColumn get focus => text()();
  TextColumn get preparation => text().withDefault(const Constant(''))();
  DateTimeColumn get plannedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {year};
}

class MissedHabitRecords extends Table {
  TextColumn get habitId => text()();
  TextColumn get localDate => text()();
  TextColumn get settledOn => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {habitId, localDate};
}

@DriftDatabase(
  tables: [
    HabitSelections,
    HabitLogs,
    PointTransactions,
    ReviewEntries,
    TimerSessions,
    ChallengeDraws,
    HabitActivityEntries,
    TravelPlans,
    MissedHabitRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'habit_app'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(reviewEntries);
        await migrator.createTable(timerSessions);
        await migrator.createTable(challengeDraws);
      }
      if (from >= 2 && from < 3) {
        await migrator.addColumn(challengeDraws, challengeDraws.swapCount);
        await customStatement(
          'UPDATE challenge_draws SET swap_count = 1 WHERE swap_used = 1',
        );
      }
      if (from >= 2 && from < 4) {
        await migrator.addColumn(timerSessions, timerSessions.focusTopic);
      }
      if (from < 5) {
        await migrator.createTable(habitActivityEntries);
      }
      if (from < 6) {
        await migrator.createTable(travelPlans);
      }
      if (from < 7 && !await _hasColumn('habit_selections', 'is_starred')) {
        await migrator.addColumn(habitSelections, habitSelections.isStarred);
      }
      if (from < 8) {
        if (!await _hasColumn('habit_selections', 'active_on')) {
          await migrator.addColumn(habitSelections, habitSelections.activeOn);
        }
        await customStatement(
          'UPDATE habit_selections SET active_on = enabled_at',
        );
      }
      if (from < 9) await migrator.createTable(missedHabitRecords);
      if (from < 10) {
        if (!await _hasColumn('missed_habit_records', 'settled_on')) {
          await migrator.addColumn(
            missedHabitRecords,
            missedHabitRecords.settledOn,
          );
        }
      }
    },
  );

  Future<bool> _hasColumn(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }

  Stream<List<HabitSelection>> watchSelectedHabits() =>
      select(habitSelections).watch();

  Stream<List<HabitSelection>> watchActiveHabits({DateTime? now}) {
    final current = now ?? DateTime.now();
    final day = DateTime(current.year, current.month, current.day);
    return customSelect(
      'SELECT 1',
      readsFrom: {habitSelections, habitActivityEntries},
    ).watch().asyncMap((_) async {
      final rows = await select(habitSelections).get();
      final active = <HabitSelection>[];
      for (final row in rows) {
        final selected =
            row.isStarred ||
            isPeriodicHabit(row.habitId) ||
            (row.activeOn != null && _sameDay(row.activeOn!, day));
        if (!selected) continue;
        if (isPeriodicHabit(row.habitId)) {
          final completedAt = await _periodicCompletedAt(row.habitId, current);
          if (completedAt != null) {
            if (!_sameDay(completedAt, day)) continue;
          } else {
            final selectedThisPeriod =
                row.activeOn != null &&
                _activityPeriodKey(row.habitId, row.activeOn!) ==
                    _activityPeriodKey(row.habitId, current);
            if (!selectedThisPeriod) continue;
          }
        }
        active.add(row);
      }
      return active;
    });
  }

  Future<DateTime?> _periodicCompletedAt(String habitId, DateTime now) async {
    final periodKey = _activityPeriodKey(habitId, now);
    final entry =
        await (select(habitActivityEntries)..where(
              (row) =>
                  row.habitId.equals(habitId) & row.periodKey.equals(periodKey),
            ))
            .getSingleOrNull();
    return entry?.completedAt;
  }

  Future<Set<String>> completedPeriodicHabitIds({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final completed = <String>{};
    for (final habitId in periodicHabitIds) {
      final completedAt = await _periodicCompletedAt(habitId, current);
      if (completedAt != null && !_sameDay(completedAt, current)) {
        completed.add(habitId);
      }
    }
    return completed;
  }

  Future<void> settleMissedOrdinaryHabits({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final selections = await select(habitSelections).get();
    await transaction(() async {
      for (final selection in selections) {
        final activeOn = selection.activeOn;
        if (selection.isStarred ||
            isPeriodicHabit(selection.habitId) ||
            activeOn == null ||
            !_isBeforeDay(activeOn, today)) {
          continue;
        }
        final date = _localDate(activeOn);
        final completed =
            await (select(habitLogs)..where(
                  (log) =>
                      log.habitId.equals(selection.habitId) &
                      log.localDate.equals(date),
                ))
                .getSingleOrNull();
        if (completed == null) {
          await into(missedHabitRecords).insertOnConflictUpdate(
            MissedHabitRecordsCompanion.insert(
              habitId: selection.habitId,
              localDate: date,
            ),
          );
        }
        await (update(habitSelections)
              ..where((row) => row.habitId.equals(selection.habitId)))
            .write(const HabitSelectionsCompanion(activeOn: Value(null)));
      }
    });
  }

  Future<void> settleMissedPeriodicHabits({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final selections = await select(habitSelections).get();
    await transaction(() async {
      for (final selection in selections) {
        final activeOn = selection.activeOn;
        if (!isPeriodicHabit(selection.habitId) || activeOn == null) continue;
        if (isSamePeriodicCycle(selection.habitId, activeOn, current)) continue;
        final completedAt = await _periodicCompletedAt(
          selection.habitId,
          activeOn,
        );
        if (completedAt == null) {
          await into(missedHabitRecords).insertOnConflictUpdate(
            MissedHabitRecordsCompanion.insert(
              habitId: selection.habitId,
              localDate: _localDate(_periodEnd(selection.habitId, activeOn)),
              settledOn: Value(_localDate(current)),
            ),
          );
        }
        await (update(habitSelections)
              ..where((row) => row.habitId.equals(selection.habitId)))
            .write(const HabitSelectionsCompanion(activeOn: Value(null)));
      }
    });
  }

  Future<int> missedHabitCountForDate(DateTime date) async {
    final key = _localDate(date);
    return (await (select(
      missedHabitRecords,
    )..where((row) => row.localDate.equals(key))).get()).length;
  }

  Future<int> settledPeriodicMissedHabitCountForDate(DateTime date) async {
    final key = _localDate(date);
    return (await (select(
      missedHabitRecords,
    )..where((row) => row.settledOn.equals(key))).get()).length;
  }

  Future<void> removeHabitFromToday(String habitId) async {
    final selection = await (select(
      habitSelections,
    )..where((row) => row.habitId.equals(habitId))).getSingleOrNull();
    if (selection == null) return;
    if (selection.isStarred || isPeriodicHabit(habitId)) {
      await (delete(
        habitSelections,
      )..where((row) => row.habitId.equals(habitId))).go();
      return;
    }
    await (update(habitSelections)..where((row) => row.habitId.equals(habitId)))
        .write(const HabitSelectionsCompanion(activeOn: Value(null)));
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(challengeDraws).go();
      await delete(habitActivityEntries).go();
      await delete(travelPlans).go();
      await delete(missedHabitRecords).go();
      await delete(timerSessions).go();
      await delete(reviewEntries).go();
      await delete(pointTransactions).go();
      await delete(habitLogs).go();
      await delete(habitSelections).go();
    });
  }

  Future<void> saveOnboarding({
    required Set<String> habitIds,
    Set<String> starredHabitIds = const {},
    required String commitmentNote,
    DateTime? now,
  }) async {
    if (habitIds.isEmpty || starredHabitIds.difference(habitIds).isNotEmpty) {
      throw ArgumentError('至少选择1个习惯，星标必须属于已选习惯');
    }
    if (starredHabitIds.isNotEmpty) {
      throw ArgumentError('首次选择不支持星标，请完成任务后再设置');
    }
    final enabledAt = now ?? DateTime.now();
    await _validateStarredHabitLimit(starredHabitIds, enabledAt);
    if (habitIds.difference(starredHabitIds).length > 3) {
      throw ArgumentError('普通习惯最多选择3个；更多习惯请设为星标');
    }
    await transaction(() async {
      await delete(habitSelections).go();
      await batch((batch) {
        batch.insertAll(
          habitSelections,
          habitIds
              .map(
                (id) => HabitSelectionsCompanion.insert(
                  habitId: id,
                  commitmentNote: Value(commitmentNote.trim()),
                  enabledAt: enabledAt,
                  isStarred: Value(starredHabitIds.contains(id)),
                  activeOn: Value(enabledAt),
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<void> replaceSelectedHabits(
    Set<String> habitIds, {
    Set<String> starredHabitIds = const {},
    DateTime? now,
  }) async {
    if (starredHabitIds.difference(habitIds).isNotEmpty) {
      throw ArgumentError('星标必须属于当天已选习惯');
    }
    final current = now ?? DateTime.now();
    await _validateStarredHabitLimit(starredHabitIds, current);
    await transaction(() async {
      final existing = await select(habitSelections).get();
      final byId = {for (final row in existing) row.habitId: row};
      final regularCount = habitIds.where((id) {
        final selection = byId[id];
        return countsTowardsRegularQuota(
          habitId: id,
          isStarred: starredHabitIds.contains(id),
          activeOn: selection?.activeOn,
          now: current,
        );
      }).length;
      if (regularCount > 3) {
        throw ArgumentError('普通习惯最多选择3个；更多习惯请设为星标');
      }
      for (final row in existing) {
        if (!habitIds.contains(row.habitId) && !row.isStarred) {
          await (update(habitSelections)
                ..where((entry) => entry.habitId.equals(row.habitId)))
              .write(const HabitSelectionsCompanion(activeOn: Value(null)));
        }
      }
      for (final id in habitIds) {
        if (byId.containsKey(id)) {
          await (update(
            habitSelections,
          )..where((entry) => entry.habitId.equals(id))).write(
            HabitSelectionsCompanion(
              isStarred: Value(starredHabitIds.contains(id)),
              activeOn: Value(current),
            ),
          );
          continue;
        }
        await into(habitSelections).insert(
          HabitSelectionsCompanion.insert(
            habitId: id,
            enabledAt: current,
            isStarred: Value(starredHabitIds.contains(id)),
            activeOn: Value(current),
          ),
        );
      }
    });
  }

  Future<void> _validateStarredHabitLimit(
    Set<String> starredHabitIds,
    DateTime now,
  ) async {
    final unlocked = (await growthSnapshot(now: now)).chapterTwoUnlocked;
    final limit = unlocked ? 2 : 1;
    if (exceedsStarredHabitLimit(starredHabitIds, limit)) {
      throw ArgumentError('当前阶段最多选择 $limit 个星标习惯');
    }
  }

  Future<bool> saveLaterHabitActivity({
    required String habitId,
    required String primaryText,
    String secondaryText = '',
    double? firstValue,
    double? secondValue,
    DateTime? now,
  }) {
    if (!const {
      'H5',
      'H6',
      'H7',
      'H8',
      'H9',
      'H10',
      'H11',
      'H12',
    }.contains(habitId)) {
      throw ArgumentError.value(habitId, 'habitId');
    }
    if (primaryText.trim().isEmpty) throw ArgumentError('请填写必填内容');
    final current = now ?? DateTime.now();
    final periodKey = _activityPeriodKey(habitId, current);
    return transaction(() async {
      final existing =
          await (select(habitActivityEntries)..where(
                (row) =>
                    row.habitId.equals(habitId) &
                    row.periodKey.equals(periodKey),
              ))
              .getSingleOrNull();
      if (existing != null) return false;
      await into(habitActivityEntries).insert(
        HabitActivityEntriesCompanion.insert(
          habitId: habitId,
          periodKey: periodKey,
          primaryText: primaryText.trim(),
          secondaryText: Value(secondaryText.trim()),
          firstValue: Value(firstValue),
          secondValue: Value(secondValue),
          completedAt: current,
        ),
      );
      return _recordCompletion(
        habitId,
        current,
        points: _laterHabitPointMultiplier(habitId),
      );
    });
  }

  int _laterHabitPointMultiplier(String habitId) => switch (habitId) {
    'H5' || 'H7' => 3,
    'H10' => 4,
    'H11' => 99,
    _ => 1,
  };

  Future<TravelPlan?> travelPlanForYear({DateTime? now}) =>
      (select(travelPlans)
            ..where((row) => row.year.equals((now ?? DateTime.now()).year)))
          .getSingleOrNull();

  Future<void> saveTravelPlan({
    required String destination,
    required int days,
    required String focus,
    String preparation = '',
    DateTime? now,
  }) async {
    if (destination.trim().isEmpty || focus.trim().isEmpty || days < 1) {
      throw ArgumentError('请完整填写旅行计划');
    }
    final current = now ?? DateTime.now();
    await into(travelPlans).insertOnConflictUpdate(
      TravelPlansCompanion.insert(
        year: Value(current.year),
        destination: destination.trim(),
        days: days,
        focus: focus.trim(),
        preparation: Value(preparation.trim()),
        plannedAt: current,
      ),
    );
  }

  String _activityPeriodKey(String habitId, DateTime date) {
    if (habitId == 'H10') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
    if (habitId == 'H11') return '${date.year}';
    if (habitId == 'H5' || habitId == 'H7') {
      final day = DateTime(date.year, date.month, date.day);
      final monday = day.subtract(Duration(days: day.weekday - 1));
      return 'week-${_localDate(monday)}';
    }
    return _localDate(date);
  }

  DateTime _periodEnd(String habitId, DateTime date) {
    if (habitId == 'H10') return DateTime(date.year, date.month + 1, 0);
    if (habitId == 'H11') return DateTime(date.year, 12, 31);
    final day = DateTime(date.year, date.month, date.day);
    return day.add(Duration(days: 7 - day.weekday));
  }

  Future<bool> recordCompletion({
    required String habitId,
    required DateTime occurredAt,
  }) {
    return transaction(() => _recordCompletion(habitId, occurredAt));
  }

  Future<bool> _recordCompletion(
    String habitId,
    DateTime occurredAt, {
    int points = 1,
  }) async {
    final selection = await (select(
      habitSelections,
    )..where((row) => row.habitId.equals(habitId))).getSingleOrNull();
    if (selection?.isStarred == true) points = 0;
    final localDate = _localDate(occurredAt);
    final existing =
        await (select(habitLogs)..where(
              (log) =>
                  log.habitId.equals(habitId) & log.localDate.equals(localDate),
            ))
            .getSingleOrNull();
    if (existing != null) return false;

    final logId = await into(habitLogs).insert(
      HabitLogsCompanion.insert(
        habitId: habitId,
        localDate: localDate,
        timezoneOffsetMinutes: occurredAt.timeZoneOffset.inMinutes,
        createdAt: occurredAt,
      ),
    );

    await into(pointTransactions).insert(
      PointTransactionsCompanion.insert(
        habitLogId: logId,
        amount: points,
        createdAt: occurredAt,
      ),
    );
    return true;
  }

  Future<bool> saveReview({
    required DateTime date,
    required String decision,
    required String result,
    required String improvement,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!isAllowedReviewDate(date, current)) {
      throw ArgumentError('只能补录前3天以内的复盘');
    }
    final localDate = _localDate(date);
    final meetsTarget = reviewMeetsTarget([decision, result, improvement]);
    return transaction(() async {
      await into(reviewEntries).insertOnConflictUpdate(
        ReviewEntriesCompanion.insert(
          localDate: localDate,
          decision: decision,
          result: result,
          improvement: improvement,
          updatedAt: current,
        ),
      );
      if (!meetsTarget || localDate != _localDate(current)) return false;
      return _recordCompletion('H1', current);
    });
  }

  Future<ReviewEntry?> reviewForDate(DateTime date) => (select(
    reviewEntries,
  )..where((row) => row.localDate.equals(_localDate(date)))).getSingleOrNull();

  Future<TimerSession> startTimer({
    required String habitId,
    required int targetSeconds,
    String? focusTopic,
    DateTime? now,
  }) async {
    final startedAt = now ?? DateTime.now();
    await (update(timerSessions)..where(
          (row) =>
              row.habitId.equals(habitId) &
              row.status.isIn(['running', 'paused']),
        ))
        .write(
          TimerSessionsCompanion(
            status: const Value('failed'),
            endedAt: Value(startedAt),
          ),
        );
    final id = await into(timerSessions).insert(
      TimerSessionsCompanion.insert(
        habitId: habitId,
        targetSeconds: targetSeconds,
        startedAt: startedAt,
        focusTopic: Value(focusTopic),
      ),
    );
    return (select(
      timerSessions,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Stream<TimerSession?> watchActiveTimer(String habitId) {
    final query = select(timerSessions)
      ..where(
        (row) =>
            row.habitId.equals(habitId) &
            row.status.isIn(['running', 'paused']),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.id)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<int> recoverInterruptedDisconnectSession({DateTime? now}) {
    final failedAt = now ?? DateTime.now();
    return (update(timerSessions)..where(
          (row) => row.habitId.equals('H4') & row.status.equals('running'),
        ))
        .write(
          TimerSessionsCompanion(
            status: const Value('failed'),
            endedAt: Value(failedAt),
          ),
        );
  }

  Stream<DisconnectAttemptState> watchDisconnectAttemptState({
    DateTime Function()? clock,
  }) {
    final query = select(timerSessions)
      ..where((row) => row.habitId.equals('H4'))
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    return query.watch().map(
      (rows) => _disconnectAttemptState(rows, (clock ?? DateTime.now)()),
    );
  }

  DisconnectAttemptState _disconnectAttemptState(
    List<TimerSession> rows,
    DateTime now,
  ) {
    var failures = 0;
    DateTime? lockedUntil;
    for (final row in rows) {
      if (row.status == 'completed') {
        failures = 0;
        lockedUntil = null;
        continue;
      }
      if (row.status != 'failed') continue;
      final failedAt = row.endedAt ?? row.startedAt;
      if (lockedUntil != null) {
        if (failedAt.isBefore(lockedUntil)) continue;
        failures = 0;
        lockedUntil = null;
      }
      failures++;
      if (failures == 3) {
        lockedUntil = failedAt.add(const Duration(hours: 10));
      }
    }
    if (lockedUntil != null && !now.isBefore(lockedUntil)) {
      return const DisconnectAttemptState(consecutiveFailures: 0);
    }
    return DisconnectAttemptState(
      consecutiveFailures: failures,
      lockedUntil: lockedUntil,
    );
  }

  Future<void> pauseTimer(int id, DateTime now) =>
      (update(timerSessions)..where((row) => row.id.equals(id))).write(
        TimerSessionsCompanion(
          status: const Value('paused'),
          pausedAt: Value(now),
        ),
      );

  Future<bool> resumeTimer(int id, DateTime now) async {
    final session = await (select(
      timerSessions,
    )..where((row) => row.id.equals(id))).getSingle();
    if (session.pausedAt == null) return true;
    final paused =
        session.accumulatedPauseSeconds +
        now.difference(session.pausedAt!).inSeconds.clamp(0, 1 << 31);
    if (paused > 300) {
      await _endTimer(id, 'failed', now);
      return false;
    }
    await (update(timerSessions)..where((row) => row.id.equals(id))).write(
      TimerSessionsCompanion(
        status: const Value('running'),
        pausedAt: const Value(null),
        accumulatedPauseSeconds: Value(paused),
      ),
    );
    return true;
  }

  Future<bool> finishFocusTimer(int id, DateTime now) {
    return transaction(() async {
      final session = await (select(
        timerSessions,
      )..where((row) => row.id.equals(id))).getSingle();
      final progress = timerProgress(
        startedAt: session.startedAt,
        now: now,
        accumulatedPauseSeconds: session.accumulatedPauseSeconds,
        pausedAt: session.pausedAt,
      );
      final completed = progress.meetsFocusTarget(session.targetSeconds);
      await _endTimer(id, completed ? 'completed' : 'failed', now);
      if (!completed) return false;
      return _recordCompletion('H2', now);
    });
  }

  Future<bool> completeDisconnectTimer(int id, DateTime now) {
    return transaction(() async {
      final session = await (select(
        timerSessions,
      )..where((row) => row.id.equals(id))).getSingle();
      if (session.habitId != 'H4' || session.status != 'running') return false;
      final completed =
          now.difference(session.startedAt).inSeconds >= session.targetSeconds;
      if (!completed) return false;
      await _endTimer(id, 'completed', now);
      return _recordCompletion('H4', now);
    });
  }

  Future<void> endTimerEarly(int id, DateTime now) =>
      _endTimer(id, 'failed', now);

  Future<void> _endTimer(int id, String status, DateTime now) =>
      (update(timerSessions)..where((row) => row.id.equals(id))).write(
        TimerSessionsCompanion(status: Value(status), endedAt: Value(now)),
      );

  Future<ChallengeDraw> challengeForToday({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final localDate = _localDate(current);
    final existing = await (select(
      challengeDraws,
    )..where((row) => row.localDate.equals(localDate))).getSingleOrNull();
    if (existing != null) return existing;
    await into(challengeDraws).insert(
      ChallengeDrawsCompanion.insert(
        localDate: localDate,
        cardIndex: current.day % challengeCards.length,
      ),
    );
    return (select(
      challengeDraws,
    )..where((row) => row.localDate.equals(localDate))).getSingle();
  }

  Future<ChallengeDraw> swapChallenge({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final draw = await challengeForToday(now: current);
    final nextCount = draw.swapCount + 1;
    final nextIndex = draw.swapCount < 3
        ? (draw.cardIndex + 5) % challengeCards.length
        : draw.swapCount % 3 == 0
        ? (draw.cardIndex - 10) % challengeCards.length
        : (draw.cardIndex + 5) % challengeCards.length;
    await (update(
      challengeDraws,
    )..where((row) => row.localDate.equals(draw.localDate))).write(
      ChallengeDrawsCompanion(
        cardIndex: Value(nextIndex),
        swapUsed: Value(nextCount >= 3),
        swapCount: Value(nextCount),
      ),
    );
    return challengeForToday(now: current);
  }

  Future<int> pointBalance() async {
    final total = pointTransactions.amount.sum();
    final row = await (selectOnly(
      pointTransactions,
    )..addColumns([total])).getSingle();
    return row.read(total) ?? 0;
  }

  Stream<Set<String>> watchTodayCompletedHabitIds({DateTime? now}) {
    final date = _localDate(now ?? DateTime.now());
    return (select(habitLogs)..where((log) => log.localDate.equals(date)))
        .watch()
        .map((rows) => rows.map((row) => row.habitId).toSet());
  }

  Stream<int> watchCompletionCount(String habitId) {
    return (select(habitLogs)..where((log) => log.habitId.equals(habitId)))
        .watch()
        .map((rows) => rows.length);
  }

  Stream<GrowthSnapshot> watchGrowthSnapshot({DateTime Function()? clock}) {
    final now = clock ?? DateTime.now;
    late final StreamController<GrowthSnapshot> controller;
    StreamSubscription<void>? subscription;
    Timer? timer;

    Future<void> emit() async {
      final snapshot = await growthSnapshot(now: now());
      if (!controller.isClosed) {
        controller.add(snapshot);
      }
    }

    controller = StreamController<GrowthSnapshot>(
      onListen: () {
        subscription = customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM habit_logs) AS log_count, '
          '(SELECT COUNT(*) FROM habit_selections) AS selection_count',
          readsFrom: {habitSelections, habitLogs},
        ).watch().map<void>((_) {}).listen((_) => emit());
        timer = Timer.periodic(const Duration(minutes: 1), (_) => emit());
      },
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<GrowthSnapshot> growthSnapshot({DateTime? now}) async {
    final selections = await select(habitSelections).get();
    final logs = await select(habitLogs).get();
    return calculateGrowthSnapshot(
      enabledAtByHabit: {
        for (final selection in selections)
          selection.habitId: selection.enabledAt,
      },
      completions: [
        for (final log in logs)
          HabitCompletionEvent(
            habitId: log.habitId,
            localDate: DateTime.parse(log.localDate),
          ),
      ],
      today: now ?? DateTime.now(),
    );
  }

  Future<int> debugAddCompletionPoints({
    required String habitId,
    required int amount,
    DateTime? now,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final current = now ?? DateTime.now();
    return transaction(() async {
      final selection = await (select(
        habitSelections,
      )..where((row) => row.habitId.equals(habitId))).getSingleOrNull();
      if (selection == null) throw StateError('只能给已选习惯增加测试点');

      var inserted = 0;
      var candidate = DateTime(current.year, current.month, current.day);
      while (inserted < amount) {
        final localDate = _localDate(candidate);
        final existing =
            await (select(habitLogs)..where(
                  (row) =>
                      row.habitId.equals(habitId) &
                      row.localDate.equals(localDate),
                ))
                .getSingleOrNull();
        if (existing == null) {
          final occurredAt = DateTime(
            candidate.year,
            candidate.month,
            candidate.day,
            12,
          );
          final logId = await into(habitLogs).insert(
            HabitLogsCompanion.insert(
              habitId: habitId,
              localDate: localDate,
              timezoneOffsetMinutes: current.timeZoneOffset.inMinutes,
              createdAt: occurredAt,
            ),
          );
          await into(pointTransactions).insert(
            PointTransactionsCompanion.insert(
              habitLogId: logId,
              amount: 1,
              createdAt: occurredAt,
            ),
          );
          inserted++;
        }
        candidate = candidate.subtract(const Duration(days: 1));
      }
      return inserted;
    });
  }

  Future<List<DailyRecordSummary>> monthlyRecordSummaries(
    DateTime month,
  ) async {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1);
    final firstDate = _localDate(first);
    final lastDate = _localDate(last);
    final logs =
        await (select(habitLogs)..where(
              (row) =>
                  row.localDate.isBiggerOrEqualValue(firstDate) &
                  row.localDate.isSmallerThanValue(lastDate),
            ))
            .get();
    final reviews =
        await (select(reviewEntries)..where(
              (row) =>
                  row.localDate.isBiggerOrEqualValue(firstDate) &
                  row.localDate.isSmallerThanValue(lastDate),
            ))
            .get();
    final challenges =
        await (select(challengeDraws)..where(
              (row) =>
                  row.localDate.isBiggerOrEqualValue(firstDate) &
                  row.localDate.isSmallerThanValue(lastDate),
            ))
            .get();
    final sessions =
        await (select(timerSessions)..where(
              (row) =>
                  row.startedAt.isBiggerOrEqualValue(first) &
                  row.startedAt.isSmallerThanValue(last),
            ))
            .get();
    final activities =
        await (select(habitActivityEntries)..where(
              (row) =>
                  row.completedAt.isBiggerOrEqualValue(first) &
                  row.completedAt.isSmallerThanValue(last),
            ))
            .get();
    final missed =
        await (select(missedHabitRecords)..where(
              (row) =>
                  row.localDate.isBiggerOrEqualValue(_localDate(first)) &
                  row.localDate.isSmallerThanValue(_localDate(last)),
            ))
            .get();
    final transactions = await select(pointTransactions).get();
    final pointsByLogId = <int, int>{
      for (final transaction in transactions)
        transaction.habitLogId: transaction.amount,
    };
    final logsByDate = <String, List<HabitLog>>{};
    for (final log in logs) {
      logsByDate.putIfAbsent(log.localDate, () => []).add(log);
    }
    final reviewsByDate = {
      for (final review in reviews) review.localDate: review,
    };
    final challengesByDate = {
      for (final challenge in challenges) challenge.localDate: challenge,
    };
    final sessionsByDate = <String, List<TimerSession>>{};
    for (final session in sessions) {
      sessionsByDate
          .putIfAbsent(_localDate(session.startedAt), () => [])
          .add(session);
    }
    final activitiesByDate = <String, List<HabitActivityEntry>>{};
    for (final activity in activities) {
      activitiesByDate
          .putIfAbsent(_localDate(activity.completedAt), () => [])
          .add(activity);
    }
    final missedByDate = <String, Set<String>>{};
    for (final record in missed) {
      missedByDate.putIfAbsent(record.localDate, () => {}).add(record.habitId);
    }

    final result = <DailyRecordSummary>[];
    for (
      var date = first;
      date.isBefore(last);
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey = _localDate(date);
      final dayLogs = logsByDate[dateKey] ?? const <HabitLog>[];
      final pointsByHabit = <String, int>{};
      for (final log in dayLogs) {
        pointsByHabit[log.habitId] =
            (pointsByHabit[log.habitId] ?? 0) + (pointsByLogId[log.id] ?? 0);
      }
      final daySessions = sessionsByDate[dateKey] ?? const <TimerSession>[];
      final focusSessions = daySessions.where(
        (session) => session.habitId == 'H2',
      );
      final disconnectSessions = daySessions.where(
        (session) => session.habitId == 'H4',
      );
      final focus = focusSessions.isEmpty
          ? null
          : _focusRecord(focusSessions.last);
      final disconnect = disconnectSessions.isEmpty
          ? null
          : _disconnectRecord(disconnectSessions.last);
      final review = reviewsByDate[dateKey];
      result.add(
        DailyRecordSummary(
          date: date,
          completedHabitIds: dayLogs.map((log) => log.habitId).toSet(),
          missedHabitIds: missedByDate[dateKey] ?? const {},
          points: dayLogs.fold<int>(
            0,
            (sum, log) => sum + (pointsByLogId[log.id] ?? 0),
          ),
          pointsByHabit: pointsByHabit,
          review: review == null
              ? null
              : ReviewRecord(
                  decision: review.decision,
                  result: review.result,
                  improvement: review.improvement,
                ),
          focus: focus,
          challengeCardIndex: challengesByDate[dateKey]?.cardIndex,
          disconnect: disconnect,
          activities: [
            for (final activity
                in activitiesByDate[dateKey] ?? const <HabitActivityEntry>[])
              HabitActivityRecord(
                habitId: activity.habitId,
                primaryText: activity.primaryText,
                secondaryText: activity.secondaryText,
                firstValue: activity.firstValue,
                secondValue: activity.secondValue,
              ),
          ],
        ),
      );
    }
    return result;
  }

  FocusRecord _focusRecord(TimerSession session) {
    final endedAt = session.endedAt ?? session.startedAt;
    final progress = timerProgress(
      startedAt: session.startedAt,
      now: endedAt,
      accumulatedPauseSeconds: session.accumulatedPauseSeconds,
      pausedAt: session.pausedAt,
    );
    return FocusRecord(
      focusMinutes: (progress.focusSeconds / 60).floor(),
      status: session.status,
      topic: session.focusTopic,
    );
  }

  DisconnectRecord _disconnectRecord(TimerSession session) {
    final endedAt = session.endedAt ?? session.startedAt;
    final elapsed = endedAt
        .difference(session.startedAt)
        .inSeconds
        .clamp(0, 1 << 31);
    return DisconnectRecord(
      minutes: (elapsed / 60).floor(),
      status: session.status,
    );
  }

  Stream<int> watchPointBalance() {
    return select(
      pointTransactions,
    ).watch().map((rows) => rows.fold<int>(0, (sum, row) => sum + row.amount));
  }

  String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  bool _isBeforeDay(DateTime first, DateTime second) => DateTime(
    first.year,
    first.month,
    first.day,
  ).isBefore(DateTime(second.year, second.month, second.day));
}

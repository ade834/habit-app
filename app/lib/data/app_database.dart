import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/habit_growth.dart';
import '../domain/habit_tools.dart';
import '../domain/daily_records.dart';

part 'app_database.g.dart';

class HabitSelections extends Table {
  TextColumn get habitId => text()();
  TextColumn get commitmentNote => text().withDefault(const Constant(''))();
  DateTimeColumn get enabledAt => dateTime()();

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

@DriftDatabase(
  tables: [
    HabitSelections,
    HabitLogs,
    PointTransactions,
    ReviewEntries,
    TimerSessions,
    ChallengeDraws,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'habit_app'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

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
    },
  );

  Stream<List<HabitSelection>> watchSelectedHabits() =>
      select(habitSelections).watch();

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(challengeDraws).go();
      await delete(timerSessions).go();
      await delete(reviewEntries).go();
      await delete(pointTransactions).go();
      await delete(habitLogs).go();
      await delete(habitSelections).go();
    });
  }

  Future<void> saveOnboarding({
    required Set<String> habitIds,
    required String commitmentNote,
    DateTime? now,
  }) async {
    if (habitIds.isEmpty || habitIds.length > 3) {
      throw ArgumentError('请选择1到3个习惯');
    }

    final enabledAt = now ?? DateTime.now();
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
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<bool> recordCompletion({
    required String habitId,
    required DateTime occurredAt,
  }) {
    return transaction(() => _recordCompletion(habitId, occurredAt));
  }

  Future<bool> _recordCompletion(String habitId, DateTime occurredAt) async {
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
        amount: 1,
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
          'SELECT 1',
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

    final result = <DailyRecordSummary>[];
    for (
      var date = first;
      date.isBefore(last);
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey = _localDate(date);
      final dayLogs = logsByDate[dateKey] ?? const <HabitLog>[];
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
          points: dayLogs.fold<int>(
            0,
            (sum, log) => sum + (pointsByLogId[log.id] ?? 0),
          ),
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
}

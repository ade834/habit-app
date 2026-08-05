import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [HabitSelections, HabitLogs, PointTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'habit_app'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Stream<List<HabitSelection>> watchSelectedHabits() =>
      select(habitSelections).watch();

  Future<void> clearAllData() async {
    await transaction(() async {
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
    final localDate =
        '${occurredAt.year.toString().padLeft(4, '0')}-'
        '${occurredAt.month.toString().padLeft(2, '0')}-'
        '${occurredAt.day.toString().padLeft(2, '0')}';

    return transaction(() async {
      final existing =
          await (select(habitLogs)..where(
                (log) =>
                    log.habitId.equals(habitId) &
                    log.localDate.equals(localDate),
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
    });
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

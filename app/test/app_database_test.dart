import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/data/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('重复打卡不会重复发积分', () async {
    final time = DateTime(2026, 8, 4, 9);

    expect(
      await database.recordCompletion(habitId: 'H1', occurredAt: time),
      isTrue,
    );
    expect(
      await database.recordCompletion(habitId: 'H1', occurredAt: time),
      isFalse,
    );
    expect(await database.pointBalance(), 1);
  });

  test('首次启动只能选择1到3个习惯', () async {
    expect(
      () => database.saveOnboarding(habitIds: {}, commitmentNote: ''),
      throwsArgumentError,
    );
    expect(
      () => database.saveOnboarding(
        habitIds: {'H1', 'H2', 'H3', 'H4'},
        commitmentNote: '',
      ),
      throwsArgumentError,
    );
  });
}

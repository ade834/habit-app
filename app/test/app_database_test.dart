import 'dart:io';

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

  test('关闭后重新打开数据库仍保留已选习惯', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('habit_app_test_');
    final file = File('${directory.path}/habit.sqlite');
    final first = AppDatabase.forTesting(NativeDatabase(file));

    await first.saveOnboarding(
      habitIds: {'H1', 'H2'},
      commitmentNote: '为了长期成长',
    );
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    final selections = await reopened.watchSelectedHabits().first;
    expect(selections.map((item) => item.habitId), containsAll(['H1', 'H2']));

    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('清除本地数据会删除习惯、打卡和积分', () async {
    await database.saveOnboarding(habitIds: {'H1'}, commitmentNote: '测试');
    await database.recordCompletion(
      habitId: 'H1',
      occurredAt: DateTime(2026, 8, 5),
    );

    await database.clearAllData();

    expect(await database.watchSelectedHabits().first, isEmpty);
    expect(await database.pointBalance(), 0);
  });

  test('H1今日100字发积分，补录前3天不发积分', () async {
    final now = DateTime(2026, 8, 5, 12);
    expect(
      await database.saveReview(
        date: now,
        decision: List.filled(100, '我').join(),
        result: '',
        improvement: '',
        now: now,
      ),
      isTrue,
    );
    expect(
      await database.saveReview(
        date: DateTime(2026, 8, 2),
        decision: List.filled(100, '我').join(),
        result: '',
        improvement: '',
        now: now,
      ),
      isFalse,
    );
    expect(await database.pointBalance(), 1);
  });

  test('H2达到30分钟且暂停不超过5分钟才完成', () async {
    final start = DateTime(2026, 8, 5, 10);
    final session = await database.startTimer(
      habitId: 'H2',
      targetSeconds: 30 * 60,
      now: start,
    );
    await database.pauseTimer(
      session.id,
      start.add(const Duration(minutes: 10)),
    );
    await database.resumeTimer(
      session.id,
      start.add(const Duration(minutes: 15)),
    );
    expect(
      await database.finishFocusTimer(
        session.id,
        start.add(const Duration(minutes: 35)),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 1);
  });

  test('H3每天只能换卡一次', () async {
    final now = DateTime(2026, 8, 5);
    final first = await database.challengeForToday(now: now);
    final swapped = await database.swapChallenge(now: now);
    final repeated = await database.swapChallenge(now: now);
    expect(swapped.swapUsed, isTrue);
    expect(swapped.cardIndex, isNot(first.cardIndex));
    expect(repeated.cardIndex, swapped.cardIndex);
  });

  test('H4倒计未结束不能确认，结束后完成', () async {
    final start = DateTime(2026, 8, 5, 22);
    final session = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: start,
    );
    expect(
      await database.confirmDisconnectTimer(
        session.id,
        start.add(const Duration(minutes: 14)),
      ),
      isFalse,
    );
    expect(
      await database.confirmDisconnectTimer(
        session.id,
        start.add(const Duration(minutes: 15)),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 1);
  });
}

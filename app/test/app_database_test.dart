import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/data/app_database.dart';
import 'package:habit_app/domain/daily_records.dart';
import 'package:habit_app/domain/habit_tools.dart';

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

  test('月历最多显示3条活动短标题', () {
    final summary = DailyRecordSummary(
      date: DateTime(2026, 8, 25),
      completedHabitIds: const {},
      points: 0,
      activities: List.generate(
        4,
        (index) => HabitActivityRecord(
          habitId: 'H${index + 5}',
          primaryText: '记录${index + 1}',
          secondaryText: '',
        ),
      ),
    );

    expect(summary.calendarActivities.map((activity) => activity.primaryText), [
      '记录1',
      '记录2',
      '记录3',
    ]);
  });

  test('H7财务字段仅允许选填数字', () {
    expect(isOptionalNumber(''), isTrue);
    expect(isOptionalNumber('12.5'), isTrue);
    expect(isOptionalNumber('一百'), isFalse);
  });

  test('首次启动普通习惯只能选择1到3个', () async {
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

  test('首次选择不允许星标，后续选择可把星标设为额外项', () async {
    await expectLater(
      database.saveOnboarding(
        habitIds: {'H1'},
        starredHabitIds: {'H1'},
        commitmentNote: '测试',
      ),
      throwsArgumentError,
    );
    await database.saveOnboarding(
      habitIds: {'H1', 'H2', 'H3'},
      commitmentNote: '测试',
      now: DateTime(2026, 8, 25),
    );
    await database.replaceSelectedHabits(
      {'H1', 'H2', 'H3', 'H5'},
      starredHabitIds: {'H5'},
      now: DateTime(2026, 8, 26),
    );

    final selections = await database.watchSelectedHabits().first;
    expect(selections.where((row) => row.isStarred).map((row) => row.habitId), {
      'H5',
    });
  });

  test('星标第一阶段限1个，解锁第二阶段后限2个', () async {
    await expectLater(
      database.saveOnboarding(
        habitIds: {'H1', 'H2'},
        starredHabitIds: {'H1', 'H2'},
        commitmentNote: '测试',
      ),
      throwsArgumentError,
    );
    await database.saveOnboarding(
      habitIds: {'H1'},
      commitmentNote: '测试',
      now: DateTime(2026, 1, 1),
    );
    await expectLater(
      database.replaceSelectedHabits(
        {'H1', 'H7'},
        starredHabitIds: {'H1', 'H7'},
        now: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
    for (var day = 1; day <= 6; day++) {
      await database.recordCompletion(
        habitId: 'H1',
        occurredAt: DateTime(2026, 1, day),
      );
    }
    await database.replaceSelectedHabits(
      {'H1', 'H7'},
      starredHabitIds: {'H1', 'H7'},
      now: DateTime(2026, 1, 7),
    );
    await expectLater(
      database.replaceSelectedHabits(
        {'H1', 'H7', 'H8'},
        starredHabitIds: {'H1', 'H7', 'H8'},
        now: DateTime(2026, 1, 7),
      ),
      throwsArgumentError,
    );
  });

  test('周期习惯次日转为额外名额', () async {
    final firstDay = DateTime(2026, 8, 25);
    final secondDay = firstDay.add(const Duration(days: 1));
    await database.saveOnboarding(
      habitIds: {'H1', 'H5', 'H7'},
      commitmentNote: '测试',
      now: firstDay,
    );

    await database.replaceSelectedHabits({
      'H1',
      'H2',
      'H3',
      'H5',
      'H7',
    }, now: secondDay);

    expect(
      (await database.watchSelectedHabits().first).map((row) => row.habitId),
      containsAll(['H1', 'H2', 'H3', 'H5', 'H7']),
    );
  });

  test('新的一天自动保留星标和周期习惯', () async {
    final firstDay = DateTime(2026, 8, 25);
    final secondDay = firstDay.add(const Duration(days: 1));
    await database.saveOnboarding(
      habitIds: {'H1', 'H2', 'H5'},
      commitmentNote: '测试',
      now: firstDay,
    );

    expect(
      (await database.watchActiveHabits(now: firstDay).first).map(
        (row) => row.habitId,
      ),
      containsAll({'H1', 'H2', 'H5'}),
    );
    await database.replaceSelectedHabits(
      {'H2', 'H5'},
      starredHabitIds: {'H2'},
      now: secondDay,
    );
    expect(
      (await database.watchActiveHabits(now: secondDay).first).map(
        (row) => row.habitId,
      ),
      {'H2', 'H5'},
    );
  });

  test('重新选择的月任务会保留到本月完成', () async {
    await database.saveLaterHabitActivity(
      habitId: 'H10',
      primaryText: '八月读完的书',
      now: DateTime(2026, 8, 20),
    );
    final selectedOn = DateTime(2026, 9, 1);
    await database.replaceSelectedHabits({'H10'}, now: selectedOn);

    expect(
      (await database.watchActiveHabits(now: DateTime(2026, 9, 2)).first).map(
        (row) => row.habitId,
      ),
      contains('H10'),
    );
  });

  test('未完成周期任务只留在被选择的自然周期内', () async {
    final cases = [
      ('H5', DateTime(2026, 9, 1), DateTime(2026, 9, 7)),
      ('H10', DateTime(2026, 9, 1), DateTime(2026, 10, 1)),
      ('H11', DateTime(2026, 1, 1), DateTime(2027, 1, 1)),
    ];
    for (final entry in cases) {
      await database.clearAllData();
      await database.replaceSelectedHabits({entry.$1}, now: entry.$2);

      expect(
        (await database.watchActiveHabits(now: entry.$2).first).map(
          (row) => row.habitId,
        ),
        contains(entry.$1),
      );
      expect(await database.watchActiveHabits(now: entry.$3).first, isEmpty);
      expect(
        (await database.watchSelectedHabits().first).map((row) => row.habitId),
        contains(entry.$1),
      );
    }
  });

  test('次日重新选择时周期习惯不占普通名额', () async {
    final firstDay = DateTime(2026, 8, 25);
    final secondDay = firstDay.add(const Duration(days: 1));
    await database.saveOnboarding(
      habitIds: {'H1', 'H5'},
      commitmentNote: '测试',
      now: firstDay,
    );

    await database.replaceSelectedHabits({
      'H1',
      'H2',
      'H3',
      'H5',
    }, now: secondDay);

    expect(
      (await database.watchActiveHabits(now: secondDay).first).map(
        (row) => row.habitId,
      ),
      containsAll({'H1', 'H2', 'H3', 'H5'}),
    );
  });

  test('跨周期重新选择的周期习惯会重新占当天名额', () async {
    await database.saveOnboarding(
      habitIds: {'H1', 'H5'},
      commitmentNote: '测试',
      now: DateTime(2026, 9, 1),
    );

    await expectLater(
      database.replaceSelectedHabits({
        'H1',
        'H2',
        'H5',
        'H7',
      }, now: DateTime(2026, 9, 7)),
      throwsArgumentError,
    );
  });

  test('周期任务到期未完成会写入周期末日并在结算日提示', () async {
    await database.saveOnboarding(
      habitIds: {'H5'},
      commitmentNote: '测试',
      now: DateTime(2026, 9, 1),
    );
    final settledOn = DateTime(2026, 9, 8);
    await database.settleMissedPeriodicHabits(now: settledOn);

    expect(await database.settledPeriodicMissedHabitCountForDate(settledOn), 1);
    final summaries = await database.monthlyRecordSummaries(DateTime(2026, 9));
    final periodEnd = summaries.firstWhere((item) => item.date.day == 6);
    expect(periodEnd.missedHabitIds, contains('H5'));
    expect(
      (await database.watchActiveHabits(now: settledOn).first).map(
        (row) => row.habitId,
      ),
      isNot(contains('H5')),
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

  test('测试阶段可把当前选择更换为H5到H12且保留历史记录', () async {
    await database.saveOnboarding(habitIds: {'H1'}, commitmentNote: '测试');
    await database.recordCompletion(
      habitId: 'H1',
      occurredAt: DateTime(2026, 8, 5),
    );

    await database.replaceSelectedHabits({'H5', 'H10', 'H12'});

    final selected = await database.watchSelectedHabits().first;
    expect(
      selected.map((row) => row.habitId),
      containsAll(['H5', 'H10', 'H12']),
    );
    expect(await database.watchCompletionCount('H1').first, 1);
  });

  test('星标习惯完成不加积分但增加养成进度', () async {
    await database.saveOnboarding(habitIds: {'H1'}, commitmentNote: '测试');
    await database.replaceSelectedHabits({'H1', 'H5'}, starredHabitIds: {'H5'});
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H5',
        primaryText: '星标任务',
        now: DateTime(2026, 8, 25),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 0);
    final snapshot = await database.growthSnapshot(now: DateTime(2026, 8, 25));
    expect(snapshot.habits['H5']!.historicalCompletions, 1);
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

  test('H2计时会话保留用户选择的思考议题', () async {
    final session = await database.startTimer(
      habitId: 'H2',
      targetSeconds: 30 * 60,
      focusTopic: '善良的边界该如何取舍？',
      now: DateTime(2026, 8, 5, 10),
    );
    expect(session.focusTopic, '善良的边界该如何取舍？');
  });

  test('H3前3次换新卡，第4次起在前3张中循环', () async {
    final now = DateTime(2026, 8, 5);
    final first = await database.challengeForToday(now: now);
    final firstSwap = await database.swapChallenge(now: now);
    final secondSwap = await database.swapChallenge(now: now);
    final thirdSwap = await database.swapChallenge(now: now);
    final fourthSwap = await database.swapChallenge(now: now);
    final fifthSwap = await database.swapChallenge(now: now);
    final sixthSwap = await database.swapChallenge(now: now);

    expect({
      firstSwap.cardIndex,
      secondSwap.cardIndex,
      thirdSwap.cardIndex,
    }, hasLength(3));
    expect(firstSwap.cardIndex, isNot(first.cardIndex));
    expect(fourthSwap.cardIndex, firstSwap.cardIndex);
    expect(fifthSwap.cardIndex, secondSwap.cardIndex);
    expect(sixthSwap.cardIndex, thirdSwap.cardIndex);
    expect(sixthSwap.swapCount, 6);
  });

  test('H4倒计未结束不能完成，结束后自动完成', () async {
    final start = DateTime(2026, 8, 5, 22);
    final session = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: start,
    );
    expect(
      await database.completeDisconnectTimer(
        session.id,
        start.add(const Duration(minutes: 14)),
      ),
      isFalse,
    );
    expect(
      await database.completeDisconnectTimer(
        session.id,
        start.add(const Duration(minutes: 15)),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 1);
  });

  test('H4离开页面时结束未完成会话', () async {
    final start = DateTime(2026, 8, 5, 22);
    final session = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: start,
    );
    await database.endTimerEarly(
      session.id,
      start.add(const Duration(minutes: 1)),
    );

    expect(await database.watchActiveTimer('H4').first, isNull);
    expect(await database.pointBalance(), 0);
  });

  test('App启动时将遗留的H4 running会话判为失败且不能补发积分', () async {
    final start = DateTime(2026, 8, 5, 22);
    final session = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: start,
    );

    expect(
      await database.recoverInterruptedDisconnectSession(
        now: start.add(const Duration(minutes: 20)),
      ),
      1,
    );

    expect(await database.watchActiveTimer('H4').first, isNull);
    expect(
      await database.completeDisconnectTimer(
        session.id,
        start.add(const Duration(minutes: 20)),
      ),
      isFalse,
    );
    final state = await database.watchDisconnectAttemptState().first;
    expect(state.consecutiveFailures, 1);
    expect(await database.pointBalance(), 0);
  });

  test('H4连续重置3次后冷却10小时', () async {
    final now = DateTime.now();
    for (var attempt = 0; attempt < 3; attempt++) {
      final start = now.add(Duration(minutes: attempt));
      final session = await database.startTimer(
        habitId: 'H4',
        targetSeconds: 15 * 60,
        now: start,
      );
      await database.endTimerEarly(
        session.id,
        start.add(const Duration(minutes: 1)),
      );
    }

    final state = await database.watchDisconnectAttemptState().first;
    expect(state.consecutiveFailures, 3);
    expect(state.isLocked, isTrue);
    expect(state.lockedUntil!.difference(now).inHours, greaterThanOrEqualTo(9));
  });

  test('H4冷却到期后再次失败从第1次重新计算', () async {
    final start = DateTime(2026, 8, 5, 8);
    for (var attempt = 0; attempt < 3; attempt++) {
      final attemptStart = start.add(Duration(minutes: attempt));
      final session = await database.startTimer(
        habitId: 'H4',
        targetSeconds: 15 * 60,
        now: attemptStart,
      );
      await database.endTimerEarly(
        session.id,
        attemptStart.add(const Duration(minutes: 1)),
      );
    }

    final afterCooldown = start.add(const Duration(hours: 11));
    final next = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: afterCooldown,
    );
    await database.endTimerEarly(
      next.id,
      afterCooldown.add(const Duration(minutes: 1)),
    );

    final state = await database
        .watchDisconnectAttemptState(clock: () => afterCooldown)
        .first;
    expect(state.consecutiveFailures, 1);
    expect(state.lockedUntil, isNull);
  });

  test('调试加点写入日志和积分并可解锁第二章', () async {
    await database.saveOnboarding(
      habitIds: {'H1', 'H2', 'H3'},
      commitmentNote: '测试',
      now: DateTime(2026, 8, 1),
    );
    await database.debugAddCompletionPoints(
      habitId: 'H1',
      amount: 5,
      now: DateTime(2026, 8, 5),
    );
    await database.debugAddCompletionPoints(
      habitId: 'H2',
      amount: 1,
      now: DateTime(2026, 8, 5),
    );

    expect(await database.pointBalance(), 6);
    final snapshot = await database.growthSnapshot(now: DateTime(2026, 8, 5));
    expect(snapshot.habits['H1']!.historicalCompletions, 5);
    expect(snapshot.chapterTwoUnlocked, isTrue);
  });

  test('月历汇总从日志、复盘、计时和挑战记录派生', () async {
    final day = DateTime(2026, 8, 5, 10);
    await database.saveReview(
      date: day,
      decision: List.filled(100, '我').join(),
      result: '结果',
      improvement: '下次',
      now: day,
    );
    final focus = await database.startTimer(
      habitId: 'H2',
      targetSeconds: 30 * 60,
      focusTopic: '测试议题',
      now: day,
    );
    await database.finishFocusTimer(
      focus.id,
      day.add(const Duration(minutes: 30)),
    );
    await database.challengeForToday(now: day);
    final disconnect = await database.startTimer(
      habitId: 'H4',
      targetSeconds: 15 * 60,
      now: day.add(const Duration(hours: 10)),
    );
    await database.endTimerEarly(
      disconnect.id,
      day.add(const Duration(hours: 10, minutes: 1)),
    );
    await database.saveLaterHabitActivity(
      habitId: 'H5',
      primaryText: '老朋友小林',
      secondaryText: '聊了最近的工作变化',
      now: day,
    );

    final summaries = await database.monthlyRecordSummaries(DateTime(2026, 8));
    final summary = summaries.firstWhere((item) => item.date.day == 5);
    expect(summary.completedHabitIds, containsAll(['H1', 'H2', 'H5']));
    expect(summary.points, 5);
    expect(summary.review?.decision, contains('我'));
    expect(summary.focus?.status, 'completed');
    expect(summary.focus?.focusMinutes, 30);
    expect(summary.focus?.topic, '测试议题');
    expect(summary.challengeCardIndex, isNotNull);
    expect(summary.disconnect?.status, 'failed');
    expect(summary.activities.single.primaryText, '老朋友小林');
    expect(summary.activities.single.secondaryText, '聊了最近的工作变化');
  });

  test('H5每个自然周只奖励一次，下一周可再次完成', () async {
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H5',
        primaryText: '老朋友甲',
        now: DateTime(2026, 8, 3),
      ),
      isTrue,
    );
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H5',
        primaryText: '老朋友乙',
        now: DateTime(2026, 8, 9),
      ),
      isFalse,
    );
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H5',
        primaryText: '老朋友丙',
        now: DateTime(2026, 8, 10),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 6);
  });

  test('周期任务可以暂存到之后日期完成，并按实际完成日记录', () async {
    final later = DateTime(2026, 8, 6); // 本周任务顺延到周四完成
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H5',
        primaryText: '顺延联系的朋友',
        now: later,
      ),
      isTrue,
    );
    final summaries = await database.monthlyRecordSummaries(DateTime(2026, 8));
    final completedDay = summaries.firstWhere((item) => item.date.day == 6);
    expect(completedDay.completedHabitIds, contains('H5'));
    expect(completedDay.points, 3);
  });

  test('H10按月、H11按年防止重复奖励', () async {
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H10',
        primaryText: '跨界书A',
        now: DateTime(2026, 8, 1),
      ),
      isTrue,
    );
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H10',
        primaryText: '跨界书B',
        now: DateTime(2026, 8, 31),
      ),
      isFalse,
    );
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H11',
        primaryText: '杭州',
        now: DateTime(2026, 1, 1),
      ),
      isTrue,
    );
    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H11',
        primaryText: '成都',
        now: DateTime(2026, 12, 31),
      ),
      isFalse,
    );
    expect(await database.pointBalance(), 103);
  });

  test('H6到H9、H12均可保存结构化记录并写入积分', () async {
    for (final habitId in ['H6', 'H7', 'H8', 'H9', 'H12']) {
      expect(
        await database.saveLaterHabitActivity(
          habitId: habitId,
          primaryText: '$habitId 的必填记录',
          secondaryText: '补充内容',
          firstValue: habitId == 'H7' ? 100 : null,
          secondValue: habitId == 'H7' ? 50 : null,
          now: DateTime(2026, 8, 5),
        ),
        isTrue,
      );
    }
    expect(await database.pointBalance(), 7);
  });

  test('H11先保存旅行计划，再完成总结并获得99积分', () async {
    await database.saveTravelPlan(
      destination: '大理',
      days: 4,
      focus: '想清楚下一阶段方向',
      preparation: '预算3000元',
      now: DateTime(2026, 8, 5),
    );
    final plan = await database.travelPlanForYear(now: DateTime(2026, 9, 1));
    expect(plan?.destination, '大理');
    expect(plan?.days, 4);

    expect(
      await database.saveLaterHabitActivity(
        habitId: 'H11',
        primaryText: plan!.destination,
        secondaryText: '学会一个人面对不确定',
        now: DateTime(2026, 9, 1),
      ),
      isTrue,
    );
    expect(await database.pointBalance(), 99);
  });
}

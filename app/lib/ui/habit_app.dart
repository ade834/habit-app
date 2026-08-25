import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../domain/daily_records.dart';
import '../domain/habit.dart';
import '../domain/habit_growth.dart';
import '../domain/habit_tools.dart';
import '../domain/monthly_reflection.dart';
import '../domain/monthly_insight.dart';
import 'habit_tools_page.dart';
import '../domain/debug_clock.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final monthlyInsightGeneratorProvider = Provider<MonthlyInsightGenerator>(
  (ref) => const PreviewMonthlyInsightGenerator(),
);

final startupRecoveryProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(databaseProvider);
  await database.settleMissedOrdinaryHabits(now: appDebugNow());
  await database.settleMissedPeriodicHabits(now: appDebugNow());
  await database.recoverInterruptedDisconnectSession();
});

final missedYesterdayProvider = FutureProvider.family<int, DateTime>(
  (ref, now) => ref
      .watch(databaseProvider)
      .missedHabitCountForDate(now.subtract(const Duration(days: 1))),
);

final settledPeriodicMissedProvider = FutureProvider.family<int, DateTime>(
  (ref, now) =>
      ref.watch(databaseProvider).settledPeriodicMissedHabitCountForDate(now),
);

final travelPlanProvider = FutureProvider.family<TravelPlan?, DateTime>(
  (ref, now) => ref.watch(databaseProvider).travelPlanForYear(now: now),
);

final selectedHabitsProvider = StreamProvider<List<HabitSelection>>(
  (ref) => ref.watch(databaseProvider).watchSelectedHabits(),
);

final activeHabitsProvider =
    StreamProvider.family<List<HabitSelection>, DateTime>(
      (ref, now) => ref.watch(databaseProvider).watchActiveHabits(now: now),
    );

final todayCompletedProvider = StreamProvider.family<Set<String>, DateTime>(
  (ref, now) =>
      ref.watch(databaseProvider).watchTodayCompletedHabitIds(now: now),
);

final pointBalanceProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchPointBalance(),
);

final completionCountProvider = StreamProvider.family<int, String>(
  (ref, habitId) => ref.watch(databaseProvider).watchCompletionCount(habitId),
);

final growthSnapshotProvider = StreamProvider.family<GrowthSnapshot, DateTime>(
  (ref, now) =>
      ref.watch(databaseProvider).watchGrowthSnapshot(clock: () => now),
);

const _normalHabitColor = Color(0xFFC4D1BB);
const _periodicHabitColor = Color(0xFFB9CCD4);
const _starredHabitColor = Color(0xFFE0D0A8);

void _showCompletionBanner(
  BuildContext context,
  int points, {
  required bool isStarred,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(
    MaterialBanner(
      leading: const Icon(Icons.stars_rounded, size: 40),
      content: Text(
        isStarred
            ? '恭喜你完成今天的星标任务'
            : points > 0
            ? '完成！获得 $points 积分'
            : '记录已保存',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('知道了'),
        ),
      ],
    ),
  );
  Future<void>.delayed(const Duration(seconds: 4), () {
    messenger.hideCurrentMaterialBanner();
  });
}

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '习惯花园',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF557A5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5EE),
        useMaterial3: true,
      ),
      home: const _StartupPage(),
    );
  }
}

class _StartupPage extends ConsumerWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(startupRecoveryProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) =>
              Scaffold(body: Center(child: Text('恢复本地数据失败：$error'))),
          data: (_) => ref
              .watch(selectedHabitsProvider)
              .when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) =>
                    Scaffold(body: Center(child: Text('读取本地数据失败：$error'))),
                data: (selected) => selected.isEmpty
                    ? const _OnboardingPage()
                    : const _MainShell(),
              ),
        );
  }
}

class _OnboardingPage extends ConsumerStatefulWidget {
  const _OnboardingPage();

  @override
  ConsumerState<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<_OnboardingPage> {
  final _selected = <String>{};
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regularCount = _selected.length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text('从今天开始', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text('首日普通和周期习惯合计最多3个；完成任务后再设置星标。'),
            const SizedBox(height: 4),
            Text('已选：普通 $regularCount/3'),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _HabitColorLegend(color: _normalHabitColor, label: '普通习惯'),
                _HabitColorLegend(color: _periodicHabitColor, label: '周期习惯'),
              ],
            ),
            const SizedBox(height: 12),
            for (final habit in allHabits)
              Builder(
                builder: (context) {
                  final isPeriodic = isPeriodicHabit(habit.id);
                  final isSelected = _selected.contains(habit.id);
                  final accent = isPeriodic
                      ? _periodicHabitColor
                      : _normalHabitColor;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      title: Text(habit.name),
                      subtitle: Text(
                        isPeriodic
                            ? '周期习惯：首日计入普通名额，次日起作为额外名额保留'
                            : habit.description,
                      ),
                      fillColor: isPeriodic
                          ? WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.green.shade200
                                  : null,
                            )
                          : null,
                      onChanged: !isSelected && regularCount >= 3
                          ? null
                          : (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(habit.id);
                              } else {
                                _selected.remove(habit.id);
                              }
                            }),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '我想养成这些习惯，是因为……',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _selected.isEmpty || regularCount > 3 || _saving
                  ? null
                  : _save,
              child: Text(_saving ? '保存中…' : '开始养成'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseProvider)
          .saveOnboarding(
            habitIds: _selected,
            commitmentNote: _noteController.text,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  int _reviewVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<DateTime>(
        valueListenable: debugDateNotifier,
        builder: (context, now, _) => switch (_index) {
          0 => _TodayPage(key: ValueKey(now), now: now),
          1 => _GrowthPage(key: ValueKey(now), now: now),
          2 => _ReviewPage(key: ValueKey(_reviewVersion), now: now),
          _ => const _SettingsPage(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          if (value == 2) _reviewVersion++;
          _index = value;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '今天'),
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            label: '养成物',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            label: '复盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _TodayPage extends ConsumerWidget {
  const _TodayPage({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(activeHabitsProvider(now));
    final allSelections = ref.watch(selectedHabitsProvider);
    final completed = ref.watch(todayCompletedProvider(now));
    final points = ref.watch(pointBalanceProvider);
    final growth = ref.watch(growthSnapshotProvider(now));
    final missedYesterday = ref.watch(missedYesterdayProvider(now));
    final settledPeriodic = ref.watch(settledPeriodicMissedProvider(now));
    return SafeArea(
      child: allSelections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('读取习惯失败：$error')),
        data: (all) => selected.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('读取习惯失败：$error')),
          data: (habits) => completed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('读取今日状态失败：$error')),
            data: (done) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${now.month}月${now.day}日 · 今天',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    points.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (value) => Chip(
                        avatar: const Icon(Icons.star, size: 18),
                        label: Text('$value 积分'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '今天也照顾一下正在长大的自己。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                missedYesterday.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (count) => count == 0
                      ? const SizedBox.shrink()
                      : Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '昨天有 $count 个普通习惯未完成，已记入日历。未完成不直接扣分；连续7天没有完成才会进入休眠与衰减。',
                            ),
                          ),
                        ),
                ),
                settledPeriodic.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (count) => count == 0
                      ? const SizedBox.shrink()
                      : Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '上一个周期有 $count 个周期习惯未完成，已标记在该周期最后一天的日历。',
                            ),
                          ),
                        ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _TodayHabitPicker.choose(context, ref, all, habits, now),
                  icon: const Icon(Icons.tune),
                  label: const Text('选择今天的习惯'),
                ),
                const SizedBox(height: 24),
                growth.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (snapshot) {
                    if (snapshot.habits.isEmpty) return const SizedBox.shrink();
                    final state = snapshot.habits.values.first;
                    if (!state.shouldWarnDormancy) {
                      return const SizedBox.shrink();
                    }
                    final message = state.inactivityDay >= 7
                        ? '今天完成任一习惯，可避免养成物今晚进入休眠。'
                        : '再过1天没有完成习惯，养成物将进入休眠。';
                    return Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined),
                            const SizedBox(width: 12),
                            Expanded(child: Text(message)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                for (final habit in habits)
                  Dismissible(
                    key: ValueKey('today-${habit.habitId}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete_outline),
                    ),
                    confirmDismiss: (_) async {
                      await ref
                          .read(databaseProvider)
                          .removeHabitFromToday(habit.habitId);
                      return true;
                    },
                    child: _TodayHabitCard(
                      habit: habit,
                      completed: done.contains(habit.habitId),
                      now: now,
                    ),
                  ),
                if (habits.isEmpty) const Center(child: Text('还没有选择习惯。')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayHabitCard extends ConsumerWidget {
  const _TodayHabitCard({
    required this.habit,
    required this.completed,
    required this.now,
  });

  final HabitSelection habit;
  final bool completed;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = habitById(habit.habitId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Row(
          children: [
            if (habit.isStarred) ...[
              Icon(Icons.star, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 4),
            ],
            Expanded(child: Text(definition.name)),
          ],
        ),
        subtitle: Text(completed ? '今天已完成，做得很好。' : definition.description),
        trailing: completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : habit.habitId == 'H11'
            ? ref
                  .watch(travelPlanProvider(now))
                  .when(
                    loading: () => const SizedBox(width: 24, height: 24),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (plan) => FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push<int>(
                          MaterialPageRoute<int>(
                            builder: (_) => habitToolPage(
                              habitId: habit.habitId,
                              database: ref.read(databaseProvider),
                            ),
                          ),
                        );
                        ref.invalidate(travelPlanProvider(now));
                      },
                      child: Text(plan == null ? '开始' : '复盘'),
                    ),
                  )
            : FilledButton(
                onPressed: () async {
                  final points = await Navigator.of(context).push<int>(
                    MaterialPageRoute<int>(
                      builder: (_) => habitToolPage(
                        habitId: habit.habitId,
                        database: ref.read(databaseProvider),
                      ),
                    ),
                  );
                  if (context.mounted && points != null) {
                    _showCompletionBanner(
                      context,
                      points,
                      isStarred: habit.isStarred,
                    );
                  }
                },
                child: const Text('开始'),
              ),
      ),
    );
  }
}

class _HabitColorLegend extends StatelessWidget {
  const _HabitColorLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _TodayHabitPicker {
  static Future<void> choose(
    BuildContext context,
    WidgetRef ref,
    List<HabitSelection> allSelections,
    List<HabitSelection> activeSelections,
    DateTime now,
  ) async {
    final completedPeriodic = await ref
        .read(databaseProvider)
        .completedPeriodicHabitIds(now: now);
    final starLimit =
        (await ref.read(databaseProvider).growthSnapshot(now: now))
            .chapterTwoUnlocked
        ? 2
        : 1;
    if (!context.mounted) return;
    final selected = activeSelections.map((row) => row.habitId).toSet();
    final starred = allSelections
        .where((row) => row.isStarred)
        .map((row) => row.habitId)
        .toSet();
    selected.addAll(starred);
    final result =
        await showDialog<({Set<String> selected, Set<String> starred})>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final today = now;
              final byId = {for (final row in allSelections) row.habitId: row};
              final regularCount = selected.where((id) {
                final selection = byId[id];
                return countsTowardsRegularQuota(
                  habitId: id,
                  isStarred: starred.contains(id),
                  activeOn: selection?.activeOn,
                  now: today,
                );
              }).length;
              return AlertDialog(
                title: const Text('选择正在养成的习惯'),
                content: SizedBox(
                  width: 520,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Text('当天新建习惯最多选择 3 个；星标和已保留习惯不占名额。'),
                      const SizedBox(height: 4),
                      Text(
                        '当天新建：$regularCount/3 · 星标 ${starred.length}/$starLimit',
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _HabitColorLegend(
                            color: _normalHabitColor,
                            label: '普通习惯',
                          ),
                          _HabitColorLegend(
                            color: _periodicHabitColor,
                            label: '周期习惯',
                          ),
                          _HabitColorLegend(
                            color: _starredHabitColor,
                            label: '星标习惯',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final habit in allHabits.where(
                        (habit) => !completedPeriodic.contains(habit.id),
                      ))
                        Builder(
                          builder: (context) {
                            final isStarred = starred.contains(habit.id);
                            final isPeriodic = isPeriodicHabit(habit.id);
                            final isSelected = selected.contains(habit.id);
                            final countsQuota = countsTowardsRegularQuota(
                              habitId: habit.id,
                              isStarred: isStarred,
                              activeOn: byId[habit.id]?.activeOn,
                              now: today,
                            );
                            final accent = isStarred
                                ? _starredHabitColor
                                : isPeriodic
                                ? _periodicHabitColor
                                : _normalHabitColor;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? accent : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CheckboxListTile(
                                value: selected.contains(habit.id),
                                title: Text(habit.name),
                                subtitle: Text(
                                  isStarred
                                      ? '星标：完成不加积分，但增加养成进度'
                                      : isPeriodic
                                      ? '周期习惯：次日起作为额外名额保留'
                                      : habit.description,
                                ),
                                fillColor: isStarred || isPeriodic
                                    ? WidgetStateProperty.resolveWith(
                                        (states) =>
                                            states.contains(
                                              WidgetState.selected,
                                            )
                                            ? Colors.green.shade200
                                            : null,
                                      )
                                    : null,
                                secondary: IconButton(
                                  tooltip: isStarred ? '取消星标' : '设为星标',
                                  icon: Icon(
                                    isStarred ? Icons.star : Icons.star_border,
                                    color: isStarred
                                        ? Colors.amber.shade700
                                        : null,
                                  ),
                                  onPressed:
                                      !canStarHabit(
                                        starred,
                                        habit.id,
                                        starLimit,
                                      )
                                      ? null
                                      : () => setDialogState(() {
                                          if (starred.remove(habit.id)) {
                                            if (regularCount >= 3) {
                                              selected.remove(habit.id);
                                            }
                                          } else {
                                            selected.add(habit.id);
                                            starred.add(habit.id);
                                          }
                                        }),
                                ),
                                onChanged:
                                    !isSelected &&
                                        countsQuota &&
                                        regularCount >= 3
                                    ? null
                                    : (checked) => setDialogState(() {
                                        if (checked == true) {
                                          selected.add(habit.id);
                                        } else {
                                          selected.remove(habit.id);
                                          starred.remove(habit.id);
                                        }
                                      }),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: regularCount > 3
                        ? null
                        : () => Navigator.pop(context, (
                            selected: selected,
                            starred: starred,
                          )),
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
    if (result != null) {
      await ref
          .read(databaseProvider)
          .replaceSelectedHabits(
            result.selected,
            starredHabitIds: result.starred,
            now: now,
          );
    }
  }
}

class _GrowthPage extends ConsumerWidget {
  const _GrowthPage({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ref
          .watch(selectedHabitsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('读取养成物失败：$error')),
            data: (habits) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('养成物', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('每个习惯都会养出自己的生命。'),
                const SizedBox(height: 24),
                for (final habit in habits)
                  _GrowthTile(habitId: habit.habitId, now: now),
                const SizedBox(height: 12),
                ref
                    .watch(growthSnapshotProvider(now))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text('读取第二章状态失败：$error'),
                      data: (snapshot) => _ChapterTwoCard(
                        unlocked: snapshot.chapterTwoUnlocked,
                      ),
                    ),
              ],
            ),
          ),
    );
  }
}

class _GrowthTile extends ConsumerWidget {
  const _GrowthTile({required this.habitId, required this.now});
  final String habitId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = habitById(habitId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ref
                .watch(growthSnapshotProvider(now))
                .maybeWhen(
                  data: (snapshot) {
                    final dormant =
                        snapshot.habits[habitId]?.isDormant ?? false;
                    return Icon(
                      dormant ? Icons.eco_outlined : Icons.local_florist,
                      color: dormant
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                      size: 36,
                    );
                  },
                  orElse: () => const SizedBox(width: 36, height: 36),
                ),
            const SizedBox(width: 16),
            Expanded(
              child: ref
                  .watch(growthSnapshotProvider(now))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('读取失败：$error'),
                    data: (snapshot) {
                      final state = snapshot.habits[habitId];
                      if (state == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.stage.label} · 当前 ${state.currentProgress} 点'
                            ' · 累计完成 ${state.historicalCompletions} 次',
                          ),
                          if (state.isDormant) ...[
                            const SizedBox(height: 6),
                            Text(
                              state.recoveryDays > 0
                                  ? '恢复中 ${state.recoveryDays}/3 · 衰减已暂停'
                                  : '休眠中 · 每天按1、2点交替后退',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (state.shouldWarnDormancy) ...[
                            const SizedBox(height: 6),
                            Text(
                              state.inactivityDay >= 7
                                  ? '今晚24:00前完成任一习惯，可避免休眠。'
                                  : '再过1天没有完成习惯，将进入休眠。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: state.stageProgress),
                          const SizedBox(height: 6),
                          Text(
                            state.nextStage == null
                                ? '${state.stage.description} 已达当前最高阶段。'
                                : '${state.stage.description} '
                                      '距${state.nextStage!.label}还差${state.remainingToNext}点。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTwoCard extends StatelessWidget {
  const _ChapterTwoCard({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: unlocked
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(
          unlocked ? Icons.workspace_premium : Icons.lock_outline,
          size: 34,
        ),
        title: const Text('第二章'),
        subtitle: Text(unlocked ? '你已解锁下一段旅程' : '累计完成6次习惯后解锁第二章'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              unlocked ? Icons.workspace_premium : Icons.lock_outline,
              size: 56,
            ),
            title: Text(unlocked ? '第二章徽章' : '第二章尚未解锁'),
            content: Text(
              unlocked
                  ? '你已解锁下一段旅程，现在可以选择新的习惯。第二章习惯内容将在后续开放。'
                  : '所有已选习惯累计完成6次后，就能获得第二章徽章。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地数据？'),
        content: const Text('这会删除已选习惯、打卡记录和积分，并回到首次选择页。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除并重新开始'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(databaseProvider).clearAllData();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('设置', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 32),
          const Text('提醒、隐私和数据设置。'),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _clearData(context, ref),
            icon: const Icon(Icons.restart_alt),
            label: const Text('清除本地数据并重新开始'),
          ),
        ],
      ),
    );
  }
}

class _ReviewPage extends ConsumerStatefulWidget {
  const _ReviewPage({super.key, required this.now});

  final DateTime now;

  @override
  ConsumerState<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<_ReviewPage> {
  late DateTime _month;
  late Future<List<DailyRecordSummary>> _summaries;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.now.year, widget.now.month);
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMonth = DateTime(widget.now.year, widget.now.month);
    if (oldWidget.now.year != widget.now.year ||
        oldWidget.now.month != widget.now.month) {
      setState(() {
        _month = newMonth;
        _load();
      });
    }
  }

  void _load() {
    _summaries = ref.read(databaseProvider).monthlyRecordSummaries(_month);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<DailyRecordSummary>>(
        future: _summaries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('读取复盘记录失败：${snapshot.error}'));
          }
          final summaries = snapshot.data ?? const <DailyRecordSummary>[];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '复盘',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '上个月',
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${_month.year}年${_month.month}月'),
                  IconButton(
                    tooltip: '下个月',
                    onPressed: () => _moveMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('只读回看每天的习惯完成和记录。'),
              const SizedBox(height: 20),
              _MonthCalendar(summaries: summaries, onTap: _showDetails),
              const SizedBox(height: 20),
              selectedHabitsProviderCard(context, ref, summaries, _month),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Color(0xFFE5E2D9)),
                  SizedBox(width: 6),
                  Text('未完成'),
                  SizedBox(width: 16),
                  Icon(Icons.circle, size: 10, color: Color(0xFFE8C8C3)),
                  SizedBox(width: 6),
                  Text('任务未完成'),
                  SizedBox(width: 16),
                  Icon(Icons.circle, size: 10, color: Color(0xFF557A5B)),
                  SizedBox(width: 6),
                  Text('有完成记录'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget selectedHabitsProviderCard(
    BuildContext context,
    WidgetRef ref,
    List<DailyRecordSummary> summaries,
    DateTime month,
  ) => ref
      .watch(selectedHabitsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('读取月度总结失败：$error'),
        data: (habits) => _MonthlyReflectionCard(
          reflection: buildMonthlyReflection(
            summaries: summaries,
            selectedHabitIds: habits.map((habit) => habit.habitId).toSet(),
            month: month,
            today: appDebugNow(),
            starredHabitIds: habits
                .where((habit) => habit.isStarred)
                .map((habit) => habit.habitId)
                .toSet(),
          ),
          starredHabitIds: habits
              .where((habit) => habit.isStarred)
              .map((habit) => habit.habitId)
              .toSet(),
        ),
      );

  void _showDetails(DailyRecordSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _DailyRecordSheet(summary: summary),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.summaries, required this.onTap});

  final List<DailyRecordSummary> summaries;
  final ValueChanged<DailyRecordSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final leading = summaries.first.date.weekday - 1;
    final cells = <Widget>[
      for (var index = 0; index < leading; index++) const SizedBox.shrink(),
      for (final summary in summaries)
        _CalendarDay(summary: summary, onTap: () => onTap(summary)),
    ];
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('一'),
            Text('二'),
            Text('三'),
            Text('四'),
            Text('五'),
            Text('六'),
            Text('日'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: cells,
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.summary, required this.onTap});

  final DailyRecordSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = summary.completedHabitIds.length;
    final color = summary.missedHabitIds.isNotEmpty
        ? const Color(0xFFE8C8C3)
        : count == 0
        ? const Color(0xFFE5E2D9)
        : Color.lerp(
            const Color(0xFFD8E7D6),
            const Color(0xFF557A5B),
            (count / 3).clamp(0.0, 1.0),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 120;
        final activities = compact
            ? const <HabitActivityRecord>[]
            : summary.calendarActivities.take(3);
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${summary.date.day}'),
                if (summary.hasAnyRecord)
                  Text(
                    count > 0 ? '$count项' : '·',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                for (final activity in activities)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      activity.shortTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DailyRecordSheet extends StatelessWidget {
  const _DailyRecordSheet({required this.summary});

  final DailyRecordSummary summary;

  @override
  Widget build(BuildContext context) {
    final habitNames = {for (final habit in allHabits) habit.id: habit.name};
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '${summary.date.year}年${summary.date.month}月${summary.date.day}日',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            _RecordSection(
              title: '完成习惯',
              child: summary.completedHabitIds.isEmpty
                  ? const Text('当天没有有效完成')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final id in summary.completedHabitIds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${habitNames[id] ?? id}  ·  ${_signedPoints(summary.pointsByHabit[id] ?? 0)} 分',
                            ),
                          ),
                      ],
                    ),
            ),
            _RecordSection(title: '获得积分', child: Text('${summary.points} 分')),
            if (summary.review != null)
              _RecordSection(
                title: 'H1 复盘内容',
                child: Text(
                  '决定：${summary.review!.decision}\n'
                  '结果：${summary.review!.result}\n'
                  '下次：${summary.review!.improvement}',
                ),
              ),
            if (summary.focus != null)
              _RecordSection(
                title: 'H2 深度思考',
                child: Text(
                  '${summary.focus!.focusMinutes} 分钟 · ${_timerStatus(summary.focus!.status)}'
                  '${summary.focus!.topic == null ? '' : '\n议题：${summary.focus!.topic}'}',
                ),
              ),
            if (summary.challengeCardIndex != null)
              _RecordSection(
                title: 'H3 挑战卡',
                child: Text(_challengeText(summary.challengeCardIndex!)),
              ),
            if (summary.disconnect != null)
              _RecordSection(
                title: 'H4 睡前断网',
                child: Text(
                  '${summary.disconnect!.minutes} 分钟 · ${_timerStatus(summary.disconnect!.status)}',
                ),
              ),
            for (final activity in summary.activities)
              _RecordSection(
                title: habitNames[activity.habitId] ?? activity.habitId,
                child: Text(_activityDetails(activity)),
              ),
          ],
        ),
      ),
    );
  }

  String _timerStatus(String status) => switch (status) {
    'completed' => '完成',
    'failed' => '未完成/失败',
    _ => status,
  };

  String _challengeText(int index) {
    if (index < 0 || index >= challengeCards.length) return '挑战卡记录不可用';
    return challengeCards[index];
  }

  String _activityDetails(HabitActivityRecord activity) {
    final lines = <String>[activity.primaryText];
    if (activity.secondaryText.isNotEmpty) lines.add(activity.secondaryText);
    if (activity.habitId == 'H7') {
      if (activity.firstValue != null) lines.add('资产投入：${activity.firstValue}');
      if (activity.secondValue != null) {
        lines.add('消费消耗：${activity.secondValue}');
      }
    }
    return lines.join('\n');
  }

  String _signedPoints(int points) => points >= 0 ? '+$points' : '$points';
}

class _RecordSection extends StatelessWidget {
  const _RecordSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

class _MonthlyReflectionCard extends StatelessWidget {
  const _MonthlyReflectionCard({
    required this.reflection,
    required this.starredHabitIds,
  });

  final MonthlyReflection reflection;
  final Set<String> starredHabitIds;

  @override
  Widget build(BuildContext context) {
    final names = {for (final habit in allHabits) habit.id: habit.name};
    String namesFor(Iterable<String> ids) =>
        ids.map((id) => names[id] ?? id).join('、');
    final best = namesFor(reflection.bestHabitIds);
    final hard = namesFor(reflection.hardHabitIds);
    final areas = reflection.progressAreas.join('、');
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月小结', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '完成 ${reflection.totalCompletions} 次 · 获得 ${reflection.totalPoints} 积分',
            ),
            const SizedBox(height: 16),
            _MonthlyHabitBarChart(
              counts: reflection.completionCounts,
              starredHabitIds: starredHabitIds,
            ),
            const SizedBox(height: 14),
            _ReflectionLine(
              icon: Icons.favorite_outline,
              title: '最容易坚持',
              text: best.isEmpty ? '先从一个习惯开始' : best,
            ),
            _ReflectionLine(
              icon: Icons.refresh,
              title: '最容易放弃',
              text: hard.isEmpty ? '还没有足够记录' : hard,
            ),
            _ReflectionLine(
              icon: Icons.trending_up,
              title: '它正在帮助你',
              text: areas.isEmpty ? '慢慢找到自己的节奏' : areas,
            ),
            _AiMonthlyInsight(
              reflection: reflection,
              starredHabitIds: starredHabitIds,
            ),
            const Divider(height: 22),
            Text(reflection.encouragement),
          ],
        ),
      ),
    );
  }
}

class _AiMonthlyInsight extends ConsumerWidget {
  const _AiMonthlyInsight({
    required this.reflection,
    required this.starredHabitIds,
  });

  final MonthlyReflection reflection;
  final Set<String> starredHabitIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<MonthlyInsight>(
        future: ref
            .read(monthlyInsightGeneratorProvider)
            .generate(
              MonthlyInsightRequest.fromReflection(
                reflection,
                starredHabitIds: starredHabitIds,
              ),
            ),
        builder: (context, snapshot) {
          final insight = snapshot.data;
          if (insight == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分析建议', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _InsightSection(
                  title: '你已建立的节奏',
                  theme: insight.strengthTheme,
                  count: insight.strengthCount,
                  text: insight.strengthText,
                  color: const Color(0xFFE3EFE2),
                ),
                const SizedBox(height: 8),
                _InsightSection(
                  title: '下一步值得照顾',
                  theme: insight.focusTheme,
                  count: insight.focusCount,
                  text: insight.focusText,
                  color: const Color(0xFFF1E8D6),
                ),
                const SizedBox(height: 8),
                _InsightSection(
                  title: '一个可执行的安排',
                  text: insight.nextStep,
                  color: const Color(0xFFE8EDF0),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 生成建议预览',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        },
      );
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.text,
    required this.color,
    this.theme,
    this.count,
  });

  final String title;
  final String text;
  final Color color;
  final String? theme;
  final int? count;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.labelLarge),
            ),
            if (theme != null)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('$theme · ${count ?? 0}次'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(text),
      ],
    ),
  );
}

class _MonthlyHabitBarChart extends StatelessWidget {
  const _MonthlyHabitBarChart({
    required this.counts,
    required this.starredHabitIds,
  });

  final Map<String, int> counts;
  final Set<String> starredHabitIds;

  @override
  Widget build(BuildContext context) {
    final names = {for (final habit in allHabits) habit.id: habit.name};
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 31);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('习惯完成次数', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final category in HabitCategory.values) ...[
          if (counts.keys.any(
            (id) => habitCategory(id, starredHabitIds) == category,
          )) ...[
            Text(
              _categoryLabel(category),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
          ],
          for (final entry in counts.entries.where(
            (entry) => habitCategory(entry.key, starredHabitIds) == category,
          )) ...[
            Row(
              children: [
                SizedBox(width: 28, child: Text(entry.key)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: entry.value / maxCount,
                    minHeight: 12,
                    color: starredHabitIds.contains(entry.key)
                        ? _starredHabitColor
                        : isPeriodicHabit(entry.key)
                        ? _periodicHabitColor
                        : _normalHabitColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 24, child: Text('${entry.value}')),
              ],
            ),
            Text(
              names[entry.key] ?? entry.key,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  String _categoryLabel(HabitCategory category) => switch (category) {
    HabitCategory.normal => '普通习惯',
    HabitCategory.periodic => '周期习惯',
    HabitCategory.starred => '星标习惯',
  };
}

class _ReflectionLine extends StatelessWidget {
  const _ReflectionLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('$title：$text')),
      ],
    ),
  );
}

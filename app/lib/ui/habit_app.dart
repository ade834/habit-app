import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../domain/daily_records.dart';
import '../domain/habit.dart';
import '../domain/habit_growth.dart';
import '../domain/habit_tools.dart';
import '../domain/monthly_reflection.dart';
import 'habit_tools_page.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final startupRecoveryProvider = FutureProvider<void>((ref) async {
  await ref.watch(databaseProvider).recoverInterruptedDisconnectSession();
});

final selectedHabitsProvider = StreamProvider<List<HabitSelection>>(
  (ref) => ref.watch(databaseProvider).watchSelectedHabits(),
);

final todayCompletedProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchTodayCompletedHabitIds(),
);

final pointBalanceProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchPointBalance(),
);

final completionCountProvider = StreamProvider.family<int, String>(
  (ref, habitId) => ref.watch(databaseProvider).watchCompletionCount(habitId),
);

final growthSnapshotProvider = StreamProvider<GrowthSnapshot>(
  (ref) => ref.watch(databaseProvider).watchGrowthSnapshot(),
);

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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text('从今天开始', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text('选择1到3个习惯，让它在你手里一点点长大。'),
            const SizedBox(height: 24),
            for (final habit in firstHabits)
              Card(
                child: CheckboxListTile(
                  value: _selected.contains(habit.id),
                  title: Text(habit.name),
                  subtitle: Text(habit.description),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true && _selected.length < 3) {
                        _selected.add(habit.id);
                      } else if (checked == false) {
                        _selected.remove(habit.id);
                      }
                    });
                  },
                ),
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
              onPressed: _selected.isEmpty || _saving ? null : _save,
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

  static const _pages = [
    _TodayPage(),
    _HabitsPage(),
    _GrowthPage(),
    _ReviewPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _index == 4
          ? const _SettingsPage()
          : _index == 3
          ? _ReviewPage(key: ValueKey(_reviewVersion))
          : _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          if (value == 3) _reviewVersion++;
          _index = value;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '今天'),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: '习惯',
          ),
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
  const _TodayPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedHabitsProvider);
    final completed = ref.watch(todayCompletedProvider);
    final points = ref.watch(pointBalanceProvider);
    final growth = ref.watch(growthSnapshotProvider);
    return SafeArea(
      child: selected.when(
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
                      '今天',
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
                _TodayHabitCard(
                  habit: habit,
                  completed: done.contains(habit.habitId),
                ),
              if (habits.isEmpty) const Center(child: Text('还没有选择习惯。')),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHabitCard extends ConsumerWidget {
  const _TodayHabitCard({required this.habit, required this.completed});

  final HabitSelection habit;
  final bool completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = firstHabits.firstWhere(
      (item) => item.id == habit.habitId,
      orElse: () => HabitDefinition(
        id: habit.habitId,
        name: habit.habitId,
        description: '',
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(definition.name),
        subtitle: Text(completed ? '今天已完成，做得很好。' : definition.description),
        trailing: completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => habitToolPage(
                        habitId: habit.habitId,
                        database: ref.read(databaseProvider),
                      ),
                    ),
                  );
                },
                child: const Text('开始'),
              ),
      ),
    );
  }
}

class _HabitsPage extends ConsumerWidget {
  const _HabitsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ref
          .watch(selectedHabitsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('读取习惯失败：$error')),
            data: (habits) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('习惯', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('你选择的习惯会显示在这里。'),
                const SizedBox(height: 24),
                for (final habit in habits)
                  _HabitProgressTile(habitId: habit.habitId),
              ],
            ),
          ),
    );
  }
}

class _HabitProgressTile extends ConsumerWidget {
  const _HabitProgressTile({required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = firstHabits.firstWhere((item) => item.id == habitId);
    return Card(
      child: ref
          .watch(growthSnapshotProvider)
          .when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (error, _) => ListTile(title: Text('读取进度失败：$error')),
            data: (snapshot) {
              final state = snapshot.habits[habitId];
              if (state == null) return const SizedBox.shrink();
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => habitToolPage(
                      habitId: habitId,
                      database: ref.read(databaseProvider),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              definition.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前 ${state.currentProgress} 点 · ${state.stage.label}'
                        '（累计完成 ${state.historicalCompletions} 次）',
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: state.stageProgress),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _GrowthPage extends ConsumerWidget {
  const _GrowthPage();

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
                for (final habit in habits) _GrowthTile(habitId: habit.habitId),
                const SizedBox(height: 12),
                ref
                    .watch(growthSnapshotProvider)
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
  const _GrowthTile({required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = firstHabits.firstWhere((item) => item.id == habitId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ref
                .watch(growthSnapshotProvider)
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
                  .watch(growthSnapshotProvider)
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
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            const _DebugToolsCard(),
          ],
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

class _DebugToolsCard extends ConsumerWidget {
  const _DebugToolsCard();

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String habitId,
    int amount,
  ) async {
    final inserted = await ref
        .read(databaseProvider)
        .debugAddCompletionPoints(habitId: habitId, amount: amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已增加 $inserted 个测试点')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedHabitsProvider);
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ExpansionTile(
        leading: const Icon(Icons.science_outlined),
        title: const Text('开发测试'),
        subtitle: const Text('仅调试版本可见，发布前删除'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          selected.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('读取失败：$error'),
            data: (habits) => Column(
              children: [
                for (final habit in habits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      firstHabits
                          .firstWhere((item) => item.id == habit.habitId)
                          .name,
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _add(context, ref, habit.habitId, 1),
                          child: const Text('+1测试点'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _add(context, ref, habit.habitId, 5),
                          child: const Text('+5测试点'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPage extends ConsumerStatefulWidget {
  const _ReviewPage({super.key});

  @override
  ConsumerState<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<_ReviewPage> {
  late DateTime _month;
  late Future<List<DailyRecordSummary>> _summaries;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
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
          ),
        ),
      );

  void _showDetails(DailyRecordSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DailyRecordSheet(summary: summary),
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
    final color = count == 0
        ? const Color(0xFFE5E2D9)
        : Color.lerp(
            const Color(0xFFD8E7D6),
            const Color(0xFF557A5B),
            (count / 3).clamp(0.0, 1.0),
          );
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${summary.date.day}'),
            if (summary.hasAnyRecord)
              Text(
                count > 0 ? '$count项' : '·',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyRecordSheet extends StatelessWidget {
  const _DailyRecordSheet({required this.summary});

  final DailyRecordSummary summary;

  @override
  Widget build(BuildContext context) {
    final habitNames = {for (final habit in firstHabits) habit.id: habit.name};
    final completed = summary.completedHabitIds
        .map((id) => habitNames[id] ?? id)
        .join('、');
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
              child: Text(completed.isEmpty ? '当天没有有效完成' : completed),
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
  const _MonthlyReflectionCard({required this.reflection});

  final MonthlyReflection reflection;

  @override
  Widget build(BuildContext context) {
    final names = {for (final habit in firstHabits) habit.id: habit.name};
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
            _MonthlyHabitBarChart(counts: reflection.completionCounts),
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
            const Divider(height: 22),
            Text(reflection.encouragement),
          ],
        ),
      ),
    );
  }
}

class _MonthlyHabitBarChart extends StatelessWidget {
  const _MonthlyHabitBarChart({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final names = {for (final habit in firstHabits) habit.id: habit.name};
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 31);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('习惯完成次数', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in counts.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${entry.value}'),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 88 * entry.value / maxCount + 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          names[entry.key] ?? entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
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

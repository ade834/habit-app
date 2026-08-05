import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../domain/habit.dart';
import 'habit_tools_page.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
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
        .watch(selectedHabitsProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) =>
              Scaffold(body: Center(child: Text('读取本地数据失败：$error'))),
          data: (selected) =>
              selected.isEmpty ? const _OnboardingPage() : const _MainShell(),
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

  static const _pages = [
    _TodayPage(),
    _HabitsPage(),
    _GrowthPage(),
    _PlaceholderPage(
      icon: Icons.edit_note_outlined,
      title: '复盘',
      text: '记录决定、结果和下一次改进。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _index == 4 ? const _SettingsPage() : _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
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
          .watch(completionCountProvider(habitId))
          .when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (error, _) => ListTile(title: Text('读取进度失败：$error')),
            data: (count) {
              final progress = (count / 3).clamp(0.0, 1.0);
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
                      Text('累计完成 $count 次 · ${count >= 3 ? '发芽' : '种子'}'),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: progress),
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
              ],
            ),
          ),
    );
  }
}

class _GrowthTile extends ConsumerWidget {
  const _GrowthTile({required this.habitId});
  final String habitId;

  static const _sproutTarget = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = firstHabits.firstWhere((item) => item.id == habitId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.local_florist,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ref
                  .watch(completionCountProvider(habitId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('读取失败：$error'),
                    data: (count) {
                      final hasSprouted = count >= _sproutTarget;
                      final remaining = _sproutTarget - count;
                      final progress = (count / _sproutTarget).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasSprouted
                                ? '已发芽 · 累计完成 $count 次'
                                : '种子 · $count/$_sproutTarget',
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 6),
                          Text(
                            hasSprouted
                                ? '你的坚持已经让它发芽了。'
                                : '再完成 $remaining 次即可发芽',
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const Spacer(),
            Center(
              child: Icon(
                icon,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Chip(label: Text('即将开放'))),
            const SizedBox(height: 12),
            Center(child: Text(text, textAlign: TextAlign.center)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

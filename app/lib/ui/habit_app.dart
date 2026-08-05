import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../domain/habit.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final selectedHabitsProvider = StreamProvider<List<HabitSelection>>(
  (ref) => ref.watch(databaseProvider).watchSelectedHabits(),
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
    _PlaceholderPage(
      icon: Icons.home_outlined,
      title: '今天',
      text: '今天要照顾哪些习惯？',
    ),
    _PlaceholderPage(
      icon: Icons.check_circle_outline,
      title: '习惯',
      text: '你选择的习惯会显示在这里。',
    ),
    _PlaceholderPage(
      icon: Icons.local_florist_outlined,
      title: '养成物',
      text: '每个习惯都会养出自己的生命。',
    ),
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
            Center(child: Text(text, textAlign: TextAlign.center)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

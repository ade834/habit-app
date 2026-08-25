import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';
import '../domain/habit_tools.dart';
import '../domain/habit.dart';
import '../domain/debug_clock.dart';

Widget habitToolPage({required String habitId, required AppDatabase database}) {
  return switch (habitId) {
    'H1' => ReviewToolPage(database: database),
    'H2' => FocusToolPage(database: database),
    'H3' => ChallengeToolPage(database: database),
    'H4' => DisconnectToolPage(database: database),
    'H5' ||
    'H6' ||
    'H7' ||
    'H8' ||
    'H9' ||
    'H10' ||
    'H12' => LaterHabitToolPage(habitId: habitId, database: database),
    'H11' => TravelToolPage(database: database),
    _ => const Scaffold(body: Center(child: Text('该习惯工具尚未开放。'))),
  };
}

class LaterHabitToolPage extends StatefulWidget {
  const LaterHabitToolPage({
    super.key,
    required this.habitId,
    required this.database,
  });
  final String habitId;
  final AppDatabase database;

  @override
  State<LaterHabitToolPage> createState() => _LaterHabitToolPageState();
}

class _LaterHabitToolPageState extends State<LaterHabitToolPage> {
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _firstNumber = TextEditingController();
  final _secondNumber = TextEditingController();
  bool _saving = false;

  static const _labels = <String, (String, String, String)>{
    'H5': ('联系了谁？', '你们聊了什么？（选填）', '本周完成'),
    'H6': ('清理了哪个信息源？', '为什么它不值得继续占用注意力？（选填）', '完成清理'),
    'H7': ('本周最大的财务发现是什么？', '下周想调整什么？（选填）', '完成本周盘点'),
    'H8': ('你拒绝了什么？', '你守住了哪条边界？（选填）', '今天守住了边界'),
    'H9': ('这次输出讲清了什么？', '你能讲给我听听么？', '完成一次输出'),
    'H10': ('读完了哪本跨界书？', '最重要的一条收获（选填）', '完成本月阅读'),
    'H11': ('这次独自去了哪里？', '旅途中重新看见了什么？（选填）', '完成本年旅行'),
    'H12': ('今天必须承认的真话是什么？', '明天采取什么行动？（选填）', '记下这句真话'),
  };

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    _firstNumber.dispose();
    _secondNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_primary.text.trim().isEmpty) return;
    if (widget.habitId == 'H7' &&
        (!isOptionalNumber(_firstNumber.text) ||
            !isOptionalNumber(_secondNumber.text))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('资产投入和消费消耗仅能填写数字，也可留空。')));
      return;
    }
    setState(() => _saving = true);
    final completed = await widget.database.saveLaterHabitActivity(
      habitId: widget.habitId,
      primaryText: _primary.text,
      secondaryText: _secondary.text,
      firstValue: double.tryParse(_firstNumber.text),
      secondValue: double.tryParse(_secondNumber.text),
      now: appDebugNow(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (completed) {
      Navigator.pop(context, _pointsForHabit(widget.habitId));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('这个周期已经完成过了。')));
  }

  int _pointsForHabit(String habitId) => switch (habitId) {
    'H5' || 'H7' => 3,
    'H10' => 4,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final definition = habitById(widget.habitId);
    final labels = _labels[widget.habitId]!;
    final finance = widget.habitId == 'H7';
    return Scaffold(
      appBar: AppBar(title: Text(definition.name)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            definition.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (const {'H5', 'H7', 'H10', 'H11'}.contains(widget.habitId))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '这是周期任务。今天没完成也不用丢弃，可以暂存到之后完成；完成后按实际完成日期记录。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _primary,
            minLines: 2,
            maxLines: 4,
            maxLength: 5,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: labels.$1,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secondary,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: labels.$2,
              border: const OutlineInputBorder(),
            ),
          ),
          if (finance) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNumber,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '资产投入',
                      helperText: '选填，只能填数字',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _secondNumber,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '消费消耗',
                      helperText: '选填，只能填数字',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || _primary.text.trim().isEmpty ? null : _save,
            child: Text(_saving ? '保存中…' : labels.$3),
          ),
        ],
      ),
    );
  }
}

class TravelToolPage extends StatefulWidget {
  const TravelToolPage({super.key, required this.database});
  final AppDatabase database;

  @override
  State<TravelToolPage> createState() => _TravelToolPageState();
}

class _TravelToolPageState extends State<TravelToolPage> {
  final _destination = TextEditingController();
  final _focus = TextEditingController();
  final _preparation = TextEditingController();
  final _summary = TextEditingController();
  late Future<TravelPlan?> _plan;
  int _plannedDays = 3;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.database.travelPlanForYear(now: appDebugNow());
    for (final controller in [_destination, _focus, _summary]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _destination.dispose();
    _focus.dispose();
    _preparation.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    setState(() => _saving = true);
    await widget.database.saveTravelPlan(
      destination: _destination.text,
      days: _plannedDays,
      focus: _focus.text,
      preparation: _preparation.text,
      now: appDebugNow(),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _complete(TravelPlan plan) async {
    setState(() => _saving = true);
    final completed = await widget.database.saveLaterHabitActivity(
      habitId: 'H11',
      primaryText: plan.destination,
      secondaryText: _summary.text,
      now: appDebugNow(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (completed) {
      Navigator.pop(context, 99);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今年的独自旅行已经完成过了。')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('每年一次独自旅行')),
    body: FutureBuilder<TravelPlan?>(
      future: _plan,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final plan = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: plan == null ? _guideFields() : _summaryFields(plan),
        );
      },
    ),
  );

  List<Widget> _guideFields() => [
    Text('先为自己设计一次真正的独处旅程。', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    const Text('选一个目的地，留出不被日常角色打扰的时间。路线不必塞满，但每天要有一段只属于自己的探索。'),
    const SizedBox(height: 20),
    TextField(
      controller: _destination,
      decoration: const InputDecoration(
        labelText: '想去哪里？',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    InputDecorator(
      decoration: const InputDecoration(
        labelText: '计划几天？',
        border: OutlineInputBorder(),
      ),
      child: SizedBox(
        height: 116,
        child: CupertinoPicker(
          itemExtent: 40,
          scrollController: FixedExtentScrollController(
            initialItem: _plannedDays - 1,
          ),
          onSelectedItemChanged: (index) =>
              setState(() => _plannedDays = index + 1),
          children: [
            for (var days = 1; days <= 30; days++)
              Center(
                child: Text(
                  '$days 天',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _focus,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: '这趟旅行最想想清楚什么？',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _preparation,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: '路线、预算和准备事项（选填）',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 16),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('向导建议', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• 每天只安排一个核心地点\n• 留出至少一小时独自行走\n• 选一顿饭不看手机\n• 每晚记下今天看见的自己'),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed:
          _saving ||
              _destination.text.trim().isEmpty ||
              _focus.text.trim().isEmpty
          ? null
          : _savePlan,
      child: Text(_saving ? '保存中…' : '保存旅行计划'),
    ),
  ];

  List<Widget> _summaryFields(TravelPlan plan) => [
    Text(
      '${plan.destination} · ${plan.days}天',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 8),
    Text('这趟旅行想想清楚：${plan.focus}'),
    if (plan.preparation.isNotEmpty) Text('准备：${plan.preparation}'),
    const SizedBox(height: 24),
    const Text('旅行回来后，再完成这一步。'),
    const SizedBox(height: 12),
    TextField(
      controller: _summary,
      minLines: 4,
      maxLines: 8,
      decoration: const InputDecoration(
        labelText: '旅途中重新看见了什么？',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: _saving || _summary.text.trim().isEmpty
          ? null
          : () => _complete(plan),
      child: Text(_saving ? '保存中…' : '完成旅行 · 获得99积分'),
    ),
  ];
}

class ReviewToolPage extends StatefulWidget {
  const ReviewToolPage({super.key, required this.database});
  final AppDatabase database;

  @override
  State<ReviewToolPage> createState() => _ReviewToolPageState();
}

class _ReviewToolPageState extends State<ReviewToolPage> {
  final _decision = TextEditingController();
  final _result = TextEditingController();
  final _improvement = TextEditingController();
  int _daysAgo = 0;
  bool _saving = false;

  int get _count => reviewCharacterCount(
    '${_decision.text}${_result.text}${_improvement.text}',
  );

  DateTime get _date => DateTime.now().subtract(Duration(days: _daysAgo));

  @override
  void initState() {
    super.initState();
    for (final controller in [_decision, _result, _improvement]) {
      controller.addListener(_refresh);
    }
    _load();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final entry = await widget.database.reviewForDate(_date);
    if (!mounted || entry == null) return;
    _decision.text = entry.decision;
    _result.text = entry.result;
    _improvement.text = entry.improvement;
  }

  @override
  void dispose() {
    _decision.dispose();
    _result.dispose();
    _improvement.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final completed = await widget.database.saveReview(
      date: _date,
      decision: _decision.text,
      result: _result.text,
      improvement: _improvement.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, completed ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每天100字复盘')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('每天花2分钟，写下一个决定、一个结果、一个改进。100字不用多，但要真。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _daysAgo,
            decoration: const InputDecoration(labelText: '复盘日期'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('今天')),
              DropdownMenuItem(value: 1, child: Text('昨天（补录不积分）')),
              DropdownMenuItem(value: 2, child: Text('2天前（补录不积分）')),
              DropdownMenuItem(value: 3, child: Text('3天前（补录不积分）')),
            ],
            onChanged: (value) async {
              _daysAgo = value ?? 0;
              _decision.clear();
              _result.clear();
              _improvement.clear();
              await _load();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _ReviewField(controller: _decision, label: '今天做了什么决定？'),
          _ReviewField(controller: _result, label: '结果怎么样？'),
          _ReviewField(controller: _improvement, label: '下次想怎么改？'),
          Text(
            '有效字数：$_count / 100（不计标点和空格）',
            style: TextStyle(
              color: _count >= 100
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _count < 100 ? null : _save,
            child: Text(
              _saving
                  ? '保存中…'
                  : _daysAgo == 0
                  ? '提交复盘'
                  : '保存补录',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewField extends StatelessWidget {
  const _ReviewField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class FocusToolPage extends StatefulWidget {
  const FocusToolPage({super.key, required this.database});
  final AppDatabase database;

  @override
  State<FocusToolPage> createState() => _FocusToolPageState();
}

class _FocusToolPageState extends State<FocusToolPage> {
  Timer? _ticker;
  final _customTopicController = TextEditingController();
  late final List<String> _recommendedTopics;
  String? _selectedTopic;
  bool _useCustomTopic = false;

  @override
  void initState() {
    super.initState();
    _recommendedTopics = dailyThinkingTopics(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _customTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TimerScaffold(
    title: '30分钟深度思考',
    introduction: '放下手机，给自己30分钟不被打断的时间。想清楚一件真正重要的事。',
    stream: widget.database.watchActiveTimer('H2'),
    emptyAction: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '今天我为你推荐了三个值得想想的问题：',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _useCustomTopic ? null : _selectedTopic,
          onChanged: (value) => setState(() {
            _useCustomTopic = false;
            _selectedTopic = value;
          }),
          child: Column(
            children: [
              for (final topic in _recommendedTopics)
                Card(
                  child: RadioListTile<String>(
                    value: topic,
                    title: Text(topic),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customTopicController,
          decoration: const InputDecoration(
            labelText: '我有自己重要、值得想想的事',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {
            _useCustomTopic = value.trim().isNotEmpty;
          }),
        ),
        if (_chosenTopic != null) ...[
          const SizedBox(height: 16),
          Text('今天我为你推荐的思考是“${_chosenTopic!}”。当然，你也可以有自己重要、值得想想的事。现在让我们开始吧。'),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _chosenTopic == null
              ? null
              : () => widget.database.startTimer(
                  habitId: 'H2',
                  targetSeconds: 30 * 60,
                  focusTopic: _chosenTopic,
                ),
          child: const Text('选好了，开始30分钟'),
        ),
      ],
    ),
    builder: (session) {
      final progress = timerProgress(
        startedAt: session.startedAt,
        now: DateTime.now(),
        accumulatedPauseSeconds: session.accumulatedPauseSeconds,
        pausedAt: session.pausedAt,
      );
      final remaining = (session.targetSeconds - progress.focusSeconds).clamp(
        0,
        1 << 31,
      );
      final pauseExceeded = progress.pauseSeconds > 300;
      if (pauseExceeded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.database.endTimerEarly(session.id, DateTime.now());
        });
      }
      return Column(
        children: [
          if (session.focusTopic != null) ...[
            Text('今天思考：${session.focusTopic}'),
            const SizedBox(height: 12),
          ],
          const Text('专注中，先别看手机。'),
          const SizedBox(height: 20),
          Text(
            _formatSeconds(remaining),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          Text('已暂停 ${_formatSeconds(progress.pauseSeconds)} / 05:00'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              if (session.status == 'running')
                OutlinedButton(
                  onPressed: () =>
                      widget.database.pauseTimer(session.id, DateTime.now()),
                  child: const Text('暂停'),
                )
              else
                OutlinedButton(
                  onPressed: () =>
                      widget.database.resumeTimer(session.id, DateTime.now()),
                  child: const Text('继续'),
                ),
              FilledButton(
                onPressed: remaining == 0
                    ? () async {
                        final completed = await widget.database
                            .finishFocusTimer(session.id, DateTime.now());
                        if (context.mounted) {
                          Navigator.pop(context, completed ? 1 : 0);
                        }
                      }
                    : null,
                child: const Text('完成'),
              ),
              TextButton(
                onPressed: () =>
                    widget.database.endTimerEarly(session.id, DateTime.now()),
                child: const Text('提前结束'),
              ),
            ],
          ),
        ],
      );
    },
  );

  String? get _chosenTopic {
    if (_useCustomTopic) {
      final custom = _customTopicController.text.trim();
      return custom.isEmpty ? null : custom;
    }
    return _selectedTopic;
  }
}

class ChallengeToolPage extends StatefulWidget {
  const ChallengeToolPage({super.key, required this.database});
  final AppDatabase database;

  @override
  State<ChallengeToolPage> createState() => _ChallengeToolPageState();
}

class _ChallengeToolPageState extends State<ChallengeToolPage> {
  late Future<ChallengeDraw> _draw;

  @override
  void initState() {
    super.initState();
    _draw = widget.database.challengeForToday();
  }

  Future<void> _swap() async {
    final swapped = await widget.database.swapChallenge();
    if (!mounted) return;
    setState(() {
      _draw = Future.value(swapped);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          swapped.swapCount <= 3
              ? '已获取第 ${swapped.swapCount} 张新挑战。'
              : '已切换到前三张挑战之一。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('做一件不舒服的事')),
    body: FutureBuilder<ChallengeDraw>(
      future: _draw,
      builder: (context, snapshot) {
        final draw = snapshot.data;
        if (draw == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('舒适区外一小步，才是真正的成长区。'),
            const SizedBox(height: 8),
            Text(
              '500个成长挑战之一 · 编号 ${draw.cardIndex + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  challengeCards[draw.cardIndex],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _swap,
              icon: const Icon(Icons.swap_horiz),
              label: Text(
                draw.swapCount < 3
                    ? '换一张（还可获取 ${3 - draw.swapCount} 张新挑战）'
                    : '在前三张挑战中切换',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final completed = await widget.database.recordCompletion(
                  habitId: 'H3',
                  occurredAt: DateTime.now(),
                );
                if (context.mounted) Navigator.pop(context, completed ? 1 : 0);
              },
              child: const Text('我做到了'),
            ),
          ],
        );
      },
    ),
  );
}

class DisconnectToolPage extends StatefulWidget {
  const DisconnectToolPage({super.key, required this.database});
  final AppDatabase database;

  @override
  State<DisconnectToolPage> createState() => _DisconnectToolPageState();
}

class _DisconnectToolPageState extends State<DisconnectToolPage>
    with WidgetsBindingObserver {
  int _minutes = 30;
  Timer? _ticker;
  StreamSubscription<DisconnectAttemptState>? _attemptSubscription;
  int? _activeSessionId;
  bool _completing = false;
  DisconnectAttemptState _attemptState = const DisconnectAttemptState(
    consecutiveFailures: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attemptSubscription = widget.database.watchDisconnectAttemptState().listen(
      (state) {
        if (mounted) setState(() => _attemptState = state);
      },
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _attemptSubscription?.cancel();
    final sessionId = _activeSessionId;
    if (sessionId != null && !_completing) {
      widget.database.endTimerEarly(sessionId, DateTime.now());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notification/Control Center, screen lock, and backgrounding must not
    // interrupt the timestamp-based H4 session. On resume, rebuilding causes
    // the remaining time to be recalculated from startedAt; if it reached
    // zero while away, the existing post-frame completion path handles it.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Future<void> _complete(TimerSession session) async {
    if (_completing) return;
    _completing = true;
    final completed = await widget.database.completeDisconnectTimer(
      session.id,
      DateTime.now(),
    );
    _activeSessionId = null;
    if (completed && mounted) {
      Navigator.pop(context, 1);
    }
    _completing = false;
  }

  @override
  Widget build(BuildContext context) => _TimerScaffold(
    title: '睡前断网',
    introduction: '给大脑一个真正安静的收尾，而不是刷到睡着。',
    stream: widget.database.watchActiveTimer('H4'),
    emptyAction: Column(
      children: [
        if (_attemptState.consecutiveFailures > 0)
          Card(
            color: _attemptState.isLocked
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                disconnectAttemptMessage(
                  _attemptState.consecutiveFailures,
                  lockedUntilLabel: _attemptState.lockedUntil == null
                      ? null
                      : _formatDateTime(_attemptState.lockedUntil!),
                ),
              ),
            ),
          ),
        if (_attemptState.consecutiveFailures > 0) const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 15, label: Text('15分钟')),
            ButtonSegment(value: 30, label: Text('30分钟')),
            ButtonSegment(value: 60, label: Text('60分钟')),
          ],
          selected: {_minutes},
          onSelectionChanged: _attemptState.isLocked
              ? null
              : (value) => setState(() => _minutes = value.first),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _attemptState.isLocked
              ? null
              : () => widget.database.startTimer(
                  habitId: 'H4',
                  targetSeconds: _minutes * 60,
                ),
          child: Text(_attemptState.isLocked ? '10小时冷却中' : '开始断网仪式'),
        ),
        const SizedBox(height: 16),
        const Text('开始后无暂停，归零会自动完成并获得1积分。'),
        const SizedBox(height: 8),
        const Text('离开本页面会重置；下拉通知中心、锁屏或切到后台不会中断。'),
      ],
    ),
    builder: (session) {
      _activeSessionId = session.id;
      final remaining =
          (session.targetSeconds -
                  DateTime.now().difference(session.startedAt).inSeconds)
              .clamp(0, 1 << 31);
      if (remaining == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _complete(session));
      }
      return Column(
        children: [
          Text('接下来${session.targetSeconds ~/ 60}分钟，试着不碰手机。倒计时开始。'),
          const SizedBox(height: 20),
          Text(
            _formatSeconds(remaining),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 20),
          const Text('保持在本页面，归零后将自动完成并获得1积分。'),
          const SizedBox(height: 12),
          const Text('离开本页面会重置；下拉通知中心、锁屏或切到后台不会中断。'),
        ],
      );
    },
  );
}

class _TimerScaffold extends StatelessWidget {
  const _TimerScaffold({
    required this.title,
    required this.introduction,
    required this.stream,
    required this.emptyAction,
    required this.builder,
  });

  final String title;
  final String introduction;
  final Stream<TimerSession?> stream;
  final Widget emptyAction;
  final Widget Function(TimerSession session) builder;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: StreamBuilder<TimerSession?>(
      stream: stream,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(introduction),
          const SizedBox(height: 32),
          snapshot.data == null ? emptyAction : builder(snapshot.data!),
        ],
      ),
    ),
  );
}

String _formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) =>
    '${value.month}月${value.day}日 '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

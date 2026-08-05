import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../domain/habit_tools.dart';

Widget habitToolPage({required String habitId, required AppDatabase database}) {
  return switch (habitId) {
    'H1' => ReviewToolPage(database: database),
    'H2' => FocusToolPage(database: database),
    'H3' => ChallengeToolPage(database: database),
    'H4' => DisconnectToolPage(database: database),
    _ => const Scaffold(body: Center(child: Text('该习惯工具尚未开放。'))),
  };
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _daysAgo > 0
              ? '补录已保存，不发放积分。'
              : completed
              ? '记下来了，这就是进步的证据。'
              : '今日复盘已保存。',
        ),
      ),
    );
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
                    ? () => widget.database.finishFocusTimer(
                        session.id,
                        DateTime.now(),
                      )
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
                await widget.database.recordCompletion(
                  habitId: 'H3',
                  occurredAt: DateTime.now(),
                );
                if (context.mounted) Navigator.pop(context);
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
  static const _maximumFailures = 3;

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
    if (state != AppLifecycleState.resumed) {
      final sessionId = _activeSessionId;
      if (sessionId != null && !_completing) {
        _activeSessionId = null;
        widget.database.endTimerEarly(sessionId, DateTime.now());
        if (mounted) Navigator.maybePop(context);
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今晚，你比手机先睡着的样子，很好看。')));
      Navigator.pop(context);
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
                _attemptState.isLocked
                    ? '这次任务已失败。你连续3次离开倒计时，现在不能再开始。先放下自责，但也请认真对待自己的承诺。${_formatDateTime(_attemptState.lockedUntil!)}后可再尝试。'
                    : '你刚才离开了倒计时，所以本次已重置。可以重新开始，但请不要轻易中途离开；连续3次将失败并锁定10小时，你还剩 ${_maximumFailures - _attemptState.consecutiveFailures} 次机会。',
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
        const Text('离开页面或切出 App，本次倒计时将重置。'),
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
          const Text('离开页面或切出 App，本次倒计时将重置。'),
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

int reviewCharacterCount(String text) {
  final punctuationOrSpace = RegExp(r'[\s\p{P}]', unicode: true);
  return text.runes
      .map(String.fromCharCode)
      .where((character) => !punctuationOrSpace.hasMatch(character))
      .length;
}

bool reviewMeetsTarget(Iterable<String> sections) =>
    reviewCharacterCount(sections.join()) >= 100;

bool isAllowedReviewDate(DateTime target, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(target.year, target.month, target.day);
  final daysAgo = today.difference(date).inDays;
  return daysAgo >= 0 && daysAgo <= 3;
}

class TimerProgress {
  const TimerProgress({required this.focusSeconds, required this.pauseSeconds});

  final int focusSeconds;
  final int pauseSeconds;

  bool meetsFocusTarget(int targetSeconds) =>
      focusSeconds >= targetSeconds && pauseSeconds <= 300;
}

TimerProgress timerProgress({
  required DateTime startedAt,
  required DateTime now,
  required int accumulatedPauseSeconds,
  DateTime? pausedAt,
}) {
  final currentPause = pausedAt == null
      ? 0
      : now.difference(pausedAt).inSeconds.clamp(0, 1 << 31);
  final pauseSeconds = accumulatedPauseSeconds + currentPause;
  final elapsedSeconds = now.difference(startedAt).inSeconds.clamp(0, 1 << 31);
  return TimerProgress(
    focusSeconds: (elapsedSeconds - pauseSeconds).clamp(0, 1 << 31),
    pauseSeconds: pauseSeconds,
  );
}

final challengeCards = _buildChallengeCards();

List<String> _buildChallengeCards() {
  const actionsByCategory = [
    [
      '给一个很久没联系的人发条真诚的消息',
      '在会议或群里说出一个真实观点',
      '主动向一位陌生人友好地打招呼',
      '向一位你欣赏的人具体表达赞赏',
      '开口请教一个你担心显得基础的问题',
      '把一个没说清楚的误会主动讲清楚',
      '对一个平时只点赞的人留下真诚回复',
      '在小组讨论中主动做第一个发言的人',
      '给曾经帮过你的人补一句谢谢',
      '向可信任的人说出一个最近的真实感受',
    ],
    [
      '拒绝一件你其实不想做且没有义务做的事',
      '对一个不合理的请求清楚说明边界',
      '把一个你正在勉强承受的小问题说出来',
      '为今天最重要的事留出一段不被打扰的时间',
      '停止一次不必要的讨好并说出真实选择',
      '在别人打断你时平静地说请让我说完',
      '把一件不属于你的责任归还给它的负责人',
      '取消一个只因为害怕让人失望才答应的安排',
      '为一个你重视的原则发声一次',
      '直接说出你需要的帮助而不让别人猜',
    ],
    [
      '先做五分钟那件你拖了最久的小事',
      '完成一个不完美但可交付的第一版',
      '给一个重要目标安排下一个具体行动',
      '把一件模糊的待办改写成一个可执行动作',
      '在没有完全准备好时开始一个小尝试',
      '主动接下一个能让你学到东西的小任务',
      '将手机放远并完成一段专注工作',
      '公开告诉一个人你今天要完成的一件事',
      '为一个迟迟没做的决定设定明确截止时间',
      '立即处理一个你每次看到都想躲开的小问题',
    ],
    [
      '走一条没走过的安全路线',
      '试一种你没吃过且确认安全的食物',
      '去一个从没进去过的公共空间看看',
      '换一种方式完成一件熟悉的小事',
      '听一次与你平时喜好不同的完整观点',
      '参加一个你感兴趣但一直观望的小活动',
      '在熟悉的地方做一个安全的新选择',
      '用一种新工具完成一个十分钟小任务',
      '阅读一篇你平时不会点开的优质文章',
      '询问一个与你背景不同的人如何看待某件小事',
    ],
    [
      '写下一句你一直不愿承认的真话',
      '承认一个属于你的小错误并提出补救',
      '写下你真正想要却不好意思说的一件事',
      '对自己说出一个当前确实做不到的事',
      '承认一个看似忙碌实际在逃避的行为',
      '写下一个你对别人严格却对自己宽松的标准',
      '承认一件你需要重新学习的事',
      '对一个你曾经轻率评判的人重新了解一次',
      '写下你今天最想逃避的情绪名称',
      '承认一个你的旧观点可能已经不再适用',
    ],
    [
      '关掉通知专注做完一个小任务',
      '安静坐五分钟不用手机填满空白',
      '一次只做一件事直到它告一段落',
      '把今天最重要的一件事放在聊天前完成',
      '吃一顿饭时不看屏幕只感受当下',
      '用十分钟清理一个最常干扰你的信息入口',
      '为一段深度工作明确写下不做清单',
      '延迟十分钟再满足一次无意识刷屏冲动',
      '完整听完别人的一段话而不急着回应',
      '在今天结束前完成一次不被打断的阅读',
    ],
    [
      '向一个比你熟练的人请教具体做法',
      '选一个不会的小技能完成第一次练习',
      '请别人指出你一项作品中最需要改进的地方',
      '重做一道曾经做错的题并说明原因',
      '用自己的话讲解一个刚学到的概念',
      '阅读一份你一直因为觉得难而躲开的资料',
      '把一次失败拆成三个可修正的具体原因',
      '练习一次你最不熟练的基础动作',
      '向别人展示一个未完成作品并询问反馈',
      '写下一个你不懂的问题并查找可靠答案',
    ],
    [
      '主动约一个想更了解的人短聊一次',
      '向亲近的人询问一个你一直不敢问的温和问题',
      '为一次你的疏忽真诚道歉且不辩解',
      '告诉一个重要的人你对这段关系的一个期待',
      '主动问一个人最近是否需要具体帮助',
      '对一段只有客套的对话补上一个真诚问题',
      '向一个被你忽略过的人表达尊重',
      '与一个意见不同的人先复述对方观点再回应',
      '请一个信任的人告诉你一个盲点',
      '把一次重要的感谢从心里想法变成实际表达',
    ],
    [
      '完成十分钟符合自身情况的轻量活动',
      '今天比平时早十分钟放下屏幕',
      '整理一个你每天都会看见却一直忽略的小角落',
      '为明天准备一份能降低早晨摩擦的物品',
      '选一顿饭慢一点吃并停下一次自动分心',
      '把一件损坏或不再使用的小物品处理好',
      '完成一个小家务后再打开娱乐内容',
      '为今天的休息设一个清晰的开始时间',
      '准备一份简单健康且适合自己的加餐',
      '把一个影响专注的小环境问题改掉',
    ],
    [
      '清理一个你一直不想打开的数字文件夹',
      '处理一封你拖着没回的重要消息',
      '整理明天最重要的三件事并排出先后',
      '关闭五个已经不需要的浏览器页面',
      '删掉一个只会增加焦虑且没有价值的订阅',
      '把一份重要文件放到容易找到的位置',
      '列出一笔你一直回避查看的小额开支',
      '将一个混乱的桌面清到能立即开始工作',
      '把一项口头约定写成双方都清楚的一句话',
      '完成一个不超过十分钟的行政小任务',
    ],
  ];
  const modifiers = [
    '只做最小的第一步，不追求完美',
    '完成后写下你最担心什么以及实际发生了什么',
    '开始前给自己十秒钟，然后直接行动',
    '把标准设为真诚完成，而不是表现出色',
    '结束后记下一个你比之前更了解的细节',
  ];

  return [
    for (final category in actionsByCategory)
      for (final action in category)
        for (final modifier in modifiers) '$action，$modifier。',
  ];
}

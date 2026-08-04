class HabitDefinition {
  const HabitDefinition({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

const firstHabits = [
  HabitDefinition(id: 'H1', name: '每天100字复盘', description: '写下一个决定、一个结果、一个改进。'),
  HabitDefinition(id: 'H2', name: '30分钟深度思考', description: '给自己30分钟不被打断的时间。'),
  HabitDefinition(id: 'H3', name: '做一件不舒服的事', description: '舒适区外一小步，才是真正的成长区。'),
  HabitDefinition(id: 'H4', name: '睡前断网', description: '给大脑一个真正安静的收尾。'),
];

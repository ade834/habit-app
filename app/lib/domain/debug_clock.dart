import 'package:flutter/foundation.dart';

final debugDateNotifier = ValueNotifier<DateTime>(DateTime.now());

DateTime appDebugNow() => debugDateNotifier.value;

void moveDebugDate(int days) {
  final current = debugDateNotifier.value;
  debugDateNotifier.value = current.add(Duration(days: days));
}

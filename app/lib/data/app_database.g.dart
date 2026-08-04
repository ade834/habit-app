// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HabitSelectionsTable extends HabitSelections
    with TableInfo<$HabitSelectionsTable, HabitSelection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitmentNoteMeta = const VerificationMeta(
    'commitmentNote',
  );
  @override
  late final GeneratedColumn<String> commitmentNote = GeneratedColumn<String>(
    'commitment_note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledAtMeta = const VerificationMeta(
    'enabledAt',
  );
  @override
  late final GeneratedColumn<DateTime> enabledAt = GeneratedColumn<DateTime>(
    'enabled_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [habitId, commitmentNote, enabledAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('commitment_note')) {
      context.handle(
        _commitmentNoteMeta,
        commitmentNote.isAcceptableOrUnknown(
          data['commitment_note']!,
          _commitmentNoteMeta,
        ),
      );
    }
    if (data.containsKey('enabled_at')) {
      context.handle(
        _enabledAtMeta,
        enabledAt.isAcceptableOrUnknown(data['enabled_at']!, _enabledAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {habitId};
  @override
  HabitSelection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitSelection(
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      commitmentNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commitment_note'],
      )!,
      enabledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enabled_at'],
      )!,
    );
  }

  @override
  $HabitSelectionsTable createAlias(String alias) {
    return $HabitSelectionsTable(attachedDatabase, alias);
  }
}

class HabitSelection extends DataClass implements Insertable<HabitSelection> {
  final String habitId;
  final String commitmentNote;
  final DateTime enabledAt;
  const HabitSelection({
    required this.habitId,
    required this.commitmentNote,
    required this.enabledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['habit_id'] = Variable<String>(habitId);
    map['commitment_note'] = Variable<String>(commitmentNote);
    map['enabled_at'] = Variable<DateTime>(enabledAt);
    return map;
  }

  HabitSelectionsCompanion toCompanion(bool nullToAbsent) {
    return HabitSelectionsCompanion(
      habitId: Value(habitId),
      commitmentNote: Value(commitmentNote),
      enabledAt: Value(enabledAt),
    );
  }

  factory HabitSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitSelection(
      habitId: serializer.fromJson<String>(json['habitId']),
      commitmentNote: serializer.fromJson<String>(json['commitmentNote']),
      enabledAt: serializer.fromJson<DateTime>(json['enabledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'habitId': serializer.toJson<String>(habitId),
      'commitmentNote': serializer.toJson<String>(commitmentNote),
      'enabledAt': serializer.toJson<DateTime>(enabledAt),
    };
  }

  HabitSelection copyWith({
    String? habitId,
    String? commitmentNote,
    DateTime? enabledAt,
  }) => HabitSelection(
    habitId: habitId ?? this.habitId,
    commitmentNote: commitmentNote ?? this.commitmentNote,
    enabledAt: enabledAt ?? this.enabledAt,
  );
  HabitSelection copyWithCompanion(HabitSelectionsCompanion data) {
    return HabitSelection(
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      commitmentNote: data.commitmentNote.present
          ? data.commitmentNote.value
          : this.commitmentNote,
      enabledAt: data.enabledAt.present ? data.enabledAt.value : this.enabledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitSelection(')
          ..write('habitId: $habitId, ')
          ..write('commitmentNote: $commitmentNote, ')
          ..write('enabledAt: $enabledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(habitId, commitmentNote, enabledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitSelection &&
          other.habitId == this.habitId &&
          other.commitmentNote == this.commitmentNote &&
          other.enabledAt == this.enabledAt);
}

class HabitSelectionsCompanion extends UpdateCompanion<HabitSelection> {
  final Value<String> habitId;
  final Value<String> commitmentNote;
  final Value<DateTime> enabledAt;
  final Value<int> rowid;
  const HabitSelectionsCompanion({
    this.habitId = const Value.absent(),
    this.commitmentNote = const Value.absent(),
    this.enabledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitSelectionsCompanion.insert({
    required String habitId,
    this.commitmentNote = const Value.absent(),
    required DateTime enabledAt,
    this.rowid = const Value.absent(),
  }) : habitId = Value(habitId),
       enabledAt = Value(enabledAt);
  static Insertable<HabitSelection> custom({
    Expression<String>? habitId,
    Expression<String>? commitmentNote,
    Expression<DateTime>? enabledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (habitId != null) 'habit_id': habitId,
      if (commitmentNote != null) 'commitment_note': commitmentNote,
      if (enabledAt != null) 'enabled_at': enabledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitSelectionsCompanion copyWith({
    Value<String>? habitId,
    Value<String>? commitmentNote,
    Value<DateTime>? enabledAt,
    Value<int>? rowid,
  }) {
    return HabitSelectionsCompanion(
      habitId: habitId ?? this.habitId,
      commitmentNote: commitmentNote ?? this.commitmentNote,
      enabledAt: enabledAt ?? this.enabledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (commitmentNote.present) {
      map['commitment_note'] = Variable<String>(commitmentNote.value);
    }
    if (enabledAt.present) {
      map['enabled_at'] = Variable<DateTime>(enabledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitSelectionsCompanion(')
          ..write('habitId: $habitId, ')
          ..write('commitmentNote: $commitmentNote, ')
          ..write('enabledAt: $enabledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitLogsTable extends HabitLogs
    with TableInfo<$HabitLogsTable, HabitLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneOffsetMinutesMeta =
      const VerificationMeta('timezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> timezoneOffsetMinutes = GeneratedColumn<int>(
    'timezone_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    localDate,
    timezoneOffsetMinutes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('timezone_offset_minutes')) {
      context.handle(
        _timezoneOffsetMinutesMeta,
        timezoneOffsetMinutes.isAcceptableOrUnknown(
          data['timezone_offset_minutes']!,
          _timezoneOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timezoneOffsetMinutesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, localDate},
  ];
  @override
  HabitLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      timezoneOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timezone_offset_minutes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HabitLogsTable createAlias(String alias) {
    return $HabitLogsTable(attachedDatabase, alias);
  }
}

class HabitLog extends DataClass implements Insertable<HabitLog> {
  final int id;
  final String habitId;
  final String localDate;
  final int timezoneOffsetMinutes;
  final DateTime createdAt;
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.localDate,
    required this.timezoneOffsetMinutes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['local_date'] = Variable<String>(localDate);
    map['timezone_offset_minutes'] = Variable<int>(timezoneOffsetMinutes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HabitLogsCompanion toCompanion(bool nullToAbsent) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      localDate: Value(localDate),
      timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
      createdAt: Value(createdAt),
    );
  }

  factory HabitLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitLog(
      id: serializer.fromJson<int>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      localDate: serializer.fromJson<String>(json['localDate']),
      timezoneOffsetMinutes: serializer.fromJson<int>(
        json['timezoneOffsetMinutes'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'habitId': serializer.toJson<String>(habitId),
      'localDate': serializer.toJson<String>(localDate),
      'timezoneOffsetMinutes': serializer.toJson<int>(timezoneOffsetMinutes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HabitLog copyWith({
    int? id,
    String? habitId,
    String? localDate,
    int? timezoneOffsetMinutes,
    DateTime? createdAt,
  }) => HabitLog(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    localDate: localDate ?? this.localDate,
    timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
    createdAt: createdAt ?? this.createdAt,
  );
  HabitLog copyWithCompanion(HabitLogsCompanion data) {
    return HabitLog(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      timezoneOffsetMinutes: data.timezoneOffsetMinutes.present
          ? data.timezoneOffsetMinutes.value
          : this.timezoneOffsetMinutes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitLog(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDate: $localDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, habitId, localDate, timezoneOffsetMinutes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitLog &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.localDate == this.localDate &&
          other.timezoneOffsetMinutes == this.timezoneOffsetMinutes &&
          other.createdAt == this.createdAt);
}

class HabitLogsCompanion extends UpdateCompanion<HabitLog> {
  final Value<int> id;
  final Value<String> habitId;
  final Value<String> localDate;
  final Value<int> timezoneOffsetMinutes;
  final Value<DateTime> createdAt;
  const HabitLogsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.timezoneOffsetMinutes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HabitLogsCompanion.insert({
    this.id = const Value.absent(),
    required String habitId,
    required String localDate,
    required int timezoneOffsetMinutes,
    required DateTime createdAt,
  }) : habitId = Value(habitId),
       localDate = Value(localDate),
       timezoneOffsetMinutes = Value(timezoneOffsetMinutes),
       createdAt = Value(createdAt);
  static Insertable<HabitLog> custom({
    Expression<int>? id,
    Expression<String>? habitId,
    Expression<String>? localDate,
    Expression<int>? timezoneOffsetMinutes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (localDate != null) 'local_date': localDate,
      if (timezoneOffsetMinutes != null)
        'timezone_offset_minutes': timezoneOffsetMinutes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HabitLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? habitId,
    Value<String>? localDate,
    Value<int>? timezoneOffsetMinutes,
    Value<DateTime>? createdAt,
  }) {
    return HabitLogsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      localDate: localDate ?? this.localDate,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (timezoneOffsetMinutes.present) {
      map['timezone_offset_minutes'] = Variable<int>(
        timezoneOffsetMinutes.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDate: $localDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PointTransactionsTable extends PointTransactions
    with TableInfo<$PointTransactionsTable, PointTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _habitLogIdMeta = const VerificationMeta(
    'habitLogId',
  );
  @override
  late final GeneratedColumn<int> habitLogId = GeneratedColumn<int>(
    'habit_log_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES habit_logs (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, habitLogId, amount, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'point_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('habit_log_id')) {
      context.handle(
        _habitLogIdMeta,
        habitLogId.isAcceptableOrUnknown(
          data['habit_log_id']!,
          _habitLogIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_habitLogIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PointTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      habitLogId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}habit_log_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PointTransactionsTable createAlias(String alias) {
    return $PointTransactionsTable(attachedDatabase, alias);
  }
}

class PointTransaction extends DataClass
    implements Insertable<PointTransaction> {
  final int id;
  final int habitLogId;
  final int amount;
  final DateTime createdAt;
  const PointTransaction({
    required this.id,
    required this.habitLogId,
    required this.amount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['habit_log_id'] = Variable<int>(habitLogId);
    map['amount'] = Variable<int>(amount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PointTransactionsCompanion toCompanion(bool nullToAbsent) {
    return PointTransactionsCompanion(
      id: Value(id),
      habitLogId: Value(habitLogId),
      amount: Value(amount),
      createdAt: Value(createdAt),
    );
  }

  factory PointTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointTransaction(
      id: serializer.fromJson<int>(json['id']),
      habitLogId: serializer.fromJson<int>(json['habitLogId']),
      amount: serializer.fromJson<int>(json['amount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'habitLogId': serializer.toJson<int>(habitLogId),
      'amount': serializer.toJson<int>(amount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PointTransaction copyWith({
    int? id,
    int? habitLogId,
    int? amount,
    DateTime? createdAt,
  }) => PointTransaction(
    id: id ?? this.id,
    habitLogId: habitLogId ?? this.habitLogId,
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
  );
  PointTransaction copyWithCompanion(PointTransactionsCompanion data) {
    return PointTransaction(
      id: data.id.present ? data.id.value : this.id,
      habitLogId: data.habitLogId.present
          ? data.habitLogId.value
          : this.habitLogId,
      amount: data.amount.present ? data.amount.value : this.amount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointTransaction(')
          ..write('id: $id, ')
          ..write('habitLogId: $habitLogId, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, habitLogId, amount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointTransaction &&
          other.id == this.id &&
          other.habitLogId == this.habitLogId &&
          other.amount == this.amount &&
          other.createdAt == this.createdAt);
}

class PointTransactionsCompanion extends UpdateCompanion<PointTransaction> {
  final Value<int> id;
  final Value<int> habitLogId;
  final Value<int> amount;
  final Value<DateTime> createdAt;
  const PointTransactionsCompanion({
    this.id = const Value.absent(),
    this.habitLogId = const Value.absent(),
    this.amount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PointTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int habitLogId,
    required int amount,
    required DateTime createdAt,
  }) : habitLogId = Value(habitLogId),
       amount = Value(amount),
       createdAt = Value(createdAt);
  static Insertable<PointTransaction> custom({
    Expression<int>? id,
    Expression<int>? habitLogId,
    Expression<int>? amount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitLogId != null) 'habit_log_id': habitLogId,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PointTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? habitLogId,
    Value<int>? amount,
    Value<DateTime>? createdAt,
  }) {
    return PointTransactionsCompanion(
      id: id ?? this.id,
      habitLogId: habitLogId ?? this.habitLogId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (habitLogId.present) {
      map['habit_log_id'] = Variable<int>(habitLogId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('habitLogId: $habitLogId, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HabitSelectionsTable habitSelections = $HabitSelectionsTable(
    this,
  );
  late final $HabitLogsTable habitLogs = $HabitLogsTable(this);
  late final $PointTransactionsTable pointTransactions =
      $PointTransactionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habitSelections,
    habitLogs,
    pointTransactions,
  ];
}

typedef $$HabitSelectionsTableCreateCompanionBuilder =
    HabitSelectionsCompanion Function({
      required String habitId,
      Value<String> commitmentNote,
      required DateTime enabledAt,
      Value<int> rowid,
    });
typedef $$HabitSelectionsTableUpdateCompanionBuilder =
    HabitSelectionsCompanion Function({
      Value<String> habitId,
      Value<String> commitmentNote,
      Value<DateTime> enabledAt,
      Value<int> rowid,
    });

class $$HabitSelectionsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitSelectionsTable> {
  $$HabitSelectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitmentNote => $composableBuilder(
    column: $table.commitmentNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enabledAt => $composableBuilder(
    column: $table.enabledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitSelectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitSelectionsTable> {
  $$HabitSelectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitmentNote => $composableBuilder(
    column: $table.commitmentNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enabledAt => $composableBuilder(
    column: $table.enabledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitSelectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitSelectionsTable> {
  $$HabitSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get commitmentNote => $composableBuilder(
    column: $table.commitmentNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get enabledAt =>
      $composableBuilder(column: $table.enabledAt, builder: (column) => column);
}

class $$HabitSelectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitSelectionsTable,
          HabitSelection,
          $$HabitSelectionsTableFilterComposer,
          $$HabitSelectionsTableOrderingComposer,
          $$HabitSelectionsTableAnnotationComposer,
          $$HabitSelectionsTableCreateCompanionBuilder,
          $$HabitSelectionsTableUpdateCompanionBuilder,
          (
            HabitSelection,
            BaseReferences<
              _$AppDatabase,
              $HabitSelectionsTable,
              HabitSelection
            >,
          ),
          HabitSelection,
          PrefetchHooks Function()
        > {
  $$HabitSelectionsTableTableManager(
    _$AppDatabase db,
    $HabitSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitSelectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitSelectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitSelectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> habitId = const Value.absent(),
                Value<String> commitmentNote = const Value.absent(),
                Value<DateTime> enabledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitSelectionsCompanion(
                habitId: habitId,
                commitmentNote: commitmentNote,
                enabledAt: enabledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String habitId,
                Value<String> commitmentNote = const Value.absent(),
                required DateTime enabledAt,
                Value<int> rowid = const Value.absent(),
              }) => HabitSelectionsCompanion.insert(
                habitId: habitId,
                commitmentNote: commitmentNote,
                enabledAt: enabledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitSelectionsTable,
      HabitSelection,
      $$HabitSelectionsTableFilterComposer,
      $$HabitSelectionsTableOrderingComposer,
      $$HabitSelectionsTableAnnotationComposer,
      $$HabitSelectionsTableCreateCompanionBuilder,
      $$HabitSelectionsTableUpdateCompanionBuilder,
      (
        HabitSelection,
        BaseReferences<_$AppDatabase, $HabitSelectionsTable, HabitSelection>,
      ),
      HabitSelection,
      PrefetchHooks Function()
    >;
typedef $$HabitLogsTableCreateCompanionBuilder =
    HabitLogsCompanion Function({
      Value<int> id,
      required String habitId,
      required String localDate,
      required int timezoneOffsetMinutes,
      required DateTime createdAt,
    });
typedef $$HabitLogsTableUpdateCompanionBuilder =
    HabitLogsCompanion Function({
      Value<int> id,
      Value<String> habitId,
      Value<String> localDate,
      Value<int> timezoneOffsetMinutes,
      Value<DateTime> createdAt,
    });

final class $$HabitLogsTableReferences
    extends BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLog> {
  $$HabitLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PointTransactionsTable, List<PointTransaction>>
  _pointTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pointTransactions,
        aliasName: $_aliasNameGenerator(
          db.habitLogs.id,
          db.pointTransactions.habitLogId,
        ),
      );

  $$PointTransactionsTableProcessedTableManager get pointTransactionsRefs {
    final manager = $$PointTransactionsTableTableManager(
      $_db,
      $_db.pointTransactions,
    ).filter((f) => f.habitLogId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pointTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HabitLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pointTransactionsRefs(
    Expression<bool> Function($$PointTransactionsTableFilterComposer f) f,
  ) {
    final $$PointTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointTransactions,
      getReferencedColumn: (t) => t.habitLogId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.pointTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HabitLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> pointTransactionsRefs<T extends Object>(
    Expression<T> Function($$PointTransactionsTableAnnotationComposer a) f,
  ) {
    final $$PointTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pointTransactions,
          getReferencedColumn: (t) => t.habitLogId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PointTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.pointTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$HabitLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitLogsTable,
          HabitLog,
          $$HabitLogsTableFilterComposer,
          $$HabitLogsTableOrderingComposer,
          $$HabitLogsTableAnnotationComposer,
          $$HabitLogsTableCreateCompanionBuilder,
          $$HabitLogsTableUpdateCompanionBuilder,
          (HabitLog, $$HabitLogsTableReferences),
          HabitLog,
          PrefetchHooks Function({bool pointTransactionsRefs})
        > {
  $$HabitLogsTableTableManager(_$AppDatabase db, $HabitLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> timezoneOffsetMinutes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HabitLogsCompanion(
                id: id,
                habitId: habitId,
                localDate: localDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String habitId,
                required String localDate,
                required int timezoneOffsetMinutes,
                required DateTime createdAt,
              }) => HabitLogsCompanion.insert(
                id: id,
                habitId: habitId,
                localDate: localDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HabitLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pointTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (pointTransactionsRefs) db.pointTransactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pointTransactionsRefs)
                    await $_getPrefetchedData<
                      HabitLog,
                      $HabitLogsTable,
                      PointTransaction
                    >(
                      currentTable: table,
                      referencedTable: $$HabitLogsTableReferences
                          ._pointTransactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HabitLogsTableReferences(
                            db,
                            table,
                            p0,
                          ).pointTransactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.habitLogId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$HabitLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitLogsTable,
      HabitLog,
      $$HabitLogsTableFilterComposer,
      $$HabitLogsTableOrderingComposer,
      $$HabitLogsTableAnnotationComposer,
      $$HabitLogsTableCreateCompanionBuilder,
      $$HabitLogsTableUpdateCompanionBuilder,
      (HabitLog, $$HabitLogsTableReferences),
      HabitLog,
      PrefetchHooks Function({bool pointTransactionsRefs})
    >;
typedef $$PointTransactionsTableCreateCompanionBuilder =
    PointTransactionsCompanion Function({
      Value<int> id,
      required int habitLogId,
      required int amount,
      required DateTime createdAt,
    });
typedef $$PointTransactionsTableUpdateCompanionBuilder =
    PointTransactionsCompanion Function({
      Value<int> id,
      Value<int> habitLogId,
      Value<int> amount,
      Value<DateTime> createdAt,
    });

final class $$PointTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PointTransactionsTable,
          PointTransaction
        > {
  $$PointTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HabitLogsTable _habitLogIdTable(_$AppDatabase db) =>
      db.habitLogs.createAlias(
        $_aliasNameGenerator(db.pointTransactions.habitLogId, db.habitLogs.id),
      );

  $$HabitLogsTableProcessedTableManager get habitLogId {
    final $_column = $_itemColumn<int>('habit_log_id')!;

    final manager = $$HabitLogsTableTableManager(
      $_db,
      $_db.habitLogs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_habitLogIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $PointTransactionsTable> {
  $$PointTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HabitLogsTableFilterComposer get habitLogId {
    final $$HabitLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitLogId,
      referencedTable: $db.habitLogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitLogsTableFilterComposer(
            $db: $db,
            $table: $db.habitLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointTransactionsTable> {
  $$PointTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HabitLogsTableOrderingComposer get habitLogId {
    final $$HabitLogsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitLogId,
      referencedTable: $db.habitLogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitLogsTableOrderingComposer(
            $db: $db,
            $table: $db.habitLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointTransactionsTable> {
  $$PointTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$HabitLogsTableAnnotationComposer get habitLogId {
    final $$HabitLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitLogId,
      referencedTable: $db.habitLogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.habitLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PointTransactionsTable,
          PointTransaction,
          $$PointTransactionsTableFilterComposer,
          $$PointTransactionsTableOrderingComposer,
          $$PointTransactionsTableAnnotationComposer,
          $$PointTransactionsTableCreateCompanionBuilder,
          $$PointTransactionsTableUpdateCompanionBuilder,
          (PointTransaction, $$PointTransactionsTableReferences),
          PointTransaction,
          PrefetchHooks Function({bool habitLogId})
        > {
  $$PointTransactionsTableTableManager(
    _$AppDatabase db,
    $PointTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> habitLogId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PointTransactionsCompanion(
                id: id,
                habitLogId: habitLogId,
                amount: amount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int habitLogId,
                required int amount,
                required DateTime createdAt,
              }) => PointTransactionsCompanion.insert(
                id: id,
                habitLogId: habitLogId,
                amount: amount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PointTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({habitLogId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (habitLogId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.habitLogId,
                                referencedTable:
                                    $$PointTransactionsTableReferences
                                        ._habitLogIdTable(db),
                                referencedColumn:
                                    $$PointTransactionsTableReferences
                                        ._habitLogIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PointTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PointTransactionsTable,
      PointTransaction,
      $$PointTransactionsTableFilterComposer,
      $$PointTransactionsTableOrderingComposer,
      $$PointTransactionsTableAnnotationComposer,
      $$PointTransactionsTableCreateCompanionBuilder,
      $$PointTransactionsTableUpdateCompanionBuilder,
      (PointTransaction, $$PointTransactionsTableReferences),
      PointTransaction,
      PrefetchHooks Function({bool habitLogId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HabitSelectionsTableTableManager get habitSelections =>
      $$HabitSelectionsTableTableManager(_db, _db.habitSelections);
  $$HabitLogsTableTableManager get habitLogs =>
      $$HabitLogsTableTableManager(_db, _db.habitLogs);
  $$PointTransactionsTableTableManager get pointTransactions =>
      $$PointTransactionsTableTableManager(_db, _db.pointTransactions);
}

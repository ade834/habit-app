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

class $ReviewEntriesTable extends ReviewEntries
    with TableInfo<$ReviewEntriesTable, ReviewEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _decisionMeta = const VerificationMeta(
    'decision',
  );
  @override
  late final GeneratedColumn<String> decision = GeneratedColumn<String>(
    'decision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _improvementMeta = const VerificationMeta(
    'improvement',
  );
  @override
  late final GeneratedColumn<String> improvement = GeneratedColumn<String>(
    'improvement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localDate,
    decision,
    result,
    improvement,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('decision')) {
      context.handle(
        _decisionMeta,
        decision.isAcceptableOrUnknown(data['decision']!, _decisionMeta),
      );
    } else if (isInserting) {
      context.missing(_decisionMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('improvement')) {
      context.handle(
        _improvementMeta,
        improvement.isAcceptableOrUnknown(
          data['improvement']!,
          _improvementMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_improvementMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localDate};
  @override
  ReviewEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewEntry(
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      decision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      improvement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}improvement'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReviewEntriesTable createAlias(String alias) {
    return $ReviewEntriesTable(attachedDatabase, alias);
  }
}

class ReviewEntry extends DataClass implements Insertable<ReviewEntry> {
  final String localDate;
  final String decision;
  final String result;
  final String improvement;
  final DateTime updatedAt;
  const ReviewEntry({
    required this.localDate,
    required this.decision,
    required this.result,
    required this.improvement,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_date'] = Variable<String>(localDate);
    map['decision'] = Variable<String>(decision);
    map['result'] = Variable<String>(result);
    map['improvement'] = Variable<String>(improvement);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReviewEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReviewEntriesCompanion(
      localDate: Value(localDate),
      decision: Value(decision),
      result: Value(result),
      improvement: Value(improvement),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReviewEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewEntry(
      localDate: serializer.fromJson<String>(json['localDate']),
      decision: serializer.fromJson<String>(json['decision']),
      result: serializer.fromJson<String>(json['result']),
      improvement: serializer.fromJson<String>(json['improvement']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDate': serializer.toJson<String>(localDate),
      'decision': serializer.toJson<String>(decision),
      'result': serializer.toJson<String>(result),
      'improvement': serializer.toJson<String>(improvement),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReviewEntry copyWith({
    String? localDate,
    String? decision,
    String? result,
    String? improvement,
    DateTime? updatedAt,
  }) => ReviewEntry(
    localDate: localDate ?? this.localDate,
    decision: decision ?? this.decision,
    result: result ?? this.result,
    improvement: improvement ?? this.improvement,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReviewEntry copyWithCompanion(ReviewEntriesCompanion data) {
    return ReviewEntry(
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      decision: data.decision.present ? data.decision.value : this.decision,
      result: data.result.present ? data.result.value : this.result,
      improvement: data.improvement.present
          ? data.improvement.value
          : this.improvement,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEntry(')
          ..write('localDate: $localDate, ')
          ..write('decision: $decision, ')
          ..write('result: $result, ')
          ..write('improvement: $improvement, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(localDate, decision, result, improvement, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewEntry &&
          other.localDate == this.localDate &&
          other.decision == this.decision &&
          other.result == this.result &&
          other.improvement == this.improvement &&
          other.updatedAt == this.updatedAt);
}

class ReviewEntriesCompanion extends UpdateCompanion<ReviewEntry> {
  final Value<String> localDate;
  final Value<String> decision;
  final Value<String> result;
  final Value<String> improvement;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReviewEntriesCompanion({
    this.localDate = const Value.absent(),
    this.decision = const Value.absent(),
    this.result = const Value.absent(),
    this.improvement = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewEntriesCompanion.insert({
    required String localDate,
    required String decision,
    required String result,
    required String improvement,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localDate = Value(localDate),
       decision = Value(decision),
       result = Value(result),
       improvement = Value(improvement),
       updatedAt = Value(updatedAt);
  static Insertable<ReviewEntry> custom({
    Expression<String>? localDate,
    Expression<String>? decision,
    Expression<String>? result,
    Expression<String>? improvement,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDate != null) 'local_date': localDate,
      if (decision != null) 'decision': decision,
      if (result != null) 'result': result,
      if (improvement != null) 'improvement': improvement,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewEntriesCompanion copyWith({
    Value<String>? localDate,
    Value<String>? decision,
    Value<String>? result,
    Value<String>? improvement,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReviewEntriesCompanion(
      localDate: localDate ?? this.localDate,
      decision: decision ?? this.decision,
      result: result ?? this.result,
      improvement: improvement ?? this.improvement,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (decision.present) {
      map['decision'] = Variable<String>(decision.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (improvement.present) {
      map['improvement'] = Variable<String>(improvement.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEntriesCompanion(')
          ..write('localDate: $localDate, ')
          ..write('decision: $decision, ')
          ..write('result: $result, ')
          ..write('improvement: $improvement, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimerSessionsTable extends TimerSessions
    with TableInfo<$TimerSessionsTable, TimerSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimerSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _targetSecondsMeta = const VerificationMeta(
    'targetSeconds',
  );
  @override
  late final GeneratedColumn<int> targetSeconds = GeneratedColumn<int>(
    'target_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pausedAtMeta = const VerificationMeta(
    'pausedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pausedAt = GeneratedColumn<DateTime>(
    'paused_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accumulatedPauseSecondsMeta =
      const VerificationMeta('accumulatedPauseSeconds');
  @override
  late final GeneratedColumn<int> accumulatedPauseSeconds =
      GeneratedColumn<int>(
        'accumulated_pause_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('running'),
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focusTopicMeta = const VerificationMeta(
    'focusTopic',
  );
  @override
  late final GeneratedColumn<String> focusTopic = GeneratedColumn<String>(
    'focus_topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    targetSeconds,
    startedAt,
    pausedAt,
    accumulatedPauseSeconds,
    status,
    endedAt,
    focusTopic,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timer_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimerSession> instance, {
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
    if (data.containsKey('target_seconds')) {
      context.handle(
        _targetSecondsMeta,
        targetSeconds.isAcceptableOrUnknown(
          data['target_seconds']!,
          _targetSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetSecondsMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('paused_at')) {
      context.handle(
        _pausedAtMeta,
        pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta),
      );
    }
    if (data.containsKey('accumulated_pause_seconds')) {
      context.handle(
        _accumulatedPauseSecondsMeta,
        accumulatedPauseSeconds.isAcceptableOrUnknown(
          data['accumulated_pause_seconds']!,
          _accumulatedPauseSecondsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('focus_topic')) {
      context.handle(
        _focusTopicMeta,
        focusTopic.isAcceptableOrUnknown(data['focus_topic']!, _focusTopicMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimerSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimerSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      targetSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_seconds'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      pausedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paused_at'],
      ),
      accumulatedPauseSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accumulated_pause_seconds'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      focusTopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}focus_topic'],
      ),
    );
  }

  @override
  $TimerSessionsTable createAlias(String alias) {
    return $TimerSessionsTable(attachedDatabase, alias);
  }
}

class TimerSession extends DataClass implements Insertable<TimerSession> {
  final int id;
  final String habitId;
  final int targetSeconds;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final int accumulatedPauseSeconds;
  final String status;
  final DateTime? endedAt;
  final String? focusTopic;
  const TimerSession({
    required this.id,
    required this.habitId,
    required this.targetSeconds,
    required this.startedAt,
    this.pausedAt,
    required this.accumulatedPauseSeconds,
    required this.status,
    this.endedAt,
    this.focusTopic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['target_seconds'] = Variable<int>(targetSeconds);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<DateTime>(pausedAt);
    }
    map['accumulated_pause_seconds'] = Variable<int>(accumulatedPauseSeconds);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || focusTopic != null) {
      map['focus_topic'] = Variable<String>(focusTopic);
    }
    return map;
  }

  TimerSessionsCompanion toCompanion(bool nullToAbsent) {
    return TimerSessionsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      targetSeconds: Value(targetSeconds),
      startedAt: Value(startedAt),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      accumulatedPauseSeconds: Value(accumulatedPauseSeconds),
      status: Value(status),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      focusTopic: focusTopic == null && nullToAbsent
          ? const Value.absent()
          : Value(focusTopic),
    );
  }

  factory TimerSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimerSession(
      id: serializer.fromJson<int>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      targetSeconds: serializer.fromJson<int>(json['targetSeconds']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      pausedAt: serializer.fromJson<DateTime?>(json['pausedAt']),
      accumulatedPauseSeconds: serializer.fromJson<int>(
        json['accumulatedPauseSeconds'],
      ),
      status: serializer.fromJson<String>(json['status']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      focusTopic: serializer.fromJson<String?>(json['focusTopic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'habitId': serializer.toJson<String>(habitId),
      'targetSeconds': serializer.toJson<int>(targetSeconds),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'pausedAt': serializer.toJson<DateTime?>(pausedAt),
      'accumulatedPauseSeconds': serializer.toJson<int>(
        accumulatedPauseSeconds,
      ),
      'status': serializer.toJson<String>(status),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'focusTopic': serializer.toJson<String?>(focusTopic),
    };
  }

  TimerSession copyWith({
    int? id,
    String? habitId,
    int? targetSeconds,
    DateTime? startedAt,
    Value<DateTime?> pausedAt = const Value.absent(),
    int? accumulatedPauseSeconds,
    String? status,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> focusTopic = const Value.absent(),
  }) => TimerSession(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    targetSeconds: targetSeconds ?? this.targetSeconds,
    startedAt: startedAt ?? this.startedAt,
    pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
    accumulatedPauseSeconds:
        accumulatedPauseSeconds ?? this.accumulatedPauseSeconds,
    status: status ?? this.status,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    focusTopic: focusTopic.present ? focusTopic.value : this.focusTopic,
  );
  TimerSession copyWithCompanion(TimerSessionsCompanion data) {
    return TimerSession(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      targetSeconds: data.targetSeconds.present
          ? data.targetSeconds.value
          : this.targetSeconds,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      accumulatedPauseSeconds: data.accumulatedPauseSeconds.present
          ? data.accumulatedPauseSeconds.value
          : this.accumulatedPauseSeconds,
      status: data.status.present ? data.status.value : this.status,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      focusTopic: data.focusTopic.present
          ? data.focusTopic.value
          : this.focusTopic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimerSession(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('targetSeconds: $targetSeconds, ')
          ..write('startedAt: $startedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('accumulatedPauseSeconds: $accumulatedPauseSeconds, ')
          ..write('status: $status, ')
          ..write('endedAt: $endedAt, ')
          ..write('focusTopic: $focusTopic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    targetSeconds,
    startedAt,
    pausedAt,
    accumulatedPauseSeconds,
    status,
    endedAt,
    focusTopic,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimerSession &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.targetSeconds == this.targetSeconds &&
          other.startedAt == this.startedAt &&
          other.pausedAt == this.pausedAt &&
          other.accumulatedPauseSeconds == this.accumulatedPauseSeconds &&
          other.status == this.status &&
          other.endedAt == this.endedAt &&
          other.focusTopic == this.focusTopic);
}

class TimerSessionsCompanion extends UpdateCompanion<TimerSession> {
  final Value<int> id;
  final Value<String> habitId;
  final Value<int> targetSeconds;
  final Value<DateTime> startedAt;
  final Value<DateTime?> pausedAt;
  final Value<int> accumulatedPauseSeconds;
  final Value<String> status;
  final Value<DateTime?> endedAt;
  final Value<String?> focusTopic;
  const TimerSessionsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.targetSeconds = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.accumulatedPauseSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.focusTopic = const Value.absent(),
  });
  TimerSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String habitId,
    required int targetSeconds,
    required DateTime startedAt,
    this.pausedAt = const Value.absent(),
    this.accumulatedPauseSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.focusTopic = const Value.absent(),
  }) : habitId = Value(habitId),
       targetSeconds = Value(targetSeconds),
       startedAt = Value(startedAt);
  static Insertable<TimerSession> custom({
    Expression<int>? id,
    Expression<String>? habitId,
    Expression<int>? targetSeconds,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? pausedAt,
    Expression<int>? accumulatedPauseSeconds,
    Expression<String>? status,
    Expression<DateTime>? endedAt,
    Expression<String>? focusTopic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (targetSeconds != null) 'target_seconds': targetSeconds,
      if (startedAt != null) 'started_at': startedAt,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (accumulatedPauseSeconds != null)
        'accumulated_pause_seconds': accumulatedPauseSeconds,
      if (status != null) 'status': status,
      if (endedAt != null) 'ended_at': endedAt,
      if (focusTopic != null) 'focus_topic': focusTopic,
    });
  }

  TimerSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? habitId,
    Value<int>? targetSeconds,
    Value<DateTime>? startedAt,
    Value<DateTime?>? pausedAt,
    Value<int>? accumulatedPauseSeconds,
    Value<String>? status,
    Value<DateTime?>? endedAt,
    Value<String?>? focusTopic,
  }) {
    return TimerSessionsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      accumulatedPauseSeconds:
          accumulatedPauseSeconds ?? this.accumulatedPauseSeconds,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      focusTopic: focusTopic ?? this.focusTopic,
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
    if (targetSeconds.present) {
      map['target_seconds'] = Variable<int>(targetSeconds.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<DateTime>(pausedAt.value);
    }
    if (accumulatedPauseSeconds.present) {
      map['accumulated_pause_seconds'] = Variable<int>(
        accumulatedPauseSeconds.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (focusTopic.present) {
      map['focus_topic'] = Variable<String>(focusTopic.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimerSessionsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('targetSeconds: $targetSeconds, ')
          ..write('startedAt: $startedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('accumulatedPauseSeconds: $accumulatedPauseSeconds, ')
          ..write('status: $status, ')
          ..write('endedAt: $endedAt, ')
          ..write('focusTopic: $focusTopic')
          ..write(')'))
        .toString();
  }
}

class $ChallengeDrawsTable extends ChallengeDraws
    with TableInfo<$ChallengeDrawsTable, ChallengeDraw> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChallengeDrawsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cardIndexMeta = const VerificationMeta(
    'cardIndex',
  );
  @override
  late final GeneratedColumn<int> cardIndex = GeneratedColumn<int>(
    'card_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _swapUsedMeta = const VerificationMeta(
    'swapUsed',
  );
  @override
  late final GeneratedColumn<bool> swapUsed = GeneratedColumn<bool>(
    'swap_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("swap_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _swapCountMeta = const VerificationMeta(
    'swapCount',
  );
  @override
  late final GeneratedColumn<int> swapCount = GeneratedColumn<int>(
    'swap_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localDate,
    cardIndex,
    swapUsed,
    swapCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'challenge_draws';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChallengeDraw> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('card_index')) {
      context.handle(
        _cardIndexMeta,
        cardIndex.isAcceptableOrUnknown(data['card_index']!, _cardIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIndexMeta);
    }
    if (data.containsKey('swap_used')) {
      context.handle(
        _swapUsedMeta,
        swapUsed.isAcceptableOrUnknown(data['swap_used']!, _swapUsedMeta),
      );
    }
    if (data.containsKey('swap_count')) {
      context.handle(
        _swapCountMeta,
        swapCount.isAcceptableOrUnknown(data['swap_count']!, _swapCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localDate};
  @override
  ChallengeDraw map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChallengeDraw(
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      cardIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_index'],
      )!,
      swapUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}swap_used'],
      )!,
      swapCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}swap_count'],
      )!,
    );
  }

  @override
  $ChallengeDrawsTable createAlias(String alias) {
    return $ChallengeDrawsTable(attachedDatabase, alias);
  }
}

class ChallengeDraw extends DataClass implements Insertable<ChallengeDraw> {
  final String localDate;
  final int cardIndex;
  final bool swapUsed;
  final int swapCount;
  const ChallengeDraw({
    required this.localDate,
    required this.cardIndex,
    required this.swapUsed,
    required this.swapCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_date'] = Variable<String>(localDate);
    map['card_index'] = Variable<int>(cardIndex);
    map['swap_used'] = Variable<bool>(swapUsed);
    map['swap_count'] = Variable<int>(swapCount);
    return map;
  }

  ChallengeDrawsCompanion toCompanion(bool nullToAbsent) {
    return ChallengeDrawsCompanion(
      localDate: Value(localDate),
      cardIndex: Value(cardIndex),
      swapUsed: Value(swapUsed),
      swapCount: Value(swapCount),
    );
  }

  factory ChallengeDraw.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChallengeDraw(
      localDate: serializer.fromJson<String>(json['localDate']),
      cardIndex: serializer.fromJson<int>(json['cardIndex']),
      swapUsed: serializer.fromJson<bool>(json['swapUsed']),
      swapCount: serializer.fromJson<int>(json['swapCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDate': serializer.toJson<String>(localDate),
      'cardIndex': serializer.toJson<int>(cardIndex),
      'swapUsed': serializer.toJson<bool>(swapUsed),
      'swapCount': serializer.toJson<int>(swapCount),
    };
  }

  ChallengeDraw copyWith({
    String? localDate,
    int? cardIndex,
    bool? swapUsed,
    int? swapCount,
  }) => ChallengeDraw(
    localDate: localDate ?? this.localDate,
    cardIndex: cardIndex ?? this.cardIndex,
    swapUsed: swapUsed ?? this.swapUsed,
    swapCount: swapCount ?? this.swapCount,
  );
  ChallengeDraw copyWithCompanion(ChallengeDrawsCompanion data) {
    return ChallengeDraw(
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      cardIndex: data.cardIndex.present ? data.cardIndex.value : this.cardIndex,
      swapUsed: data.swapUsed.present ? data.swapUsed.value : this.swapUsed,
      swapCount: data.swapCount.present ? data.swapCount.value : this.swapCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChallengeDraw(')
          ..write('localDate: $localDate, ')
          ..write('cardIndex: $cardIndex, ')
          ..write('swapUsed: $swapUsed, ')
          ..write('swapCount: $swapCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localDate, cardIndex, swapUsed, swapCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChallengeDraw &&
          other.localDate == this.localDate &&
          other.cardIndex == this.cardIndex &&
          other.swapUsed == this.swapUsed &&
          other.swapCount == this.swapCount);
}

class ChallengeDrawsCompanion extends UpdateCompanion<ChallengeDraw> {
  final Value<String> localDate;
  final Value<int> cardIndex;
  final Value<bool> swapUsed;
  final Value<int> swapCount;
  final Value<int> rowid;
  const ChallengeDrawsCompanion({
    this.localDate = const Value.absent(),
    this.cardIndex = const Value.absent(),
    this.swapUsed = const Value.absent(),
    this.swapCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChallengeDrawsCompanion.insert({
    required String localDate,
    required int cardIndex,
    this.swapUsed = const Value.absent(),
    this.swapCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localDate = Value(localDate),
       cardIndex = Value(cardIndex);
  static Insertable<ChallengeDraw> custom({
    Expression<String>? localDate,
    Expression<int>? cardIndex,
    Expression<bool>? swapUsed,
    Expression<int>? swapCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDate != null) 'local_date': localDate,
      if (cardIndex != null) 'card_index': cardIndex,
      if (swapUsed != null) 'swap_used': swapUsed,
      if (swapCount != null) 'swap_count': swapCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChallengeDrawsCompanion copyWith({
    Value<String>? localDate,
    Value<int>? cardIndex,
    Value<bool>? swapUsed,
    Value<int>? swapCount,
    Value<int>? rowid,
  }) {
    return ChallengeDrawsCompanion(
      localDate: localDate ?? this.localDate,
      cardIndex: cardIndex ?? this.cardIndex,
      swapUsed: swapUsed ?? this.swapUsed,
      swapCount: swapCount ?? this.swapCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (cardIndex.present) {
      map['card_index'] = Variable<int>(cardIndex.value);
    }
    if (swapUsed.present) {
      map['swap_used'] = Variable<bool>(swapUsed.value);
    }
    if (swapCount.present) {
      map['swap_count'] = Variable<int>(swapCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChallengeDrawsCompanion(')
          ..write('localDate: $localDate, ')
          ..write('cardIndex: $cardIndex, ')
          ..write('swapUsed: $swapUsed, ')
          ..write('swapCount: $swapCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitActivityEntriesTable extends HabitActivityEntries
    with TableInfo<$HabitActivityEntriesTable, HabitActivityEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitActivityEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryTextMeta = const VerificationMeta(
    'primaryText',
  );
  @override
  late final GeneratedColumn<String> primaryText = GeneratedColumn<String>(
    'primary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondaryTextMeta = const VerificationMeta(
    'secondaryText',
  );
  @override
  late final GeneratedColumn<String> secondaryText = GeneratedColumn<String>(
    'secondary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _firstValueMeta = const VerificationMeta(
    'firstValue',
  );
  @override
  late final GeneratedColumn<double> firstValue = GeneratedColumn<double>(
    'first_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondValueMeta = const VerificationMeta(
    'secondValue',
  );
  @override
  late final GeneratedColumn<double> secondValue = GeneratedColumn<double>(
    'second_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    periodKey,
    primaryText,
    secondaryText,
    firstValue,
    secondValue,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_activity_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitActivityEntry> instance, {
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
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('primary_text')) {
      context.handle(
        _primaryTextMeta,
        primaryText.isAcceptableOrUnknown(
          data['primary_text']!,
          _primaryTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryTextMeta);
    }
    if (data.containsKey('secondary_text')) {
      context.handle(
        _secondaryTextMeta,
        secondaryText.isAcceptableOrUnknown(
          data['secondary_text']!,
          _secondaryTextMeta,
        ),
      );
    }
    if (data.containsKey('first_value')) {
      context.handle(
        _firstValueMeta,
        firstValue.isAcceptableOrUnknown(data['first_value']!, _firstValueMeta),
      );
    }
    if (data.containsKey('second_value')) {
      context.handle(
        _secondValueMeta,
        secondValue.isAcceptableOrUnknown(
          data['second_value']!,
          _secondValueMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, periodKey},
  ];
  @override
  HabitActivityEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitActivityEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      primaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_text'],
      )!,
      secondaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_text'],
      )!,
      firstValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}first_value'],
      ),
      secondValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}second_value'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $HabitActivityEntriesTable createAlias(String alias) {
    return $HabitActivityEntriesTable(attachedDatabase, alias);
  }
}

class HabitActivityEntry extends DataClass
    implements Insertable<HabitActivityEntry> {
  final int id;
  final String habitId;
  final String periodKey;
  final String primaryText;
  final String secondaryText;
  final double? firstValue;
  final double? secondValue;
  final DateTime completedAt;
  const HabitActivityEntry({
    required this.id,
    required this.habitId,
    required this.periodKey,
    required this.primaryText,
    required this.secondaryText,
    this.firstValue,
    this.secondValue,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['period_key'] = Variable<String>(periodKey);
    map['primary_text'] = Variable<String>(primaryText);
    map['secondary_text'] = Variable<String>(secondaryText);
    if (!nullToAbsent || firstValue != null) {
      map['first_value'] = Variable<double>(firstValue);
    }
    if (!nullToAbsent || secondValue != null) {
      map['second_value'] = Variable<double>(secondValue);
    }
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  HabitActivityEntriesCompanion toCompanion(bool nullToAbsent) {
    return HabitActivityEntriesCompanion(
      id: Value(id),
      habitId: Value(habitId),
      periodKey: Value(periodKey),
      primaryText: Value(primaryText),
      secondaryText: Value(secondaryText),
      firstValue: firstValue == null && nullToAbsent
          ? const Value.absent()
          : Value(firstValue),
      secondValue: secondValue == null && nullToAbsent
          ? const Value.absent()
          : Value(secondValue),
      completedAt: Value(completedAt),
    );
  }

  factory HabitActivityEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitActivityEntry(
      id: serializer.fromJson<int>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      primaryText: serializer.fromJson<String>(json['primaryText']),
      secondaryText: serializer.fromJson<String>(json['secondaryText']),
      firstValue: serializer.fromJson<double?>(json['firstValue']),
      secondValue: serializer.fromJson<double?>(json['secondValue']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'habitId': serializer.toJson<String>(habitId),
      'periodKey': serializer.toJson<String>(periodKey),
      'primaryText': serializer.toJson<String>(primaryText),
      'secondaryText': serializer.toJson<String>(secondaryText),
      'firstValue': serializer.toJson<double?>(firstValue),
      'secondValue': serializer.toJson<double?>(secondValue),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  HabitActivityEntry copyWith({
    int? id,
    String? habitId,
    String? periodKey,
    String? primaryText,
    String? secondaryText,
    Value<double?> firstValue = const Value.absent(),
    Value<double?> secondValue = const Value.absent(),
    DateTime? completedAt,
  }) => HabitActivityEntry(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    periodKey: periodKey ?? this.periodKey,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    firstValue: firstValue.present ? firstValue.value : this.firstValue,
    secondValue: secondValue.present ? secondValue.value : this.secondValue,
    completedAt: completedAt ?? this.completedAt,
  );
  HabitActivityEntry copyWithCompanion(HabitActivityEntriesCompanion data) {
    return HabitActivityEntry(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      primaryText: data.primaryText.present
          ? data.primaryText.value
          : this.primaryText,
      secondaryText: data.secondaryText.present
          ? data.secondaryText.value
          : this.secondaryText,
      firstValue: data.firstValue.present
          ? data.firstValue.value
          : this.firstValue,
      secondValue: data.secondValue.present
          ? data.secondValue.value
          : this.secondValue,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitActivityEntry(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('periodKey: $periodKey, ')
          ..write('primaryText: $primaryText, ')
          ..write('secondaryText: $secondaryText, ')
          ..write('firstValue: $firstValue, ')
          ..write('secondValue: $secondValue, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    periodKey,
    primaryText,
    secondaryText,
    firstValue,
    secondValue,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitActivityEntry &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.periodKey == this.periodKey &&
          other.primaryText == this.primaryText &&
          other.secondaryText == this.secondaryText &&
          other.firstValue == this.firstValue &&
          other.secondValue == this.secondValue &&
          other.completedAt == this.completedAt);
}

class HabitActivityEntriesCompanion
    extends UpdateCompanion<HabitActivityEntry> {
  final Value<int> id;
  final Value<String> habitId;
  final Value<String> periodKey;
  final Value<String> primaryText;
  final Value<String> secondaryText;
  final Value<double?> firstValue;
  final Value<double?> secondValue;
  final Value<DateTime> completedAt;
  const HabitActivityEntriesCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.primaryText = const Value.absent(),
    this.secondaryText = const Value.absent(),
    this.firstValue = const Value.absent(),
    this.secondValue = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  HabitActivityEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String habitId,
    required String periodKey,
    required String primaryText,
    this.secondaryText = const Value.absent(),
    this.firstValue = const Value.absent(),
    this.secondValue = const Value.absent(),
    required DateTime completedAt,
  }) : habitId = Value(habitId),
       periodKey = Value(periodKey),
       primaryText = Value(primaryText),
       completedAt = Value(completedAt);
  static Insertable<HabitActivityEntry> custom({
    Expression<int>? id,
    Expression<String>? habitId,
    Expression<String>? periodKey,
    Expression<String>? primaryText,
    Expression<String>? secondaryText,
    Expression<double>? firstValue,
    Expression<double>? secondValue,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (periodKey != null) 'period_key': periodKey,
      if (primaryText != null) 'primary_text': primaryText,
      if (secondaryText != null) 'secondary_text': secondaryText,
      if (firstValue != null) 'first_value': firstValue,
      if (secondValue != null) 'second_value': secondValue,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  HabitActivityEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? habitId,
    Value<String>? periodKey,
    Value<String>? primaryText,
    Value<String>? secondaryText,
    Value<double?>? firstValue,
    Value<double?>? secondValue,
    Value<DateTime>? completedAt,
  }) {
    return HabitActivityEntriesCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      periodKey: periodKey ?? this.periodKey,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      firstValue: firstValue ?? this.firstValue,
      secondValue: secondValue ?? this.secondValue,
      completedAt: completedAt ?? this.completedAt,
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
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (primaryText.present) {
      map['primary_text'] = Variable<String>(primaryText.value);
    }
    if (secondaryText.present) {
      map['secondary_text'] = Variable<String>(secondaryText.value);
    }
    if (firstValue.present) {
      map['first_value'] = Variable<double>(firstValue.value);
    }
    if (secondValue.present) {
      map['second_value'] = Variable<double>(secondValue.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitActivityEntriesCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('periodKey: $periodKey, ')
          ..write('primaryText: $primaryText, ')
          ..write('secondaryText: $secondaryText, ')
          ..write('firstValue: $firstValue, ')
          ..write('secondValue: $secondValue, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $TravelPlansTable extends TravelPlans
    with TableInfo<$TravelPlansTable, TravelPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<int> days = GeneratedColumn<int>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _focusMeta = const VerificationMeta('focus');
  @override
  late final GeneratedColumn<String> focus = GeneratedColumn<String>(
    'focus',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preparationMeta = const VerificationMeta(
    'preparation',
  );
  @override
  late final GeneratedColumn<String> preparation = GeneratedColumn<String>(
    'preparation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _plannedAtMeta = const VerificationMeta(
    'plannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> plannedAt = GeneratedColumn<DateTime>(
    'planned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    year,
    destination,
    days,
    focus,
    preparation,
    plannedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<TravelPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationMeta);
    }
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    } else if (isInserting) {
      context.missing(_daysMeta);
    }
    if (data.containsKey('focus')) {
      context.handle(
        _focusMeta,
        focus.isAcceptableOrUnknown(data['focus']!, _focusMeta),
      );
    } else if (isInserting) {
      context.missing(_focusMeta);
    }
    if (data.containsKey('preparation')) {
      context.handle(
        _preparationMeta,
        preparation.isAcceptableOrUnknown(
          data['preparation']!,
          _preparationMeta,
        ),
      );
    }
    if (data.containsKey('planned_at')) {
      context.handle(
        _plannedAtMeta,
        plannedAt.isAcceptableOrUnknown(data['planned_at']!, _plannedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_plannedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {year};
  @override
  TravelPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TravelPlan(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days'],
      )!,
      focus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}focus'],
      )!,
      preparation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preparation'],
      )!,
      plannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}planned_at'],
      )!,
    );
  }

  @override
  $TravelPlansTable createAlias(String alias) {
    return $TravelPlansTable(attachedDatabase, alias);
  }
}

class TravelPlan extends DataClass implements Insertable<TravelPlan> {
  final int year;
  final String destination;
  final int days;
  final String focus;
  final String preparation;
  final DateTime plannedAt;
  const TravelPlan({
    required this.year,
    required this.destination,
    required this.days,
    required this.focus,
    required this.preparation,
    required this.plannedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['destination'] = Variable<String>(destination);
    map['days'] = Variable<int>(days);
    map['focus'] = Variable<String>(focus);
    map['preparation'] = Variable<String>(preparation);
    map['planned_at'] = Variable<DateTime>(plannedAt);
    return map;
  }

  TravelPlansCompanion toCompanion(bool nullToAbsent) {
    return TravelPlansCompanion(
      year: Value(year),
      destination: Value(destination),
      days: Value(days),
      focus: Value(focus),
      preparation: Value(preparation),
      plannedAt: Value(plannedAt),
    );
  }

  factory TravelPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TravelPlan(
      year: serializer.fromJson<int>(json['year']),
      destination: serializer.fromJson<String>(json['destination']),
      days: serializer.fromJson<int>(json['days']),
      focus: serializer.fromJson<String>(json['focus']),
      preparation: serializer.fromJson<String>(json['preparation']),
      plannedAt: serializer.fromJson<DateTime>(json['plannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'destination': serializer.toJson<String>(destination),
      'days': serializer.toJson<int>(days),
      'focus': serializer.toJson<String>(focus),
      'preparation': serializer.toJson<String>(preparation),
      'plannedAt': serializer.toJson<DateTime>(plannedAt),
    };
  }

  TravelPlan copyWith({
    int? year,
    String? destination,
    int? days,
    String? focus,
    String? preparation,
    DateTime? plannedAt,
  }) => TravelPlan(
    year: year ?? this.year,
    destination: destination ?? this.destination,
    days: days ?? this.days,
    focus: focus ?? this.focus,
    preparation: preparation ?? this.preparation,
    plannedAt: plannedAt ?? this.plannedAt,
  );
  TravelPlan copyWithCompanion(TravelPlansCompanion data) {
    return TravelPlan(
      year: data.year.present ? data.year.value : this.year,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      days: data.days.present ? data.days.value : this.days,
      focus: data.focus.present ? data.focus.value : this.focus,
      preparation: data.preparation.present
          ? data.preparation.value
          : this.preparation,
      plannedAt: data.plannedAt.present ? data.plannedAt.value : this.plannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TravelPlan(')
          ..write('year: $year, ')
          ..write('destination: $destination, ')
          ..write('days: $days, ')
          ..write('focus: $focus, ')
          ..write('preparation: $preparation, ')
          ..write('plannedAt: $plannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(year, destination, days, focus, preparation, plannedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TravelPlan &&
          other.year == this.year &&
          other.destination == this.destination &&
          other.days == this.days &&
          other.focus == this.focus &&
          other.preparation == this.preparation &&
          other.plannedAt == this.plannedAt);
}

class TravelPlansCompanion extends UpdateCompanion<TravelPlan> {
  final Value<int> year;
  final Value<String> destination;
  final Value<int> days;
  final Value<String> focus;
  final Value<String> preparation;
  final Value<DateTime> plannedAt;
  const TravelPlansCompanion({
    this.year = const Value.absent(),
    this.destination = const Value.absent(),
    this.days = const Value.absent(),
    this.focus = const Value.absent(),
    this.preparation = const Value.absent(),
    this.plannedAt = const Value.absent(),
  });
  TravelPlansCompanion.insert({
    this.year = const Value.absent(),
    required String destination,
    required int days,
    required String focus,
    this.preparation = const Value.absent(),
    required DateTime plannedAt,
  }) : destination = Value(destination),
       days = Value(days),
       focus = Value(focus),
       plannedAt = Value(plannedAt);
  static Insertable<TravelPlan> custom({
    Expression<int>? year,
    Expression<String>? destination,
    Expression<int>? days,
    Expression<String>? focus,
    Expression<String>? preparation,
    Expression<DateTime>? plannedAt,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (destination != null) 'destination': destination,
      if (days != null) 'days': days,
      if (focus != null) 'focus': focus,
      if (preparation != null) 'preparation': preparation,
      if (plannedAt != null) 'planned_at': plannedAt,
    });
  }

  TravelPlansCompanion copyWith({
    Value<int>? year,
    Value<String>? destination,
    Value<int>? days,
    Value<String>? focus,
    Value<String>? preparation,
    Value<DateTime>? plannedAt,
  }) {
    return TravelPlansCompanion(
      year: year ?? this.year,
      destination: destination ?? this.destination,
      days: days ?? this.days,
      focus: focus ?? this.focus,
      preparation: preparation ?? this.preparation,
      plannedAt: plannedAt ?? this.plannedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (days.present) {
      map['days'] = Variable<int>(days.value);
    }
    if (focus.present) {
      map['focus'] = Variable<String>(focus.value);
    }
    if (preparation.present) {
      map['preparation'] = Variable<String>(preparation.value);
    }
    if (plannedAt.present) {
      map['planned_at'] = Variable<DateTime>(plannedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelPlansCompanion(')
          ..write('year: $year, ')
          ..write('destination: $destination, ')
          ..write('days: $days, ')
          ..write('focus: $focus, ')
          ..write('preparation: $preparation, ')
          ..write('plannedAt: $plannedAt')
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
  late final $ReviewEntriesTable reviewEntries = $ReviewEntriesTable(this);
  late final $TimerSessionsTable timerSessions = $TimerSessionsTable(this);
  late final $ChallengeDrawsTable challengeDraws = $ChallengeDrawsTable(this);
  late final $HabitActivityEntriesTable habitActivityEntries =
      $HabitActivityEntriesTable(this);
  late final $TravelPlansTable travelPlans = $TravelPlansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habitSelections,
    habitLogs,
    pointTransactions,
    reviewEntries,
    timerSessions,
    challengeDraws,
    habitActivityEntries,
    travelPlans,
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
typedef $$ReviewEntriesTableCreateCompanionBuilder =
    ReviewEntriesCompanion Function({
      required String localDate,
      required String decision,
      required String result,
      required String improvement,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReviewEntriesTableUpdateCompanionBuilder =
    ReviewEntriesCompanion Function({
      Value<String> localDate,
      Value<String> decision,
      Value<String> result,
      Value<String> improvement,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReviewEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewEntriesTable> {
  $$ReviewEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get improvement => $composableBuilder(
    column: $table.improvement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewEntriesTable> {
  $$ReviewEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get improvement => $composableBuilder(
    column: $table.improvement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewEntriesTable> {
  $$ReviewEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get decision =>
      $composableBuilder(column: $table.decision, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get improvement => $composableBuilder(
    column: $table.improvement,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReviewEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewEntriesTable,
          ReviewEntry,
          $$ReviewEntriesTableFilterComposer,
          $$ReviewEntriesTableOrderingComposer,
          $$ReviewEntriesTableAnnotationComposer,
          $$ReviewEntriesTableCreateCompanionBuilder,
          $$ReviewEntriesTableUpdateCompanionBuilder,
          (
            ReviewEntry,
            BaseReferences<_$AppDatabase, $ReviewEntriesTable, ReviewEntry>,
          ),
          ReviewEntry,
          PrefetchHooks Function()
        > {
  $$ReviewEntriesTableTableManager(_$AppDatabase db, $ReviewEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localDate = const Value.absent(),
                Value<String> decision = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> improvement = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewEntriesCompanion(
                localDate: localDate,
                decision: decision,
                result: result,
                improvement: improvement,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localDate,
                required String decision,
                required String result,
                required String improvement,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewEntriesCompanion.insert(
                localDate: localDate,
                decision: decision,
                result: result,
                improvement: improvement,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewEntriesTable,
      ReviewEntry,
      $$ReviewEntriesTableFilterComposer,
      $$ReviewEntriesTableOrderingComposer,
      $$ReviewEntriesTableAnnotationComposer,
      $$ReviewEntriesTableCreateCompanionBuilder,
      $$ReviewEntriesTableUpdateCompanionBuilder,
      (
        ReviewEntry,
        BaseReferences<_$AppDatabase, $ReviewEntriesTable, ReviewEntry>,
      ),
      ReviewEntry,
      PrefetchHooks Function()
    >;
typedef $$TimerSessionsTableCreateCompanionBuilder =
    TimerSessionsCompanion Function({
      Value<int> id,
      required String habitId,
      required int targetSeconds,
      required DateTime startedAt,
      Value<DateTime?> pausedAt,
      Value<int> accumulatedPauseSeconds,
      Value<String> status,
      Value<DateTime?> endedAt,
      Value<String?> focusTopic,
    });
typedef $$TimerSessionsTableUpdateCompanionBuilder =
    TimerSessionsCompanion Function({
      Value<int> id,
      Value<String> habitId,
      Value<int> targetSeconds,
      Value<DateTime> startedAt,
      Value<DateTime?> pausedAt,
      Value<int> accumulatedPauseSeconds,
      Value<String> status,
      Value<DateTime?> endedAt,
      Value<String?> focusTopic,
    });

class $$TimerSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TimerSessionsTable> {
  $$TimerSessionsTableFilterComposer({
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

  ColumnFilters<int> get targetSeconds => $composableBuilder(
    column: $table.targetSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accumulatedPauseSeconds => $composableBuilder(
    column: $table.accumulatedPauseSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get focusTopic => $composableBuilder(
    column: $table.focusTopic,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimerSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimerSessionsTable> {
  $$TimerSessionsTableOrderingComposer({
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

  ColumnOrderings<int> get targetSeconds => $composableBuilder(
    column: $table.targetSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accumulatedPauseSeconds => $composableBuilder(
    column: $table.accumulatedPauseSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get focusTopic => $composableBuilder(
    column: $table.focusTopic,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimerSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimerSessionsTable> {
  $$TimerSessionsTableAnnotationComposer({
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

  GeneratedColumn<int> get targetSeconds => $composableBuilder(
    column: $table.targetSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get accumulatedPauseSeconds => $composableBuilder(
    column: $table.accumulatedPauseSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get focusTopic => $composableBuilder(
    column: $table.focusTopic,
    builder: (column) => column,
  );
}

class $$TimerSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimerSessionsTable,
          TimerSession,
          $$TimerSessionsTableFilterComposer,
          $$TimerSessionsTableOrderingComposer,
          $$TimerSessionsTableAnnotationComposer,
          $$TimerSessionsTableCreateCompanionBuilder,
          $$TimerSessionsTableUpdateCompanionBuilder,
          (
            TimerSession,
            BaseReferences<_$AppDatabase, $TimerSessionsTable, TimerSession>,
          ),
          TimerSession,
          PrefetchHooks Function()
        > {
  $$TimerSessionsTableTableManager(_$AppDatabase db, $TimerSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimerSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimerSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimerSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<int> targetSeconds = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> accumulatedPauseSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> focusTopic = const Value.absent(),
              }) => TimerSessionsCompanion(
                id: id,
                habitId: habitId,
                targetSeconds: targetSeconds,
                startedAt: startedAt,
                pausedAt: pausedAt,
                accumulatedPauseSeconds: accumulatedPauseSeconds,
                status: status,
                endedAt: endedAt,
                focusTopic: focusTopic,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String habitId,
                required int targetSeconds,
                required DateTime startedAt,
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> accumulatedPauseSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> focusTopic = const Value.absent(),
              }) => TimerSessionsCompanion.insert(
                id: id,
                habitId: habitId,
                targetSeconds: targetSeconds,
                startedAt: startedAt,
                pausedAt: pausedAt,
                accumulatedPauseSeconds: accumulatedPauseSeconds,
                status: status,
                endedAt: endedAt,
                focusTopic: focusTopic,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimerSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimerSessionsTable,
      TimerSession,
      $$TimerSessionsTableFilterComposer,
      $$TimerSessionsTableOrderingComposer,
      $$TimerSessionsTableAnnotationComposer,
      $$TimerSessionsTableCreateCompanionBuilder,
      $$TimerSessionsTableUpdateCompanionBuilder,
      (
        TimerSession,
        BaseReferences<_$AppDatabase, $TimerSessionsTable, TimerSession>,
      ),
      TimerSession,
      PrefetchHooks Function()
    >;
typedef $$ChallengeDrawsTableCreateCompanionBuilder =
    ChallengeDrawsCompanion Function({
      required String localDate,
      required int cardIndex,
      Value<bool> swapUsed,
      Value<int> swapCount,
      Value<int> rowid,
    });
typedef $$ChallengeDrawsTableUpdateCompanionBuilder =
    ChallengeDrawsCompanion Function({
      Value<String> localDate,
      Value<int> cardIndex,
      Value<bool> swapUsed,
      Value<int> swapCount,
      Value<int> rowid,
    });

class $$ChallengeDrawsTableFilterComposer
    extends Composer<_$AppDatabase, $ChallengeDrawsTable> {
  $$ChallengeDrawsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardIndex => $composableBuilder(
    column: $table.cardIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get swapUsed => $composableBuilder(
    column: $table.swapUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get swapCount => $composableBuilder(
    column: $table.swapCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChallengeDrawsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChallengeDrawsTable> {
  $$ChallengeDrawsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardIndex => $composableBuilder(
    column: $table.cardIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get swapUsed => $composableBuilder(
    column: $table.swapUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get swapCount => $composableBuilder(
    column: $table.swapCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChallengeDrawsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChallengeDrawsTable> {
  $$ChallengeDrawsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get cardIndex =>
      $composableBuilder(column: $table.cardIndex, builder: (column) => column);

  GeneratedColumn<bool> get swapUsed =>
      $composableBuilder(column: $table.swapUsed, builder: (column) => column);

  GeneratedColumn<int> get swapCount =>
      $composableBuilder(column: $table.swapCount, builder: (column) => column);
}

class $$ChallengeDrawsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChallengeDrawsTable,
          ChallengeDraw,
          $$ChallengeDrawsTableFilterComposer,
          $$ChallengeDrawsTableOrderingComposer,
          $$ChallengeDrawsTableAnnotationComposer,
          $$ChallengeDrawsTableCreateCompanionBuilder,
          $$ChallengeDrawsTableUpdateCompanionBuilder,
          (
            ChallengeDraw,
            BaseReferences<_$AppDatabase, $ChallengeDrawsTable, ChallengeDraw>,
          ),
          ChallengeDraw,
          PrefetchHooks Function()
        > {
  $$ChallengeDrawsTableTableManager(
    _$AppDatabase db,
    $ChallengeDrawsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChallengeDrawsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChallengeDrawsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChallengeDrawsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localDate = const Value.absent(),
                Value<int> cardIndex = const Value.absent(),
                Value<bool> swapUsed = const Value.absent(),
                Value<int> swapCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChallengeDrawsCompanion(
                localDate: localDate,
                cardIndex: cardIndex,
                swapUsed: swapUsed,
                swapCount: swapCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localDate,
                required int cardIndex,
                Value<bool> swapUsed = const Value.absent(),
                Value<int> swapCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChallengeDrawsCompanion.insert(
                localDate: localDate,
                cardIndex: cardIndex,
                swapUsed: swapUsed,
                swapCount: swapCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChallengeDrawsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChallengeDrawsTable,
      ChallengeDraw,
      $$ChallengeDrawsTableFilterComposer,
      $$ChallengeDrawsTableOrderingComposer,
      $$ChallengeDrawsTableAnnotationComposer,
      $$ChallengeDrawsTableCreateCompanionBuilder,
      $$ChallengeDrawsTableUpdateCompanionBuilder,
      (
        ChallengeDraw,
        BaseReferences<_$AppDatabase, $ChallengeDrawsTable, ChallengeDraw>,
      ),
      ChallengeDraw,
      PrefetchHooks Function()
    >;
typedef $$HabitActivityEntriesTableCreateCompanionBuilder =
    HabitActivityEntriesCompanion Function({
      Value<int> id,
      required String habitId,
      required String periodKey,
      required String primaryText,
      Value<String> secondaryText,
      Value<double?> firstValue,
      Value<double?> secondValue,
      required DateTime completedAt,
    });
typedef $$HabitActivityEntriesTableUpdateCompanionBuilder =
    HabitActivityEntriesCompanion Function({
      Value<int> id,
      Value<String> habitId,
      Value<String> periodKey,
      Value<String> primaryText,
      Value<String> secondaryText,
      Value<double?> firstValue,
      Value<double?> secondValue,
      Value<DateTime> completedAt,
    });

class $$HabitActivityEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $HabitActivityEntriesTable> {
  $$HabitActivityEntriesTableFilterComposer({
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

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get firstValue => $composableBuilder(
    column: $table.firstValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get secondValue => $composableBuilder(
    column: $table.secondValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitActivityEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitActivityEntriesTable> {
  $$HabitActivityEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get firstValue => $composableBuilder(
    column: $table.firstValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get secondValue => $composableBuilder(
    column: $table.secondValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitActivityEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitActivityEntriesTable> {
  $$HabitActivityEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get firstValue => $composableBuilder(
    column: $table.firstValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get secondValue => $composableBuilder(
    column: $table.secondValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$HabitActivityEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitActivityEntriesTable,
          HabitActivityEntry,
          $$HabitActivityEntriesTableFilterComposer,
          $$HabitActivityEntriesTableOrderingComposer,
          $$HabitActivityEntriesTableAnnotationComposer,
          $$HabitActivityEntriesTableCreateCompanionBuilder,
          $$HabitActivityEntriesTableUpdateCompanionBuilder,
          (
            HabitActivityEntry,
            BaseReferences<
              _$AppDatabase,
              $HabitActivityEntriesTable,
              HabitActivityEntry
            >,
          ),
          HabitActivityEntry,
          PrefetchHooks Function()
        > {
  $$HabitActivityEntriesTableTableManager(
    _$AppDatabase db,
    $HabitActivityEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitActivityEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitActivityEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HabitActivityEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<String> primaryText = const Value.absent(),
                Value<String> secondaryText = const Value.absent(),
                Value<double?> firstValue = const Value.absent(),
                Value<double?> secondValue = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
              }) => HabitActivityEntriesCompanion(
                id: id,
                habitId: habitId,
                periodKey: periodKey,
                primaryText: primaryText,
                secondaryText: secondaryText,
                firstValue: firstValue,
                secondValue: secondValue,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String habitId,
                required String periodKey,
                required String primaryText,
                Value<String> secondaryText = const Value.absent(),
                Value<double?> firstValue = const Value.absent(),
                Value<double?> secondValue = const Value.absent(),
                required DateTime completedAt,
              }) => HabitActivityEntriesCompanion.insert(
                id: id,
                habitId: habitId,
                periodKey: periodKey,
                primaryText: primaryText,
                secondaryText: secondaryText,
                firstValue: firstValue,
                secondValue: secondValue,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitActivityEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitActivityEntriesTable,
      HabitActivityEntry,
      $$HabitActivityEntriesTableFilterComposer,
      $$HabitActivityEntriesTableOrderingComposer,
      $$HabitActivityEntriesTableAnnotationComposer,
      $$HabitActivityEntriesTableCreateCompanionBuilder,
      $$HabitActivityEntriesTableUpdateCompanionBuilder,
      (
        HabitActivityEntry,
        BaseReferences<
          _$AppDatabase,
          $HabitActivityEntriesTable,
          HabitActivityEntry
        >,
      ),
      HabitActivityEntry,
      PrefetchHooks Function()
    >;
typedef $$TravelPlansTableCreateCompanionBuilder =
    TravelPlansCompanion Function({
      Value<int> year,
      required String destination,
      required int days,
      required String focus,
      Value<String> preparation,
      required DateTime plannedAt,
    });
typedef $$TravelPlansTableUpdateCompanionBuilder =
    TravelPlansCompanion Function({
      Value<int> year,
      Value<String> destination,
      Value<int> days,
      Value<String> focus,
      Value<String> preparation,
      Value<DateTime> plannedAt,
    });

class $$TravelPlansTableFilterComposer
    extends Composer<_$AppDatabase, $TravelPlansTable> {
  $$TravelPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get focus => $composableBuilder(
    column: $table.focus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preparation => $composableBuilder(
    column: $table.preparation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get plannedAt => $composableBuilder(
    column: $table.plannedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TravelPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $TravelPlansTable> {
  $$TravelPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get focus => $composableBuilder(
    column: $table.focus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preparation => $composableBuilder(
    column: $table.preparation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get plannedAt => $composableBuilder(
    column: $table.plannedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TravelPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $TravelPlansTable> {
  $$TravelPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<int> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<String> get focus =>
      $composableBuilder(column: $table.focus, builder: (column) => column);

  GeneratedColumn<String> get preparation => $composableBuilder(
    column: $table.preparation,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get plannedAt =>
      $composableBuilder(column: $table.plannedAt, builder: (column) => column);
}

class $$TravelPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TravelPlansTable,
          TravelPlan,
          $$TravelPlansTableFilterComposer,
          $$TravelPlansTableOrderingComposer,
          $$TravelPlansTableAnnotationComposer,
          $$TravelPlansTableCreateCompanionBuilder,
          $$TravelPlansTableUpdateCompanionBuilder,
          (
            TravelPlan,
            BaseReferences<_$AppDatabase, $TravelPlansTable, TravelPlan>,
          ),
          TravelPlan,
          PrefetchHooks Function()
        > {
  $$TravelPlansTableTableManager(_$AppDatabase db, $TravelPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TravelPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TravelPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TravelPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<String> focus = const Value.absent(),
                Value<String> preparation = const Value.absent(),
                Value<DateTime> plannedAt = const Value.absent(),
              }) => TravelPlansCompanion(
                year: year,
                destination: destination,
                days: days,
                focus: focus,
                preparation: preparation,
                plannedAt: plannedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                required String destination,
                required int days,
                required String focus,
                Value<String> preparation = const Value.absent(),
                required DateTime plannedAt,
              }) => TravelPlansCompanion.insert(
                year: year,
                destination: destination,
                days: days,
                focus: focus,
                preparation: preparation,
                plannedAt: plannedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TravelPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TravelPlansTable,
      TravelPlan,
      $$TravelPlansTableFilterComposer,
      $$TravelPlansTableOrderingComposer,
      $$TravelPlansTableAnnotationComposer,
      $$TravelPlansTableCreateCompanionBuilder,
      $$TravelPlansTableUpdateCompanionBuilder,
      (
        TravelPlan,
        BaseReferences<_$AppDatabase, $TravelPlansTable, TravelPlan>,
      ),
      TravelPlan,
      PrefetchHooks Function()
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
  $$ReviewEntriesTableTableManager get reviewEntries =>
      $$ReviewEntriesTableTableManager(_db, _db.reviewEntries);
  $$TimerSessionsTableTableManager get timerSessions =>
      $$TimerSessionsTableTableManager(_db, _db.timerSessions);
  $$ChallengeDrawsTableTableManager get challengeDraws =>
      $$ChallengeDrawsTableTableManager(_db, _db.challengeDraws);
  $$HabitActivityEntriesTableTableManager get habitActivityEntries =>
      $$HabitActivityEntriesTableTableManager(_db, _db.habitActivityEntries);
  $$TravelPlansTableTableManager get travelPlans =>
      $$TravelPlansTableTableManager(_db, _db.travelPlans);
}

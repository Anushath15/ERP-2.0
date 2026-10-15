// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Kv extends Table with TableInfo<Kv, DbKv> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Kv(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [name, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbKv> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  DbKv map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbKv(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Kv createAlias(String alias) {
    return Kv(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbKv extends DataClass implements Insertable<DbKv> {
  final String name;
  final String value;
  final int updatedAt;
  const DbKv({
    required this.name,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  KvCompanion toCompanion(bool nullToAbsent) {
    return KvCompanion(
      name: Value(name),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbKv.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbKv(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  DbKv copyWith({String? name, String? value, int? updatedAt}) => DbKv(
    name: name ?? this.name,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbKv copyWithCompanion(KvCompanion data) {
    return DbKv(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbKv(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbKv &&
          other.name == this.name &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KvCompanion extends UpdateCompanion<DbKv> {
  final Value<String> name;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const KvCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCompanion.insert({
    required String name,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<DbKv> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCompanion copyWith({
    Value<String>? name,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return KvCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Categories extends Table with TableInfo<Categories, DbCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbCategory extends DataClass implements Insertable<DbCategory> {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbCategory copyWith({
    String? id,
    String? name,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbCategory copyWithCompanion(CategoriesCompanion data) {
    return DbCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class CategoriesCompanion extends UpdateCompanion<DbCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Products extends Table with TableInfo<Products, DbProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Products(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pcs\'',
    defaultValue: const CustomExpression('\'pcs\''),
  );
  static const VerificationMeta _pricePaiseMeta = const VerificationMeta(
    'pricePaise',
  );
  late final GeneratedColumn<int> pricePaise = GeneratedColumn<int>(
    'price_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _costPaiseMeta = const VerificationMeta(
    'costPaise',
  );
  late final GeneratedColumn<int> costPaise = GeneratedColumn<int>(
    'cost_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _gstBpMeta = const VerificationMeta('gstBp');
  late final GeneratedColumn<int> gstBp = GeneratedColumn<int>(
    'gst_bp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1800',
    defaultValue: const CustomExpression('1800'),
  );
  static const VerificationMeta _hsnMeta = const VerificationMeta('hsn');
  late final GeneratedColumn<String> hsn = GeneratedColumn<String>(
    'hsn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _minStockMilliMeta = const VerificationMeta(
    'minStockMilli',
  );
  late final GeneratedColumn<int> minStockMilli = GeneratedColumn<int>(
    'min_stock_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  late final GeneratedColumn<int> active = GeneratedColumn<int>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _oldIdMeta = const VerificationMeta('oldId');
  late final GeneratedColumn<String> oldId = GeneratedColumn<String>(
    'old_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    unit,
    pricePaise,
    costPaise,
    gstBp,
    hsn,
    barcode,
    minStockMilli,
    active,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('price_paise')) {
      context.handle(
        _pricePaiseMeta,
        pricePaise.isAcceptableOrUnknown(data['price_paise']!, _pricePaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_pricePaiseMeta);
    }
    if (data.containsKey('cost_paise')) {
      context.handle(
        _costPaiseMeta,
        costPaise.isAcceptableOrUnknown(data['cost_paise']!, _costPaiseMeta),
      );
    }
    if (data.containsKey('gst_bp')) {
      context.handle(
        _gstBpMeta,
        gstBp.isAcceptableOrUnknown(data['gst_bp']!, _gstBpMeta),
      );
    }
    if (data.containsKey('hsn')) {
      context.handle(
        _hsnMeta,
        hsn.isAcceptableOrUnknown(data['hsn']!, _hsnMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('min_stock_milli')) {
      context.handle(
        _minStockMilliMeta,
        minStockMilli.isAcceptableOrUnknown(
          data['min_stock_milli']!,
          _minStockMilliMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('old_id')) {
      context.handle(
        _oldIdMeta,
        oldId.isAcceptableOrUnknown(data['old_id']!, _oldIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      pricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_paise'],
      )!,
      costPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_paise'],
      )!,
      gstBp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gst_bp'],
      )!,
      hsn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hsn'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
      minStockMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_stock_milli'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active'],
      )!,
      oldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Products createAlias(String alias) {
    return Products(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbProduct extends DataClass implements Insertable<DbProduct> {
  final String id;
  final String name;
  final String category;
  final String unit;
  final int pricePaise;
  final int costPaise;
  final int gstBp;
  final String hsn;
  final String barcode;
  final int minStockMilli;
  final int active;
  final String? oldId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.pricePaise,
    required this.costPaise,
    required this.gstBp,
    required this.hsn,
    required this.barcode,
    required this.minStockMilli,
    required this.active,
    this.oldId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['unit'] = Variable<String>(unit);
    map['price_paise'] = Variable<int>(pricePaise);
    map['cost_paise'] = Variable<int>(costPaise);
    map['gst_bp'] = Variable<int>(gstBp);
    map['hsn'] = Variable<String>(hsn);
    map['barcode'] = Variable<String>(barcode);
    map['min_stock_milli'] = Variable<int>(minStockMilli);
    map['active'] = Variable<int>(active);
    if (!nullToAbsent || oldId != null) {
      map['old_id'] = Variable<String>(oldId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      unit: Value(unit),
      pricePaise: Value(pricePaise),
      costPaise: Value(costPaise),
      gstBp: Value(gstBp),
      hsn: Value(hsn),
      barcode: Value(barcode),
      minStockMilli: Value(minStockMilli),
      active: Value(active),
      oldId: oldId == null && nullToAbsent
          ? const Value.absent()
          : Value(oldId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbProduct(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      unit: serializer.fromJson<String>(json['unit']),
      pricePaise: serializer.fromJson<int>(json['price_paise']),
      costPaise: serializer.fromJson<int>(json['cost_paise']),
      gstBp: serializer.fromJson<int>(json['gst_bp']),
      hsn: serializer.fromJson<String>(json['hsn']),
      barcode: serializer.fromJson<String>(json['barcode']),
      minStockMilli: serializer.fromJson<int>(json['min_stock_milli']),
      active: serializer.fromJson<int>(json['active']),
      oldId: serializer.fromJson<String?>(json['old_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'unit': serializer.toJson<String>(unit),
      'price_paise': serializer.toJson<int>(pricePaise),
      'cost_paise': serializer.toJson<int>(costPaise),
      'gst_bp': serializer.toJson<int>(gstBp),
      'hsn': serializer.toJson<String>(hsn),
      'barcode': serializer.toJson<String>(barcode),
      'min_stock_milli': serializer.toJson<int>(minStockMilli),
      'active': serializer.toJson<int>(active),
      'old_id': serializer.toJson<String?>(oldId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbProduct copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    int? pricePaise,
    int? costPaise,
    int? gstBp,
    String? hsn,
    String? barcode,
    int? minStockMilli,
    int? active,
    Value<String?> oldId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbProduct(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    pricePaise: pricePaise ?? this.pricePaise,
    costPaise: costPaise ?? this.costPaise,
    gstBp: gstBp ?? this.gstBp,
    hsn: hsn ?? this.hsn,
    barcode: barcode ?? this.barcode,
    minStockMilli: minStockMilli ?? this.minStockMilli,
    active: active ?? this.active,
    oldId: oldId.present ? oldId.value : this.oldId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbProduct copyWithCompanion(ProductsCompanion data) {
    return DbProduct(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      unit: data.unit.present ? data.unit.value : this.unit,
      pricePaise: data.pricePaise.present
          ? data.pricePaise.value
          : this.pricePaise,
      costPaise: data.costPaise.present ? data.costPaise.value : this.costPaise,
      gstBp: data.gstBp.present ? data.gstBp.value : this.gstBp,
      hsn: data.hsn.present ? data.hsn.value : this.hsn,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      minStockMilli: data.minStockMilli.present
          ? data.minStockMilli.value
          : this.minStockMilli,
      active: data.active.present ? data.active.value : this.active,
      oldId: data.oldId.present ? data.oldId.value : this.oldId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbProduct(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('pricePaise: $pricePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('gstBp: $gstBp, ')
          ..write('hsn: $hsn, ')
          ..write('barcode: $barcode, ')
          ..write('minStockMilli: $minStockMilli, ')
          ..write('active: $active, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    unit,
    pricePaise,
    costPaise,
    gstBp,
    hsn,
    barcode,
    minStockMilli,
    active,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbProduct &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.unit == this.unit &&
          other.pricePaise == this.pricePaise &&
          other.costPaise == this.costPaise &&
          other.gstBp == this.gstBp &&
          other.hsn == this.hsn &&
          other.barcode == this.barcode &&
          other.minStockMilli == this.minStockMilli &&
          other.active == this.active &&
          other.oldId == this.oldId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class ProductsCompanion extends UpdateCompanion<DbProduct> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> unit;
  final Value<int> pricePaise;
  final Value<int> costPaise;
  final Value<int> gstBp;
  final Value<String> hsn;
  final Value<String> barcode;
  final Value<int> minStockMilli;
  final Value<int> active;
  final Value<String?> oldId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.pricePaise = const Value.absent(),
    this.costPaise = const Value.absent(),
    this.gstBp = const Value.absent(),
    this.hsn = const Value.absent(),
    this.barcode = const Value.absent(),
    this.minStockMilli = const Value.absent(),
    this.active = const Value.absent(),
    this.oldId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    required int pricePaise,
    this.costPaise = const Value.absent(),
    this.gstBp = const Value.absent(),
    this.hsn = const Value.absent(),
    this.barcode = const Value.absent(),
    this.minStockMilli = const Value.absent(),
    this.active = const Value.absent(),
    this.oldId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       pricePaise = Value(pricePaise),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbProduct> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? unit,
    Expression<int>? pricePaise,
    Expression<int>? costPaise,
    Expression<int>? gstBp,
    Expression<String>? hsn,
    Expression<String>? barcode,
    Expression<int>? minStockMilli,
    Expression<int>? active,
    Expression<String>? oldId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (pricePaise != null) 'price_paise': pricePaise,
      if (costPaise != null) 'cost_paise': costPaise,
      if (gstBp != null) 'gst_bp': gstBp,
      if (hsn != null) 'hsn': hsn,
      if (barcode != null) 'barcode': barcode,
      if (minStockMilli != null) 'min_stock_milli': minStockMilli,
      if (active != null) 'active': active,
      if (oldId != null) 'old_id': oldId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String>? unit,
    Value<int>? pricePaise,
    Value<int>? costPaise,
    Value<int>? gstBp,
    Value<String>? hsn,
    Value<String>? barcode,
    Value<int>? minStockMilli,
    Value<int>? active,
    Value<String?>? oldId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      pricePaise: pricePaise ?? this.pricePaise,
      costPaise: costPaise ?? this.costPaise,
      gstBp: gstBp ?? this.gstBp,
      hsn: hsn ?? this.hsn,
      barcode: barcode ?? this.barcode,
      minStockMilli: minStockMilli ?? this.minStockMilli,
      active: active ?? this.active,
      oldId: oldId ?? this.oldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (pricePaise.present) {
      map['price_paise'] = Variable<int>(pricePaise.value);
    }
    if (costPaise.present) {
      map['cost_paise'] = Variable<int>(costPaise.value);
    }
    if (gstBp.present) {
      map['gst_bp'] = Variable<int>(gstBp.value);
    }
    if (hsn.present) {
      map['hsn'] = Variable<String>(hsn.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (minStockMilli.present) {
      map['min_stock_milli'] = Variable<int>(minStockMilli.value);
    }
    if (active.present) {
      map['active'] = Variable<int>(active.value);
    }
    if (oldId.present) {
      map['old_id'] = Variable<String>(oldId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('pricePaise: $pricePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('gstBp: $gstBp, ')
          ..write('hsn: $hsn, ')
          ..write('barcode: $barcode, ')
          ..write('minStockMilli: $minStockMilli, ')
          ..write('active: $active, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProductFts extends Table
    with
        TableInfo<ProductFts, ProductFt>,
        VirtualTableInfo<ProductFts, ProductFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProductFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [name, barcode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ProductFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductFt(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
    );
  }

  @override
  ProductFts createAlias(String alias) {
    return ProductFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(name, barcode, content=\'products\', content_rowid=\'rowid\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class ProductFt extends DataClass implements Insertable<ProductFt> {
  final String name;
  final String barcode;
  const ProductFt({required this.name, required this.barcode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['barcode'] = Variable<String>(barcode);
    return map;
  }

  ProductFtsCompanion toCompanion(bool nullToAbsent) {
    return ProductFtsCompanion(name: Value(name), barcode: Value(barcode));
  }

  factory ProductFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductFt(
      name: serializer.fromJson<String>(json['name']),
      barcode: serializer.fromJson<String>(json['barcode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'barcode': serializer.toJson<String>(barcode),
    };
  }

  ProductFt copyWith({String? name, String? barcode}) =>
      ProductFt(name: name ?? this.name, barcode: barcode ?? this.barcode);
  ProductFt copyWithCompanion(ProductFtsCompanion data) {
    return ProductFt(
      name: data.name.present ? data.name.value : this.name,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductFt(')
          ..write('name: $name, ')
          ..write('barcode: $barcode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, barcode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductFt &&
          other.name == this.name &&
          other.barcode == this.barcode);
}

class ProductFtsCompanion extends UpdateCompanion<ProductFt> {
  final Value<String> name;
  final Value<String> barcode;
  final Value<int> rowid;
  const ProductFtsCompanion({
    this.name = const Value.absent(),
    this.barcode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductFtsCompanion.insert({
    required String name,
    required String barcode,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       barcode = Value(barcode);
  static Insertable<ProductFt> custom({
    Expression<String>? name,
    Expression<String>? barcode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (barcode != null) 'barcode': barcode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductFtsCompanion copyWith({
    Value<String>? name,
    Value<String>? barcode,
    Value<int>? rowid,
  }) {
    return ProductFtsCompanion(
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductFtsCompanion(')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Customers extends Table with TableInfo<Customers, DbCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Customers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
    'gstin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _creditLimitPaiseMeta = const VerificationMeta(
    'creditLimitPaise',
  );
  late final GeneratedColumn<int> creditLimitPaise = GeneratedColumn<int>(
    'credit_limit_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _oldIdMeta = const VerificationMeta('oldId');
  late final GeneratedColumn<String> oldId = GeneratedColumn<String>(
    'old_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    city,
    address,
    gstin,
    creditLimitPaise,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCustomer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('gstin')) {
      context.handle(
        _gstinMeta,
        gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta),
      );
    }
    if (data.containsKey('credit_limit_paise')) {
      context.handle(
        _creditLimitPaiseMeta,
        creditLimitPaise.isAcceptableOrUnknown(
          data['credit_limit_paise']!,
          _creditLimitPaiseMeta,
        ),
      );
    }
    if (data.containsKey('old_id')) {
      context.handle(
        _oldIdMeta,
        oldId.isAcceptableOrUnknown(data['old_id']!, _oldIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCustomer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      gstin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gstin'],
      )!,
      creditLimitPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_paise'],
      )!,
      oldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Customers createAlias(String alias) {
    return Customers(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbCustomer extends DataClass implements Insertable<DbCustomer> {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String address;
  final String gstin;
  final int creditLimitPaise;
  final String? oldId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.address,
    required this.gstin,
    required this.creditLimitPaise,
    this.oldId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['city'] = Variable<String>(city);
    map['address'] = Variable<String>(address);
    map['gstin'] = Variable<String>(gstin);
    map['credit_limit_paise'] = Variable<int>(creditLimitPaise);
    if (!nullToAbsent || oldId != null) {
      map['old_id'] = Variable<String>(oldId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      city: Value(city),
      address: Value(address),
      gstin: Value(gstin),
      creditLimitPaise: Value(creditLimitPaise),
      oldId: oldId == null && nullToAbsent
          ? const Value.absent()
          : Value(oldId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbCustomer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCustomer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      city: serializer.fromJson<String>(json['city']),
      address: serializer.fromJson<String>(json['address']),
      gstin: serializer.fromJson<String>(json['gstin']),
      creditLimitPaise: serializer.fromJson<int>(json['credit_limit_paise']),
      oldId: serializer.fromJson<String?>(json['old_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'city': serializer.toJson<String>(city),
      'address': serializer.toJson<String>(address),
      'gstin': serializer.toJson<String>(gstin),
      'credit_limit_paise': serializer.toJson<int>(creditLimitPaise),
      'old_id': serializer.toJson<String?>(oldId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbCustomer copyWith({
    String? id,
    String? name,
    String? phone,
    String? city,
    String? address,
    String? gstin,
    int? creditLimitPaise,
    Value<String?> oldId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbCustomer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    address: address ?? this.address,
    gstin: gstin ?? this.gstin,
    creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise,
    oldId: oldId.present ? oldId.value : this.oldId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbCustomer copyWithCompanion(CustomersCompanion data) {
    return DbCustomer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      city: data.city.present ? data.city.value : this.city,
      address: data.address.present ? data.address.value : this.address,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      creditLimitPaise: data.creditLimitPaise.present
          ? data.creditLimitPaise.value
          : this.creditLimitPaise,
      oldId: data.oldId.present ? data.oldId.value : this.oldId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCustomer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('gstin: $gstin, ')
          ..write('creditLimitPaise: $creditLimitPaise, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    city,
    address,
    gstin,
    creditLimitPaise,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCustomer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.city == this.city &&
          other.address == this.address &&
          other.gstin == this.gstin &&
          other.creditLimitPaise == this.creditLimitPaise &&
          other.oldId == this.oldId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class CustomersCompanion extends UpdateCompanion<DbCustomer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> city;
  final Value<String> address;
  final Value<String> gstin;
  final Value<int> creditLimitPaise;
  final Value<String?> oldId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.city = const Value.absent(),
    this.address = const Value.absent(),
    this.gstin = const Value.absent(),
    this.creditLimitPaise = const Value.absent(),
    this.oldId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.city = const Value.absent(),
    this.address = const Value.absent(),
    this.gstin = const Value.absent(),
    this.creditLimitPaise = const Value.absent(),
    this.oldId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbCustomer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? city,
    Expression<String>? address,
    Expression<String>? gstin,
    Expression<int>? creditLimitPaise,
    Expression<String>? oldId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (address != null) 'address': address,
      if (gstin != null) 'gstin': gstin,
      if (creditLimitPaise != null) 'credit_limit_paise': creditLimitPaise,
      if (oldId != null) 'old_id': oldId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? city,
    Value<String>? address,
    Value<String>? gstin,
    Value<int>? creditLimitPaise,
    Value<String?>? oldId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise,
      oldId: oldId ?? this.oldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (creditLimitPaise.present) {
      map['credit_limit_paise'] = Variable<int>(creditLimitPaise.value);
    }
    if (oldId.present) {
      map['old_id'] = Variable<String>(oldId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('gstin: $gstin, ')
          ..write('creditLimitPaise: $creditLimitPaise, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Dealers extends Table with TableInfo<Dealers, DbDealer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Dealers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
    'gstin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _oldIdMeta = const VerificationMeta('oldId');
  late final GeneratedColumn<String> oldId = GeneratedColumn<String>(
    'old_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    city,
    address,
    gstin,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dealers';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDealer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('gstin')) {
      context.handle(
        _gstinMeta,
        gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta),
      );
    }
    if (data.containsKey('old_id')) {
      context.handle(
        _oldIdMeta,
        oldId.isAcceptableOrUnknown(data['old_id']!, _oldIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDealer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDealer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      gstin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gstin'],
      )!,
      oldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Dealers createAlias(String alias) {
    return Dealers(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbDealer extends DataClass implements Insertable<DbDealer> {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String address;
  final String gstin;
  final String? oldId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbDealer({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.address,
    required this.gstin,
    this.oldId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['city'] = Variable<String>(city);
    map['address'] = Variable<String>(address);
    map['gstin'] = Variable<String>(gstin);
    if (!nullToAbsent || oldId != null) {
      map['old_id'] = Variable<String>(oldId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  DealersCompanion toCompanion(bool nullToAbsent) {
    return DealersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      city: Value(city),
      address: Value(address),
      gstin: Value(gstin),
      oldId: oldId == null && nullToAbsent
          ? const Value.absent()
          : Value(oldId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbDealer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDealer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      city: serializer.fromJson<String>(json['city']),
      address: serializer.fromJson<String>(json['address']),
      gstin: serializer.fromJson<String>(json['gstin']),
      oldId: serializer.fromJson<String?>(json['old_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'city': serializer.toJson<String>(city),
      'address': serializer.toJson<String>(address),
      'gstin': serializer.toJson<String>(gstin),
      'old_id': serializer.toJson<String?>(oldId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbDealer copyWith({
    String? id,
    String? name,
    String? phone,
    String? city,
    String? address,
    String? gstin,
    Value<String?> oldId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbDealer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    address: address ?? this.address,
    gstin: gstin ?? this.gstin,
    oldId: oldId.present ? oldId.value : this.oldId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbDealer copyWithCompanion(DealersCompanion data) {
    return DbDealer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      city: data.city.present ? data.city.value : this.city,
      address: data.address.present ? data.address.value : this.address,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      oldId: data.oldId.present ? data.oldId.value : this.oldId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDealer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('gstin: $gstin, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    city,
    address,
    gstin,
    oldId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDealer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.city == this.city &&
          other.address == this.address &&
          other.gstin == this.gstin &&
          other.oldId == this.oldId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class DealersCompanion extends UpdateCompanion<DbDealer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> city;
  final Value<String> address;
  final Value<String> gstin;
  final Value<String?> oldId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const DealersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.city = const Value.absent(),
    this.address = const Value.absent(),
    this.gstin = const Value.absent(),
    this.oldId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DealersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.city = const Value.absent(),
    this.address = const Value.absent(),
    this.gstin = const Value.absent(),
    this.oldId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbDealer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? city,
    Expression<String>? address,
    Expression<String>? gstin,
    Expression<String>? oldId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (address != null) 'address': address,
      if (gstin != null) 'gstin': gstin,
      if (oldId != null) 'old_id': oldId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DealersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? city,
    Value<String>? address,
    Value<String>? gstin,
    Value<String?>? oldId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return DealersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      oldId: oldId ?? this.oldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (oldId.present) {
      map['old_id'] = Variable<String>(oldId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DealersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('city: $city, ')
          ..write('address: $address, ')
          ..write('gstin: $gstin, ')
          ..write('oldId: $oldId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StockMovements extends Table
    with TableInfo<StockMovements, DbStockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StockMovements(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES products(id)',
  );
  static const VerificationMeta _qtyMilliMeta = const VerificationMeta(
    'qtyMilli',
  );
  late final GeneratedColumn<int> qtyMilli = GeneratedColumn<int>(
    'qty_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _unitCostPaiseMeta = const VerificationMeta(
    'unitCostPaise',
  );
  late final GeneratedColumn<int> unitCostPaise = GeneratedColumn<int>(
    'unit_cost_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    qtyMilli,
    kind,
    refId,
    unitCostPaise,
    at,
    note,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbStockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('qty_milli')) {
      context.handle(
        _qtyMilliMeta,
        qtyMilli.isAcceptableOrUnknown(data['qty_milli']!, _qtyMilliMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMilliMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    }
    if (data.containsKey('unit_cost_paise')) {
      context.handle(
        _unitCostPaiseMeta,
        unitCostPaise.isAcceptableOrUnknown(
          data['unit_cost_paise']!,
          _unitCostPaiseMeta,
        ),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbStockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbStockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      qtyMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_milli'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      ),
      unitCostPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost_paise'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  StockMovements createAlias(String alias) {
    return StockMovements(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbStockMovement extends DataClass implements Insertable<DbStockMovement> {
  final String id;
  final String productId;
  final int qtyMilli;
  final String kind;
  final String? refId;
  final int unitCostPaise;
  final int at;
  final String note;
  final int createdAt;
  final String deviceId;
  const DbStockMovement({
    required this.id,
    required this.productId,
    required this.qtyMilli,
    required this.kind,
    this.refId,
    required this.unitCostPaise,
    required this.at,
    required this.note,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['qty_milli'] = Variable<int>(qtyMilli);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || refId != null) {
      map['ref_id'] = Variable<String>(refId);
    }
    map['unit_cost_paise'] = Variable<int>(unitCostPaise);
    map['at'] = Variable<int>(at);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      qtyMilli: Value(qtyMilli),
      kind: Value(kind),
      refId: refId == null && nullToAbsent
          ? const Value.absent()
          : Value(refId),
      unitCostPaise: Value(unitCostPaise),
      at: Value(at),
      note: Value(note),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbStockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbStockMovement(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['product_id']),
      qtyMilli: serializer.fromJson<int>(json['qty_milli']),
      kind: serializer.fromJson<String>(json['kind']),
      refId: serializer.fromJson<String?>(json['ref_id']),
      unitCostPaise: serializer.fromJson<int>(json['unit_cost_paise']),
      at: serializer.fromJson<int>(json['at']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'product_id': serializer.toJson<String>(productId),
      'qty_milli': serializer.toJson<int>(qtyMilli),
      'kind': serializer.toJson<String>(kind),
      'ref_id': serializer.toJson<String?>(refId),
      'unit_cost_paise': serializer.toJson<int>(unitCostPaise),
      'at': serializer.toJson<int>(at),
      'note': serializer.toJson<String>(note),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbStockMovement copyWith({
    String? id,
    String? productId,
    int? qtyMilli,
    String? kind,
    Value<String?> refId = const Value.absent(),
    int? unitCostPaise,
    int? at,
    String? note,
    int? createdAt,
    String? deviceId,
  }) => DbStockMovement(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    qtyMilli: qtyMilli ?? this.qtyMilli,
    kind: kind ?? this.kind,
    refId: refId.present ? refId.value : this.refId,
    unitCostPaise: unitCostPaise ?? this.unitCostPaise,
    at: at ?? this.at,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbStockMovement copyWithCompanion(StockMovementsCompanion data) {
    return DbStockMovement(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      qtyMilli: data.qtyMilli.present ? data.qtyMilli.value : this.qtyMilli,
      kind: data.kind.present ? data.kind.value : this.kind,
      refId: data.refId.present ? data.refId.value : this.refId,
      unitCostPaise: data.unitCostPaise.present
          ? data.unitCostPaise.value
          : this.unitCostPaise,
      at: data.at.present ? data.at.value : this.at,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbStockMovement(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('unitCostPaise: $unitCostPaise, ')
          ..write('at: $at, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    qtyMilli,
    kind,
    refId,
    unitCostPaise,
    at,
    note,
    createdAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbStockMovement &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.qtyMilli == this.qtyMilli &&
          other.kind == this.kind &&
          other.refId == this.refId &&
          other.unitCostPaise == this.unitCostPaise &&
          other.at == this.at &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class StockMovementsCompanion extends UpdateCompanion<DbStockMovement> {
  final Value<String> id;
  final Value<String> productId;
  final Value<int> qtyMilli;
  final Value<String> kind;
  final Value<String?> refId;
  final Value<int> unitCostPaise;
  final Value<int> at;
  final Value<String> note;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.qtyMilli = const Value.absent(),
    this.kind = const Value.absent(),
    this.refId = const Value.absent(),
    this.unitCostPaise = const Value.absent(),
    this.at = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    required String id,
    required String productId,
    required int qtyMilli,
    required String kind,
    this.refId = const Value.absent(),
    this.unitCostPaise = const Value.absent(),
    required int at,
    this.note = const Value.absent(),
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       qtyMilli = Value(qtyMilli),
       kind = Value(kind),
       at = Value(at),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbStockMovement> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<int>? qtyMilli,
    Expression<String>? kind,
    Expression<String>? refId,
    Expression<int>? unitCostPaise,
    Expression<int>? at,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (qtyMilli != null) 'qty_milli': qtyMilli,
      if (kind != null) 'kind': kind,
      if (refId != null) 'ref_id': refId,
      if (unitCostPaise != null) 'unit_cost_paise': unitCostPaise,
      if (at != null) 'at': at,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<int>? qtyMilli,
    Value<String>? kind,
    Value<String?>? refId,
    Value<int>? unitCostPaise,
    Value<int>? at,
    Value<String>? note,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      qtyMilli: qtyMilli ?? this.qtyMilli,
      kind: kind ?? this.kind,
      refId: refId ?? this.refId,
      unitCostPaise: unitCostPaise ?? this.unitCostPaise,
      at: at ?? this.at,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (qtyMilli.present) {
      map['qty_milli'] = Variable<int>(qtyMilli.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (unitCostPaise.present) {
      map['unit_cost_paise'] = Variable<int>(unitCostPaise.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('unitCostPaise: $unitCostPaise, ')
          ..write('at: $at, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StockCache extends Table with TableInfo<StockCache, DbStockCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StockCache(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY REFERENCES products(id)',
  );
  static const VerificationMeta _qtyMilliMeta = const VerificationMeta(
    'qtyMilli',
  );
  late final GeneratedColumn<int> qtyMilli = GeneratedColumn<int>(
    'qty_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [productId, qtyMilli];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbStockCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('qty_milli')) {
      context.handle(
        _qtyMilliMeta,
        qtyMilli.isAcceptableOrUnknown(data['qty_milli']!, _qtyMilliMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  DbStockCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbStockCache(
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      qtyMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_milli'],
      )!,
    );
  }

  @override
  StockCache createAlias(String alias) {
    return StockCache(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbStockCache extends DataClass implements Insertable<DbStockCache> {
  final String productId;
  final int qtyMilli;
  const DbStockCache({required this.productId, required this.qtyMilli});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['qty_milli'] = Variable<int>(qtyMilli);
    return map;
  }

  StockCacheCompanion toCompanion(bool nullToAbsent) {
    return StockCacheCompanion(
      productId: Value(productId),
      qtyMilli: Value(qtyMilli),
    );
  }

  factory DbStockCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbStockCache(
      productId: serializer.fromJson<String>(json['product_id']),
      qtyMilli: serializer.fromJson<int>(json['qty_milli']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'product_id': serializer.toJson<String>(productId),
      'qty_milli': serializer.toJson<int>(qtyMilli),
    };
  }

  DbStockCache copyWith({String? productId, int? qtyMilli}) => DbStockCache(
    productId: productId ?? this.productId,
    qtyMilli: qtyMilli ?? this.qtyMilli,
  );
  DbStockCache copyWithCompanion(StockCacheCompanion data) {
    return DbStockCache(
      productId: data.productId.present ? data.productId.value : this.productId,
      qtyMilli: data.qtyMilli.present ? data.qtyMilli.value : this.qtyMilli,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbStockCache(')
          ..write('productId: $productId, ')
          ..write('qtyMilli: $qtyMilli')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(productId, qtyMilli);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbStockCache &&
          other.productId == this.productId &&
          other.qtyMilli == this.qtyMilli);
}

class StockCacheCompanion extends UpdateCompanion<DbStockCache> {
  final Value<String> productId;
  final Value<int> qtyMilli;
  final Value<int> rowid;
  const StockCacheCompanion({
    this.productId = const Value.absent(),
    this.qtyMilli = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockCacheCompanion.insert({
    required String productId,
    this.qtyMilli = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : productId = Value(productId);
  static Insertable<DbStockCache> custom({
    Expression<String>? productId,
    Expression<int>? qtyMilli,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (qtyMilli != null) 'qty_milli': qtyMilli,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockCacheCompanion copyWith({
    Value<String>? productId,
    Value<int>? qtyMilli,
    Value<int>? rowid,
  }) {
    return StockCacheCompanion(
      productId: productId ?? this.productId,
      qtyMilli: qtyMilli ?? this.qtyMilli,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (qtyMilli.present) {
      map['qty_milli'] = Variable<int>(qtyMilli.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCacheCompanion(')
          ..write('productId: $productId, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Bills extends Table with TableInfo<Bills, DbBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Bills(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  late final GeneratedColumn<String> series = GeneratedColumn<String>(
    'series',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _billedAtMeta = const VerificationMeta(
    'billedAt',
  );
  late final GeneratedColumn<int> billedAt = GeneratedColumn<int>(
    'billed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES customers(id)',
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _totalPaiseMeta = const VerificationMeta(
    'totalPaise',
  );
  late final GeneratedColumn<int> totalPaise = GeneratedColumn<int>(
    'total_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _receivedPaiseMeta = const VerificationMeta(
    'receivedPaise',
  );
  late final GeneratedColumn<int> receivedPaise = GeneratedColumn<int>(
    'received_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _balancePaiseMeta = const VerificationMeta(
    'balancePaise',
  );
  late final GeneratedColumn<int> balancePaise = GeneratedColumn<int>(
    'balance_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _changePaiseMeta = const VerificationMeta(
    'changePaise',
  );
  late final GeneratedColumn<int> changePaise = GeneratedColumn<int>(
    'change_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _advanceKeptPaiseMeta = const VerificationMeta(
    'advanceKeptPaise',
  );
  late final GeneratedColumn<int> advanceKeptPaise = GeneratedColumn<int>(
    'advance_kept_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _taxablePaiseMeta = const VerificationMeta(
    'taxablePaise',
  );
  late final GeneratedColumn<int> taxablePaise = GeneratedColumn<int>(
    'taxable_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cgstPaiseMeta = const VerificationMeta(
    'cgstPaise',
  );
  late final GeneratedColumn<int> cgstPaise = GeneratedColumn<int>(
    'cgst_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _sgstPaiseMeta = const VerificationMeta(
    'sgstPaise',
  );
  late final GeneratedColumn<int> sgstPaise = GeneratedColumn<int>(
    'sgst_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _igstPaiseMeta = const VerificationMeta(
    'igstPaise',
  );
  late final GeneratedColumn<int> igstPaise = GeneratedColumn<int>(
    'igst_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _discountPaiseMeta = const VerificationMeta(
    'discountPaise',
  );
  late final GeneratedColumn<int> discountPaise = GeneratedColumn<int>(
    'discount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _roundOffPaiseMeta = const VerificationMeta(
    'roundOffPaise',
  );
  late final GeneratedColumn<int> roundOffPaise = GeneratedColumn<int>(
    'round_off_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _payModeMeta = const VerificationMeta(
    'payMode',
  );
  late final GeneratedColumn<int> payMode = GeneratedColumn<int>(
    'pay_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cancelledMeta = const VerificationMeta(
    'cancelled',
  );
  late final GeneratedColumn<int> cancelled = GeneratedColumn<int>(
    'cancelled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _pricesIncludeGstMeta = const VerificationMeta(
    'pricesIncludeGst',
  );
  late final GeneratedColumn<int> pricesIncludeGst = GeneratedColumn<int>(
    'prices_include_gst',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _idemKeyMeta = const VerificationMeta(
    'idemKey',
  );
  late final GeneratedColumn<String> idemKey = GeneratedColumn<String>(
    'idem_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _oldBillNoMeta = const VerificationMeta(
    'oldBillNo',
  );
  late final GeneratedColumn<String> oldBillNo = GeneratedColumn<String>(
    'old_bill_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    number,
    series,
    seq,
    billedAt,
    day,
    customerId,
    customerName,
    totalPaise,
    receivedPaise,
    balancePaise,
    changePaise,
    advanceKeptPaise,
    taxablePaise,
    cgstPaise,
    sgstPaise,
    igstPaise,
    discountPaise,
    roundOffPaise,
    payMode,
    status,
    cancelled,
    itemCount,
    pricesIncludeGst,
    idemKey,
    oldBillNo,
    note,
    createdBy,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('billed_at')) {
      context.handle(
        _billedAtMeta,
        billedAt.isAcceptableOrUnknown(data['billed_at']!, _billedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_billedAtMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('total_paise')) {
      context.handle(
        _totalPaiseMeta,
        totalPaise.isAcceptableOrUnknown(data['total_paise']!, _totalPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPaiseMeta);
    }
    if (data.containsKey('received_paise')) {
      context.handle(
        _receivedPaiseMeta,
        receivedPaise.isAcceptableOrUnknown(
          data['received_paise']!,
          _receivedPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receivedPaiseMeta);
    }
    if (data.containsKey('balance_paise')) {
      context.handle(
        _balancePaiseMeta,
        balancePaise.isAcceptableOrUnknown(
          data['balance_paise']!,
          _balancePaiseMeta,
        ),
      );
    }
    if (data.containsKey('change_paise')) {
      context.handle(
        _changePaiseMeta,
        changePaise.isAcceptableOrUnknown(
          data['change_paise']!,
          _changePaiseMeta,
        ),
      );
    }
    if (data.containsKey('advance_kept_paise')) {
      context.handle(
        _advanceKeptPaiseMeta,
        advanceKeptPaise.isAcceptableOrUnknown(
          data['advance_kept_paise']!,
          _advanceKeptPaiseMeta,
        ),
      );
    }
    if (data.containsKey('taxable_paise')) {
      context.handle(
        _taxablePaiseMeta,
        taxablePaise.isAcceptableOrUnknown(
          data['taxable_paise']!,
          _taxablePaiseMeta,
        ),
      );
    }
    if (data.containsKey('cgst_paise')) {
      context.handle(
        _cgstPaiseMeta,
        cgstPaise.isAcceptableOrUnknown(data['cgst_paise']!, _cgstPaiseMeta),
      );
    }
    if (data.containsKey('sgst_paise')) {
      context.handle(
        _sgstPaiseMeta,
        sgstPaise.isAcceptableOrUnknown(data['sgst_paise']!, _sgstPaiseMeta),
      );
    }
    if (data.containsKey('igst_paise')) {
      context.handle(
        _igstPaiseMeta,
        igstPaise.isAcceptableOrUnknown(data['igst_paise']!, _igstPaiseMeta),
      );
    }
    if (data.containsKey('discount_paise')) {
      context.handle(
        _discountPaiseMeta,
        discountPaise.isAcceptableOrUnknown(
          data['discount_paise']!,
          _discountPaiseMeta,
        ),
      );
    }
    if (data.containsKey('round_off_paise')) {
      context.handle(
        _roundOffPaiseMeta,
        roundOffPaise.isAcceptableOrUnknown(
          data['round_off_paise']!,
          _roundOffPaiseMeta,
        ),
      );
    }
    if (data.containsKey('pay_mode')) {
      context.handle(
        _payModeMeta,
        payMode.isAcceptableOrUnknown(data['pay_mode']!, _payModeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('cancelled')) {
      context.handle(
        _cancelledMeta,
        cancelled.isAcceptableOrUnknown(data['cancelled']!, _cancelledMeta),
      );
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    if (data.containsKey('prices_include_gst')) {
      context.handle(
        _pricesIncludeGstMeta,
        pricesIncludeGst.isAcceptableOrUnknown(
          data['prices_include_gst']!,
          _pricesIncludeGstMeta,
        ),
      );
    }
    if (data.containsKey('idem_key')) {
      context.handle(
        _idemKeyMeta,
        idemKey.isAcceptableOrUnknown(data['idem_key']!, _idemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_idemKeyMeta);
    }
    if (data.containsKey('old_bill_no')) {
      context.handle(
        _oldBillNoMeta,
        oldBillNo.isAcceptableOrUnknown(data['old_bill_no']!, _oldBillNoMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      billedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billed_at'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      totalPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paise'],
      )!,
      receivedPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_paise'],
      )!,
      balancePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_paise'],
      )!,
      changePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_paise'],
      )!,
      advanceKeptPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}advance_kept_paise'],
      )!,
      taxablePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taxable_paise'],
      )!,
      cgstPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cgst_paise'],
      )!,
      sgstPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sgst_paise'],
      )!,
      igstPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}igst_paise'],
      )!,
      discountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_paise'],
      )!,
      roundOffPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_off_paise'],
      )!,
      payMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pay_mode'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      cancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      pricesIncludeGst: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prices_include_gst'],
      )!,
      idemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idem_key'],
      )!,
      oldBillNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_bill_no'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  Bills createAlias(String alias) {
    return Bills(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbBill extends DataClass implements Insertable<DbBill> {
  final String id;
  final String number;
  final String series;
  final int seq;
  final int billedAt;
  final String day;
  final String? customerId;
  final String customerName;
  final int totalPaise;
  final int receivedPaise;
  final int balancePaise;
  final int changePaise;
  final int advanceKeptPaise;
  final int taxablePaise;
  final int cgstPaise;
  final int sgstPaise;
  final int igstPaise;
  final int discountPaise;
  final int roundOffPaise;
  final int payMode;
  final int status;
  final int cancelled;
  final int itemCount;
  final int pricesIncludeGst;
  final String idemKey;
  final String? oldBillNo;
  final String note;
  final String createdBy;
  final int createdAt;
  final String deviceId;
  const DbBill({
    required this.id,
    required this.number,
    required this.series,
    required this.seq,
    required this.billedAt,
    required this.day,
    this.customerId,
    required this.customerName,
    required this.totalPaise,
    required this.receivedPaise,
    required this.balancePaise,
    required this.changePaise,
    required this.advanceKeptPaise,
    required this.taxablePaise,
    required this.cgstPaise,
    required this.sgstPaise,
    required this.igstPaise,
    required this.discountPaise,
    required this.roundOffPaise,
    required this.payMode,
    required this.status,
    required this.cancelled,
    required this.itemCount,
    required this.pricesIncludeGst,
    required this.idemKey,
    this.oldBillNo,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<String>(number);
    map['series'] = Variable<String>(series);
    map['seq'] = Variable<int>(seq);
    map['billed_at'] = Variable<int>(billedAt);
    map['day'] = Variable<String>(day);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['customer_name'] = Variable<String>(customerName);
    map['total_paise'] = Variable<int>(totalPaise);
    map['received_paise'] = Variable<int>(receivedPaise);
    map['balance_paise'] = Variable<int>(balancePaise);
    map['change_paise'] = Variable<int>(changePaise);
    map['advance_kept_paise'] = Variable<int>(advanceKeptPaise);
    map['taxable_paise'] = Variable<int>(taxablePaise);
    map['cgst_paise'] = Variable<int>(cgstPaise);
    map['sgst_paise'] = Variable<int>(sgstPaise);
    map['igst_paise'] = Variable<int>(igstPaise);
    map['discount_paise'] = Variable<int>(discountPaise);
    map['round_off_paise'] = Variable<int>(roundOffPaise);
    map['pay_mode'] = Variable<int>(payMode);
    map['status'] = Variable<int>(status);
    map['cancelled'] = Variable<int>(cancelled);
    map['item_count'] = Variable<int>(itemCount);
    map['prices_include_gst'] = Variable<int>(pricesIncludeGst);
    map['idem_key'] = Variable<String>(idemKey);
    if (!nullToAbsent || oldBillNo != null) {
      map['old_bill_no'] = Variable<String>(oldBillNo);
    }
    map['note'] = Variable<String>(note);
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      number: Value(number),
      series: Value(series),
      seq: Value(seq),
      billedAt: Value(billedAt),
      day: Value(day),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: Value(customerName),
      totalPaise: Value(totalPaise),
      receivedPaise: Value(receivedPaise),
      balancePaise: Value(balancePaise),
      changePaise: Value(changePaise),
      advanceKeptPaise: Value(advanceKeptPaise),
      taxablePaise: Value(taxablePaise),
      cgstPaise: Value(cgstPaise),
      sgstPaise: Value(sgstPaise),
      igstPaise: Value(igstPaise),
      discountPaise: Value(discountPaise),
      roundOffPaise: Value(roundOffPaise),
      payMode: Value(payMode),
      status: Value(status),
      cancelled: Value(cancelled),
      itemCount: Value(itemCount),
      pricesIncludeGst: Value(pricesIncludeGst),
      idemKey: Value(idemKey),
      oldBillNo: oldBillNo == null && nullToAbsent
          ? const Value.absent()
          : Value(oldBillNo),
      note: Value(note),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBill(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<String>(json['number']),
      series: serializer.fromJson<String>(json['series']),
      seq: serializer.fromJson<int>(json['seq']),
      billedAt: serializer.fromJson<int>(json['billed_at']),
      day: serializer.fromJson<String>(json['day']),
      customerId: serializer.fromJson<String?>(json['customer_id']),
      customerName: serializer.fromJson<String>(json['customer_name']),
      totalPaise: serializer.fromJson<int>(json['total_paise']),
      receivedPaise: serializer.fromJson<int>(json['received_paise']),
      balancePaise: serializer.fromJson<int>(json['balance_paise']),
      changePaise: serializer.fromJson<int>(json['change_paise']),
      advanceKeptPaise: serializer.fromJson<int>(json['advance_kept_paise']),
      taxablePaise: serializer.fromJson<int>(json['taxable_paise']),
      cgstPaise: serializer.fromJson<int>(json['cgst_paise']),
      sgstPaise: serializer.fromJson<int>(json['sgst_paise']),
      igstPaise: serializer.fromJson<int>(json['igst_paise']),
      discountPaise: serializer.fromJson<int>(json['discount_paise']),
      roundOffPaise: serializer.fromJson<int>(json['round_off_paise']),
      payMode: serializer.fromJson<int>(json['pay_mode']),
      status: serializer.fromJson<int>(json['status']),
      cancelled: serializer.fromJson<int>(json['cancelled']),
      itemCount: serializer.fromJson<int>(json['item_count']),
      pricesIncludeGst: serializer.fromJson<int>(json['prices_include_gst']),
      idemKey: serializer.fromJson<String>(json['idem_key']),
      oldBillNo: serializer.fromJson<String?>(json['old_bill_no']),
      note: serializer.fromJson<String>(json['note']),
      createdBy: serializer.fromJson<String>(json['created_by']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<String>(number),
      'series': serializer.toJson<String>(series),
      'seq': serializer.toJson<int>(seq),
      'billed_at': serializer.toJson<int>(billedAt),
      'day': serializer.toJson<String>(day),
      'customer_id': serializer.toJson<String?>(customerId),
      'customer_name': serializer.toJson<String>(customerName),
      'total_paise': serializer.toJson<int>(totalPaise),
      'received_paise': serializer.toJson<int>(receivedPaise),
      'balance_paise': serializer.toJson<int>(balancePaise),
      'change_paise': serializer.toJson<int>(changePaise),
      'advance_kept_paise': serializer.toJson<int>(advanceKeptPaise),
      'taxable_paise': serializer.toJson<int>(taxablePaise),
      'cgst_paise': serializer.toJson<int>(cgstPaise),
      'sgst_paise': serializer.toJson<int>(sgstPaise),
      'igst_paise': serializer.toJson<int>(igstPaise),
      'discount_paise': serializer.toJson<int>(discountPaise),
      'round_off_paise': serializer.toJson<int>(roundOffPaise),
      'pay_mode': serializer.toJson<int>(payMode),
      'status': serializer.toJson<int>(status),
      'cancelled': serializer.toJson<int>(cancelled),
      'item_count': serializer.toJson<int>(itemCount),
      'prices_include_gst': serializer.toJson<int>(pricesIncludeGst),
      'idem_key': serializer.toJson<String>(idemKey),
      'old_bill_no': serializer.toJson<String?>(oldBillNo),
      'note': serializer.toJson<String>(note),
      'created_by': serializer.toJson<String>(createdBy),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbBill copyWith({
    String? id,
    String? number,
    String? series,
    int? seq,
    int? billedAt,
    String? day,
    Value<String?> customerId = const Value.absent(),
    String? customerName,
    int? totalPaise,
    int? receivedPaise,
    int? balancePaise,
    int? changePaise,
    int? advanceKeptPaise,
    int? taxablePaise,
    int? cgstPaise,
    int? sgstPaise,
    int? igstPaise,
    int? discountPaise,
    int? roundOffPaise,
    int? payMode,
    int? status,
    int? cancelled,
    int? itemCount,
    int? pricesIncludeGst,
    String? idemKey,
    Value<String?> oldBillNo = const Value.absent(),
    String? note,
    String? createdBy,
    int? createdAt,
    String? deviceId,
  }) => DbBill(
    id: id ?? this.id,
    number: number ?? this.number,
    series: series ?? this.series,
    seq: seq ?? this.seq,
    billedAt: billedAt ?? this.billedAt,
    day: day ?? this.day,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName ?? this.customerName,
    totalPaise: totalPaise ?? this.totalPaise,
    receivedPaise: receivedPaise ?? this.receivedPaise,
    balancePaise: balancePaise ?? this.balancePaise,
    changePaise: changePaise ?? this.changePaise,
    advanceKeptPaise: advanceKeptPaise ?? this.advanceKeptPaise,
    taxablePaise: taxablePaise ?? this.taxablePaise,
    cgstPaise: cgstPaise ?? this.cgstPaise,
    sgstPaise: sgstPaise ?? this.sgstPaise,
    igstPaise: igstPaise ?? this.igstPaise,
    discountPaise: discountPaise ?? this.discountPaise,
    roundOffPaise: roundOffPaise ?? this.roundOffPaise,
    payMode: payMode ?? this.payMode,
    status: status ?? this.status,
    cancelled: cancelled ?? this.cancelled,
    itemCount: itemCount ?? this.itemCount,
    pricesIncludeGst: pricesIncludeGst ?? this.pricesIncludeGst,
    idemKey: idemKey ?? this.idemKey,
    oldBillNo: oldBillNo.present ? oldBillNo.value : this.oldBillNo,
    note: note ?? this.note,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbBill copyWithCompanion(BillsCompanion data) {
    return DbBill(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      series: data.series.present ? data.series.value : this.series,
      seq: data.seq.present ? data.seq.value : this.seq,
      billedAt: data.billedAt.present ? data.billedAt.value : this.billedAt,
      day: data.day.present ? data.day.value : this.day,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      totalPaise: data.totalPaise.present
          ? data.totalPaise.value
          : this.totalPaise,
      receivedPaise: data.receivedPaise.present
          ? data.receivedPaise.value
          : this.receivedPaise,
      balancePaise: data.balancePaise.present
          ? data.balancePaise.value
          : this.balancePaise,
      changePaise: data.changePaise.present
          ? data.changePaise.value
          : this.changePaise,
      advanceKeptPaise: data.advanceKeptPaise.present
          ? data.advanceKeptPaise.value
          : this.advanceKeptPaise,
      taxablePaise: data.taxablePaise.present
          ? data.taxablePaise.value
          : this.taxablePaise,
      cgstPaise: data.cgstPaise.present ? data.cgstPaise.value : this.cgstPaise,
      sgstPaise: data.sgstPaise.present ? data.sgstPaise.value : this.sgstPaise,
      igstPaise: data.igstPaise.present ? data.igstPaise.value : this.igstPaise,
      discountPaise: data.discountPaise.present
          ? data.discountPaise.value
          : this.discountPaise,
      roundOffPaise: data.roundOffPaise.present
          ? data.roundOffPaise.value
          : this.roundOffPaise,
      payMode: data.payMode.present ? data.payMode.value : this.payMode,
      status: data.status.present ? data.status.value : this.status,
      cancelled: data.cancelled.present ? data.cancelled.value : this.cancelled,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      pricesIncludeGst: data.pricesIncludeGst.present
          ? data.pricesIncludeGst.value
          : this.pricesIncludeGst,
      idemKey: data.idemKey.present ? data.idemKey.value : this.idemKey,
      oldBillNo: data.oldBillNo.present ? data.oldBillNo.value : this.oldBillNo,
      note: data.note.present ? data.note.value : this.note,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBill(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('series: $series, ')
          ..write('seq: $seq, ')
          ..write('billedAt: $billedAt, ')
          ..write('day: $day, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('receivedPaise: $receivedPaise, ')
          ..write('balancePaise: $balancePaise, ')
          ..write('changePaise: $changePaise, ')
          ..write('advanceKeptPaise: $advanceKeptPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('cgstPaise: $cgstPaise, ')
          ..write('sgstPaise: $sgstPaise, ')
          ..write('igstPaise: $igstPaise, ')
          ..write('discountPaise: $discountPaise, ')
          ..write('roundOffPaise: $roundOffPaise, ')
          ..write('payMode: $payMode, ')
          ..write('status: $status, ')
          ..write('cancelled: $cancelled, ')
          ..write('itemCount: $itemCount, ')
          ..write('pricesIncludeGst: $pricesIncludeGst, ')
          ..write('idemKey: $idemKey, ')
          ..write('oldBillNo: $oldBillNo, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    number,
    series,
    seq,
    billedAt,
    day,
    customerId,
    customerName,
    totalPaise,
    receivedPaise,
    balancePaise,
    changePaise,
    advanceKeptPaise,
    taxablePaise,
    cgstPaise,
    sgstPaise,
    igstPaise,
    discountPaise,
    roundOffPaise,
    payMode,
    status,
    cancelled,
    itemCount,
    pricesIncludeGst,
    idemKey,
    oldBillNo,
    note,
    createdBy,
    createdAt,
    deviceId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBill &&
          other.id == this.id &&
          other.number == this.number &&
          other.series == this.series &&
          other.seq == this.seq &&
          other.billedAt == this.billedAt &&
          other.day == this.day &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.totalPaise == this.totalPaise &&
          other.receivedPaise == this.receivedPaise &&
          other.balancePaise == this.balancePaise &&
          other.changePaise == this.changePaise &&
          other.advanceKeptPaise == this.advanceKeptPaise &&
          other.taxablePaise == this.taxablePaise &&
          other.cgstPaise == this.cgstPaise &&
          other.sgstPaise == this.sgstPaise &&
          other.igstPaise == this.igstPaise &&
          other.discountPaise == this.discountPaise &&
          other.roundOffPaise == this.roundOffPaise &&
          other.payMode == this.payMode &&
          other.status == this.status &&
          other.cancelled == this.cancelled &&
          other.itemCount == this.itemCount &&
          other.pricesIncludeGst == this.pricesIncludeGst &&
          other.idemKey == this.idemKey &&
          other.oldBillNo == this.oldBillNo &&
          other.note == this.note &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class BillsCompanion extends UpdateCompanion<DbBill> {
  final Value<String> id;
  final Value<String> number;
  final Value<String> series;
  final Value<int> seq;
  final Value<int> billedAt;
  final Value<String> day;
  final Value<String?> customerId;
  final Value<String> customerName;
  final Value<int> totalPaise;
  final Value<int> receivedPaise;
  final Value<int> balancePaise;
  final Value<int> changePaise;
  final Value<int> advanceKeptPaise;
  final Value<int> taxablePaise;
  final Value<int> cgstPaise;
  final Value<int> sgstPaise;
  final Value<int> igstPaise;
  final Value<int> discountPaise;
  final Value<int> roundOffPaise;
  final Value<int> payMode;
  final Value<int> status;
  final Value<int> cancelled;
  final Value<int> itemCount;
  final Value<int> pricesIncludeGst;
  final Value<String> idemKey;
  final Value<String?> oldBillNo;
  final Value<String> note;
  final Value<String> createdBy;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.series = const Value.absent(),
    this.seq = const Value.absent(),
    this.billedAt = const Value.absent(),
    this.day = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.totalPaise = const Value.absent(),
    this.receivedPaise = const Value.absent(),
    this.balancePaise = const Value.absent(),
    this.changePaise = const Value.absent(),
    this.advanceKeptPaise = const Value.absent(),
    this.taxablePaise = const Value.absent(),
    this.cgstPaise = const Value.absent(),
    this.sgstPaise = const Value.absent(),
    this.igstPaise = const Value.absent(),
    this.discountPaise = const Value.absent(),
    this.roundOffPaise = const Value.absent(),
    this.payMode = const Value.absent(),
    this.status = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.pricesIncludeGst = const Value.absent(),
    this.idemKey = const Value.absent(),
    this.oldBillNo = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillsCompanion.insert({
    required String id,
    required String number,
    required String series,
    required int seq,
    required int billedAt,
    required String day,
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    required int totalPaise,
    required int receivedPaise,
    this.balancePaise = const Value.absent(),
    this.changePaise = const Value.absent(),
    this.advanceKeptPaise = const Value.absent(),
    this.taxablePaise = const Value.absent(),
    this.cgstPaise = const Value.absent(),
    this.sgstPaise = const Value.absent(),
    this.igstPaise = const Value.absent(),
    this.discountPaise = const Value.absent(),
    this.roundOffPaise = const Value.absent(),
    this.payMode = const Value.absent(),
    this.status = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.pricesIncludeGst = const Value.absent(),
    required String idemKey,
    this.oldBillNo = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       number = Value(number),
       series = Value(series),
       seq = Value(seq),
       billedAt = Value(billedAt),
       day = Value(day),
       totalPaise = Value(totalPaise),
       receivedPaise = Value(receivedPaise),
       idemKey = Value(idemKey),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbBill> custom({
    Expression<String>? id,
    Expression<String>? number,
    Expression<String>? series,
    Expression<int>? seq,
    Expression<int>? billedAt,
    Expression<String>? day,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<int>? totalPaise,
    Expression<int>? receivedPaise,
    Expression<int>? balancePaise,
    Expression<int>? changePaise,
    Expression<int>? advanceKeptPaise,
    Expression<int>? taxablePaise,
    Expression<int>? cgstPaise,
    Expression<int>? sgstPaise,
    Expression<int>? igstPaise,
    Expression<int>? discountPaise,
    Expression<int>? roundOffPaise,
    Expression<int>? payMode,
    Expression<int>? status,
    Expression<int>? cancelled,
    Expression<int>? itemCount,
    Expression<int>? pricesIncludeGst,
    Expression<String>? idemKey,
    Expression<String>? oldBillNo,
    Expression<String>? note,
    Expression<String>? createdBy,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (series != null) 'series': series,
      if (seq != null) 'seq': seq,
      if (billedAt != null) 'billed_at': billedAt,
      if (day != null) 'day': day,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (totalPaise != null) 'total_paise': totalPaise,
      if (receivedPaise != null) 'received_paise': receivedPaise,
      if (balancePaise != null) 'balance_paise': balancePaise,
      if (changePaise != null) 'change_paise': changePaise,
      if (advanceKeptPaise != null) 'advance_kept_paise': advanceKeptPaise,
      if (taxablePaise != null) 'taxable_paise': taxablePaise,
      if (cgstPaise != null) 'cgst_paise': cgstPaise,
      if (sgstPaise != null) 'sgst_paise': sgstPaise,
      if (igstPaise != null) 'igst_paise': igstPaise,
      if (discountPaise != null) 'discount_paise': discountPaise,
      if (roundOffPaise != null) 'round_off_paise': roundOffPaise,
      if (payMode != null) 'pay_mode': payMode,
      if (status != null) 'status': status,
      if (cancelled != null) 'cancelled': cancelled,
      if (itemCount != null) 'item_count': itemCount,
      if (pricesIncludeGst != null) 'prices_include_gst': pricesIncludeGst,
      if (idemKey != null) 'idem_key': idemKey,
      if (oldBillNo != null) 'old_bill_no': oldBillNo,
      if (note != null) 'note': note,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillsCompanion copyWith({
    Value<String>? id,
    Value<String>? number,
    Value<String>? series,
    Value<int>? seq,
    Value<int>? billedAt,
    Value<String>? day,
    Value<String?>? customerId,
    Value<String>? customerName,
    Value<int>? totalPaise,
    Value<int>? receivedPaise,
    Value<int>? balancePaise,
    Value<int>? changePaise,
    Value<int>? advanceKeptPaise,
    Value<int>? taxablePaise,
    Value<int>? cgstPaise,
    Value<int>? sgstPaise,
    Value<int>? igstPaise,
    Value<int>? discountPaise,
    Value<int>? roundOffPaise,
    Value<int>? payMode,
    Value<int>? status,
    Value<int>? cancelled,
    Value<int>? itemCount,
    Value<int>? pricesIncludeGst,
    Value<String>? idemKey,
    Value<String?>? oldBillNo,
    Value<String>? note,
    Value<String>? createdBy,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return BillsCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      series: series ?? this.series,
      seq: seq ?? this.seq,
      billedAt: billedAt ?? this.billedAt,
      day: day ?? this.day,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalPaise: totalPaise ?? this.totalPaise,
      receivedPaise: receivedPaise ?? this.receivedPaise,
      balancePaise: balancePaise ?? this.balancePaise,
      changePaise: changePaise ?? this.changePaise,
      advanceKeptPaise: advanceKeptPaise ?? this.advanceKeptPaise,
      taxablePaise: taxablePaise ?? this.taxablePaise,
      cgstPaise: cgstPaise ?? this.cgstPaise,
      sgstPaise: sgstPaise ?? this.sgstPaise,
      igstPaise: igstPaise ?? this.igstPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      roundOffPaise: roundOffPaise ?? this.roundOffPaise,
      payMode: payMode ?? this.payMode,
      status: status ?? this.status,
      cancelled: cancelled ?? this.cancelled,
      itemCount: itemCount ?? this.itemCount,
      pricesIncludeGst: pricesIncludeGst ?? this.pricesIncludeGst,
      idemKey: idemKey ?? this.idemKey,
      oldBillNo: oldBillNo ?? this.oldBillNo,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (series.present) {
      map['series'] = Variable<String>(series.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (billedAt.present) {
      map['billed_at'] = Variable<int>(billedAt.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (totalPaise.present) {
      map['total_paise'] = Variable<int>(totalPaise.value);
    }
    if (receivedPaise.present) {
      map['received_paise'] = Variable<int>(receivedPaise.value);
    }
    if (balancePaise.present) {
      map['balance_paise'] = Variable<int>(balancePaise.value);
    }
    if (changePaise.present) {
      map['change_paise'] = Variable<int>(changePaise.value);
    }
    if (advanceKeptPaise.present) {
      map['advance_kept_paise'] = Variable<int>(advanceKeptPaise.value);
    }
    if (taxablePaise.present) {
      map['taxable_paise'] = Variable<int>(taxablePaise.value);
    }
    if (cgstPaise.present) {
      map['cgst_paise'] = Variable<int>(cgstPaise.value);
    }
    if (sgstPaise.present) {
      map['sgst_paise'] = Variable<int>(sgstPaise.value);
    }
    if (igstPaise.present) {
      map['igst_paise'] = Variable<int>(igstPaise.value);
    }
    if (discountPaise.present) {
      map['discount_paise'] = Variable<int>(discountPaise.value);
    }
    if (roundOffPaise.present) {
      map['round_off_paise'] = Variable<int>(roundOffPaise.value);
    }
    if (payMode.present) {
      map['pay_mode'] = Variable<int>(payMode.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (cancelled.present) {
      map['cancelled'] = Variable<int>(cancelled.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (pricesIncludeGst.present) {
      map['prices_include_gst'] = Variable<int>(pricesIncludeGst.value);
    }
    if (idemKey.present) {
      map['idem_key'] = Variable<String>(idemKey.value);
    }
    if (oldBillNo.present) {
      map['old_bill_no'] = Variable<String>(oldBillNo.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('series: $series, ')
          ..write('seq: $seq, ')
          ..write('billedAt: $billedAt, ')
          ..write('day: $day, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('receivedPaise: $receivedPaise, ')
          ..write('balancePaise: $balancePaise, ')
          ..write('changePaise: $changePaise, ')
          ..write('advanceKeptPaise: $advanceKeptPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('cgstPaise: $cgstPaise, ')
          ..write('sgstPaise: $sgstPaise, ')
          ..write('igstPaise: $igstPaise, ')
          ..write('discountPaise: $discountPaise, ')
          ..write('roundOffPaise: $roundOffPaise, ')
          ..write('payMode: $payMode, ')
          ..write('status: $status, ')
          ..write('cancelled: $cancelled, ')
          ..write('itemCount: $itemCount, ')
          ..write('pricesIncludeGst: $pricesIncludeGst, ')
          ..write('idemKey: $idemKey, ')
          ..write('oldBillNo: $oldBillNo, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class BillLines extends Table with TableInfo<BillLines, DbBillLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BillLines(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES bills(id)',
  );
  static const VerificationMeta _lineNoMeta = const VerificationMeta('lineNo');
  late final GeneratedColumn<int> lineNo = GeneratedColumn<int>(
    'line_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES products(id)',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pcs\'',
    defaultValue: const CustomExpression('\'pcs\''),
  );
  static const VerificationMeta _qtyMilliMeta = const VerificationMeta(
    'qtyMilli',
  );
  late final GeneratedColumn<int> qtyMilli = GeneratedColumn<int>(
    'qty_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ratePaiseMeta = const VerificationMeta(
    'ratePaise',
  );
  late final GeneratedColumn<int> ratePaise = GeneratedColumn<int>(
    'rate_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _costPaiseMeta = const VerificationMeta(
    'costPaise',
  );
  late final GeneratedColumn<int> costPaise = GeneratedColumn<int>(
    'cost_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _discountBpMeta = const VerificationMeta(
    'discountBp',
  );
  late final GeneratedColumn<int> discountBp = GeneratedColumn<int>(
    'discount_bp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _gstBpMeta = const VerificationMeta('gstBp');
  late final GeneratedColumn<int> gstBp = GeneratedColumn<int>(
    'gst_bp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _grossPaiseMeta = const VerificationMeta(
    'grossPaise',
  );
  late final GeneratedColumn<int> grossPaise = GeneratedColumn<int>(
    'gross_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _discountPaiseMeta = const VerificationMeta(
    'discountPaise',
  );
  late final GeneratedColumn<int> discountPaise = GeneratedColumn<int>(
    'discount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _taxablePaiseMeta = const VerificationMeta(
    'taxablePaise',
  );
  late final GeneratedColumn<int> taxablePaise = GeneratedColumn<int>(
    'taxable_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _taxPaiseMeta = const VerificationMeta(
    'taxPaise',
  );
  late final GeneratedColumn<int> taxPaise = GeneratedColumn<int>(
    'tax_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _totalPaiseMeta = const VerificationMeta(
    'totalPaise',
  );
  late final GeneratedColumn<int> totalPaise = GeneratedColumn<int>(
    'total_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    lineNo,
    productId,
    name,
    unit,
    qtyMilli,
    ratePaise,
    costPaise,
    discountBp,
    gstBp,
    grossPaise,
    discountPaise,
    taxablePaise,
    taxPaise,
    totalPaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bill_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBillLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('line_no')) {
      context.handle(
        _lineNoMeta,
        lineNo.isAcceptableOrUnknown(data['line_no']!, _lineNoMeta),
      );
    } else if (isInserting) {
      context.missing(_lineNoMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('qty_milli')) {
      context.handle(
        _qtyMilliMeta,
        qtyMilli.isAcceptableOrUnknown(data['qty_milli']!, _qtyMilliMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMilliMeta);
    }
    if (data.containsKey('rate_paise')) {
      context.handle(
        _ratePaiseMeta,
        ratePaise.isAcceptableOrUnknown(data['rate_paise']!, _ratePaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_ratePaiseMeta);
    }
    if (data.containsKey('cost_paise')) {
      context.handle(
        _costPaiseMeta,
        costPaise.isAcceptableOrUnknown(data['cost_paise']!, _costPaiseMeta),
      );
    }
    if (data.containsKey('discount_bp')) {
      context.handle(
        _discountBpMeta,
        discountBp.isAcceptableOrUnknown(data['discount_bp']!, _discountBpMeta),
      );
    }
    if (data.containsKey('gst_bp')) {
      context.handle(
        _gstBpMeta,
        gstBp.isAcceptableOrUnknown(data['gst_bp']!, _gstBpMeta),
      );
    }
    if (data.containsKey('gross_paise')) {
      context.handle(
        _grossPaiseMeta,
        grossPaise.isAcceptableOrUnknown(data['gross_paise']!, _grossPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_grossPaiseMeta);
    }
    if (data.containsKey('discount_paise')) {
      context.handle(
        _discountPaiseMeta,
        discountPaise.isAcceptableOrUnknown(
          data['discount_paise']!,
          _discountPaiseMeta,
        ),
      );
    }
    if (data.containsKey('taxable_paise')) {
      context.handle(
        _taxablePaiseMeta,
        taxablePaise.isAcceptableOrUnknown(
          data['taxable_paise']!,
          _taxablePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taxablePaiseMeta);
    }
    if (data.containsKey('tax_paise')) {
      context.handle(
        _taxPaiseMeta,
        taxPaise.isAcceptableOrUnknown(data['tax_paise']!, _taxPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_taxPaiseMeta);
    }
    if (data.containsKey('total_paise')) {
      context.handle(
        _totalPaiseMeta,
        totalPaise.isAcceptableOrUnknown(data['total_paise']!, _totalPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBillLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBillLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_id'],
      )!,
      lineNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_no'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      qtyMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_milli'],
      )!,
      ratePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_paise'],
      )!,
      costPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_paise'],
      )!,
      discountBp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_bp'],
      )!,
      gstBp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gst_bp'],
      )!,
      grossPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross_paise'],
      )!,
      discountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_paise'],
      )!,
      taxablePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taxable_paise'],
      )!,
      taxPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_paise'],
      )!,
      totalPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paise'],
      )!,
    );
  }

  @override
  BillLines createAlias(String alias) {
    return BillLines(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbBillLine extends DataClass implements Insertable<DbBillLine> {
  final String id;
  final String billId;
  final int lineNo;
  final String productId;
  final String name;
  final String unit;
  final int qtyMilli;
  final int ratePaise;
  final int costPaise;
  final int discountBp;
  final int gstBp;
  final int grossPaise;
  final int discountPaise;
  final int taxablePaise;
  final int taxPaise;
  final int totalPaise;
  const DbBillLine({
    required this.id,
    required this.billId,
    required this.lineNo,
    required this.productId,
    required this.name,
    required this.unit,
    required this.qtyMilli,
    required this.ratePaise,
    required this.costPaise,
    required this.discountBp,
    required this.gstBp,
    required this.grossPaise,
    required this.discountPaise,
    required this.taxablePaise,
    required this.taxPaise,
    required this.totalPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bill_id'] = Variable<String>(billId);
    map['line_no'] = Variable<int>(lineNo);
    map['product_id'] = Variable<String>(productId);
    map['name'] = Variable<String>(name);
    map['unit'] = Variable<String>(unit);
    map['qty_milli'] = Variable<int>(qtyMilli);
    map['rate_paise'] = Variable<int>(ratePaise);
    map['cost_paise'] = Variable<int>(costPaise);
    map['discount_bp'] = Variable<int>(discountBp);
    map['gst_bp'] = Variable<int>(gstBp);
    map['gross_paise'] = Variable<int>(grossPaise);
    map['discount_paise'] = Variable<int>(discountPaise);
    map['taxable_paise'] = Variable<int>(taxablePaise);
    map['tax_paise'] = Variable<int>(taxPaise);
    map['total_paise'] = Variable<int>(totalPaise);
    return map;
  }

  BillLinesCompanion toCompanion(bool nullToAbsent) {
    return BillLinesCompanion(
      id: Value(id),
      billId: Value(billId),
      lineNo: Value(lineNo),
      productId: Value(productId),
      name: Value(name),
      unit: Value(unit),
      qtyMilli: Value(qtyMilli),
      ratePaise: Value(ratePaise),
      costPaise: Value(costPaise),
      discountBp: Value(discountBp),
      gstBp: Value(gstBp),
      grossPaise: Value(grossPaise),
      discountPaise: Value(discountPaise),
      taxablePaise: Value(taxablePaise),
      taxPaise: Value(taxPaise),
      totalPaise: Value(totalPaise),
    );
  }

  factory DbBillLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBillLine(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['bill_id']),
      lineNo: serializer.fromJson<int>(json['line_no']),
      productId: serializer.fromJson<String>(json['product_id']),
      name: serializer.fromJson<String>(json['name']),
      unit: serializer.fromJson<String>(json['unit']),
      qtyMilli: serializer.fromJson<int>(json['qty_milli']),
      ratePaise: serializer.fromJson<int>(json['rate_paise']),
      costPaise: serializer.fromJson<int>(json['cost_paise']),
      discountBp: serializer.fromJson<int>(json['discount_bp']),
      gstBp: serializer.fromJson<int>(json['gst_bp']),
      grossPaise: serializer.fromJson<int>(json['gross_paise']),
      discountPaise: serializer.fromJson<int>(json['discount_paise']),
      taxablePaise: serializer.fromJson<int>(json['taxable_paise']),
      taxPaise: serializer.fromJson<int>(json['tax_paise']),
      totalPaise: serializer.fromJson<int>(json['total_paise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bill_id': serializer.toJson<String>(billId),
      'line_no': serializer.toJson<int>(lineNo),
      'product_id': serializer.toJson<String>(productId),
      'name': serializer.toJson<String>(name),
      'unit': serializer.toJson<String>(unit),
      'qty_milli': serializer.toJson<int>(qtyMilli),
      'rate_paise': serializer.toJson<int>(ratePaise),
      'cost_paise': serializer.toJson<int>(costPaise),
      'discount_bp': serializer.toJson<int>(discountBp),
      'gst_bp': serializer.toJson<int>(gstBp),
      'gross_paise': serializer.toJson<int>(grossPaise),
      'discount_paise': serializer.toJson<int>(discountPaise),
      'taxable_paise': serializer.toJson<int>(taxablePaise),
      'tax_paise': serializer.toJson<int>(taxPaise),
      'total_paise': serializer.toJson<int>(totalPaise),
    };
  }

  DbBillLine copyWith({
    String? id,
    String? billId,
    int? lineNo,
    String? productId,
    String? name,
    String? unit,
    int? qtyMilli,
    int? ratePaise,
    int? costPaise,
    int? discountBp,
    int? gstBp,
    int? grossPaise,
    int? discountPaise,
    int? taxablePaise,
    int? taxPaise,
    int? totalPaise,
  }) => DbBillLine(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    lineNo: lineNo ?? this.lineNo,
    productId: productId ?? this.productId,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    qtyMilli: qtyMilli ?? this.qtyMilli,
    ratePaise: ratePaise ?? this.ratePaise,
    costPaise: costPaise ?? this.costPaise,
    discountBp: discountBp ?? this.discountBp,
    gstBp: gstBp ?? this.gstBp,
    grossPaise: grossPaise ?? this.grossPaise,
    discountPaise: discountPaise ?? this.discountPaise,
    taxablePaise: taxablePaise ?? this.taxablePaise,
    taxPaise: taxPaise ?? this.taxPaise,
    totalPaise: totalPaise ?? this.totalPaise,
  );
  DbBillLine copyWithCompanion(BillLinesCompanion data) {
    return DbBillLine(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      lineNo: data.lineNo.present ? data.lineNo.value : this.lineNo,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      unit: data.unit.present ? data.unit.value : this.unit,
      qtyMilli: data.qtyMilli.present ? data.qtyMilli.value : this.qtyMilli,
      ratePaise: data.ratePaise.present ? data.ratePaise.value : this.ratePaise,
      costPaise: data.costPaise.present ? data.costPaise.value : this.costPaise,
      discountBp: data.discountBp.present
          ? data.discountBp.value
          : this.discountBp,
      gstBp: data.gstBp.present ? data.gstBp.value : this.gstBp,
      grossPaise: data.grossPaise.present
          ? data.grossPaise.value
          : this.grossPaise,
      discountPaise: data.discountPaise.present
          ? data.discountPaise.value
          : this.discountPaise,
      taxablePaise: data.taxablePaise.present
          ? data.taxablePaise.value
          : this.taxablePaise,
      taxPaise: data.taxPaise.present ? data.taxPaise.value : this.taxPaise,
      totalPaise: data.totalPaise.present
          ? data.totalPaise.value
          : this.totalPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBillLine(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('lineNo: $lineNo, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('ratePaise: $ratePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('discountBp: $discountBp, ')
          ..write('gstBp: $gstBp, ')
          ..write('grossPaise: $grossPaise, ')
          ..write('discountPaise: $discountPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('totalPaise: $totalPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    billId,
    lineNo,
    productId,
    name,
    unit,
    qtyMilli,
    ratePaise,
    costPaise,
    discountBp,
    gstBp,
    grossPaise,
    discountPaise,
    taxablePaise,
    taxPaise,
    totalPaise,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBillLine &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.lineNo == this.lineNo &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.unit == this.unit &&
          other.qtyMilli == this.qtyMilli &&
          other.ratePaise == this.ratePaise &&
          other.costPaise == this.costPaise &&
          other.discountBp == this.discountBp &&
          other.gstBp == this.gstBp &&
          other.grossPaise == this.grossPaise &&
          other.discountPaise == this.discountPaise &&
          other.taxablePaise == this.taxablePaise &&
          other.taxPaise == this.taxPaise &&
          other.totalPaise == this.totalPaise);
}

class BillLinesCompanion extends UpdateCompanion<DbBillLine> {
  final Value<String> id;
  final Value<String> billId;
  final Value<int> lineNo;
  final Value<String> productId;
  final Value<String> name;
  final Value<String> unit;
  final Value<int> qtyMilli;
  final Value<int> ratePaise;
  final Value<int> costPaise;
  final Value<int> discountBp;
  final Value<int> gstBp;
  final Value<int> grossPaise;
  final Value<int> discountPaise;
  final Value<int> taxablePaise;
  final Value<int> taxPaise;
  final Value<int> totalPaise;
  final Value<int> rowid;
  const BillLinesCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.lineNo = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.unit = const Value.absent(),
    this.qtyMilli = const Value.absent(),
    this.ratePaise = const Value.absent(),
    this.costPaise = const Value.absent(),
    this.discountBp = const Value.absent(),
    this.gstBp = const Value.absent(),
    this.grossPaise = const Value.absent(),
    this.discountPaise = const Value.absent(),
    this.taxablePaise = const Value.absent(),
    this.taxPaise = const Value.absent(),
    this.totalPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillLinesCompanion.insert({
    required String id,
    required String billId,
    required int lineNo,
    required String productId,
    required String name,
    this.unit = const Value.absent(),
    required int qtyMilli,
    required int ratePaise,
    this.costPaise = const Value.absent(),
    this.discountBp = const Value.absent(),
    this.gstBp = const Value.absent(),
    required int grossPaise,
    this.discountPaise = const Value.absent(),
    required int taxablePaise,
    required int taxPaise,
    required int totalPaise,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       lineNo = Value(lineNo),
       productId = Value(productId),
       name = Value(name),
       qtyMilli = Value(qtyMilli),
       ratePaise = Value(ratePaise),
       grossPaise = Value(grossPaise),
       taxablePaise = Value(taxablePaise),
       taxPaise = Value(taxPaise),
       totalPaise = Value(totalPaise);
  static Insertable<DbBillLine> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<int>? lineNo,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<String>? unit,
    Expression<int>? qtyMilli,
    Expression<int>? ratePaise,
    Expression<int>? costPaise,
    Expression<int>? discountBp,
    Expression<int>? gstBp,
    Expression<int>? grossPaise,
    Expression<int>? discountPaise,
    Expression<int>? taxablePaise,
    Expression<int>? taxPaise,
    Expression<int>? totalPaise,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (lineNo != null) 'line_no': lineNo,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (unit != null) 'unit': unit,
      if (qtyMilli != null) 'qty_milli': qtyMilli,
      if (ratePaise != null) 'rate_paise': ratePaise,
      if (costPaise != null) 'cost_paise': costPaise,
      if (discountBp != null) 'discount_bp': discountBp,
      if (gstBp != null) 'gst_bp': gstBp,
      if (grossPaise != null) 'gross_paise': grossPaise,
      if (discountPaise != null) 'discount_paise': discountPaise,
      if (taxablePaise != null) 'taxable_paise': taxablePaise,
      if (taxPaise != null) 'tax_paise': taxPaise,
      if (totalPaise != null) 'total_paise': totalPaise,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<int>? lineNo,
    Value<String>? productId,
    Value<String>? name,
    Value<String>? unit,
    Value<int>? qtyMilli,
    Value<int>? ratePaise,
    Value<int>? costPaise,
    Value<int>? discountBp,
    Value<int>? gstBp,
    Value<int>? grossPaise,
    Value<int>? discountPaise,
    Value<int>? taxablePaise,
    Value<int>? taxPaise,
    Value<int>? totalPaise,
    Value<int>? rowid,
  }) {
    return BillLinesCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qtyMilli: qtyMilli ?? this.qtyMilli,
      ratePaise: ratePaise ?? this.ratePaise,
      costPaise: costPaise ?? this.costPaise,
      discountBp: discountBp ?? this.discountBp,
      gstBp: gstBp ?? this.gstBp,
      grossPaise: grossPaise ?? this.grossPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      taxablePaise: taxablePaise ?? this.taxablePaise,
      taxPaise: taxPaise ?? this.taxPaise,
      totalPaise: totalPaise ?? this.totalPaise,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (lineNo.present) {
      map['line_no'] = Variable<int>(lineNo.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (qtyMilli.present) {
      map['qty_milli'] = Variable<int>(qtyMilli.value);
    }
    if (ratePaise.present) {
      map['rate_paise'] = Variable<int>(ratePaise.value);
    }
    if (costPaise.present) {
      map['cost_paise'] = Variable<int>(costPaise.value);
    }
    if (discountBp.present) {
      map['discount_bp'] = Variable<int>(discountBp.value);
    }
    if (gstBp.present) {
      map['gst_bp'] = Variable<int>(gstBp.value);
    }
    if (grossPaise.present) {
      map['gross_paise'] = Variable<int>(grossPaise.value);
    }
    if (discountPaise.present) {
      map['discount_paise'] = Variable<int>(discountPaise.value);
    }
    if (taxablePaise.present) {
      map['taxable_paise'] = Variable<int>(taxablePaise.value);
    }
    if (taxPaise.present) {
      map['tax_paise'] = Variable<int>(taxPaise.value);
    }
    if (totalPaise.present) {
      map['total_paise'] = Variable<int>(totalPaise.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillLinesCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('lineNo: $lineNo, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('ratePaise: $ratePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('discountBp: $discountBp, ')
          ..write('gstBp: $gstBp, ')
          ..write('grossPaise: $grossPaise, ')
          ..write('discountPaise: $discountPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class BillCancellations extends Table
    with TableInfo<BillCancellations, DbBillCancellation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BillCancellations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES bills(id)',
  );
  static const VerificationMeta _billNoMeta = const VerificationMeta('billNo');
  late final GeneratedColumn<String> billNo = GeneratedColumn<String>(
    'bill_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _byNameMeta = const VerificationMeta('byName');
  late final GeneratedColumn<String> byName = GeneratedColumn<String>(
    'by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    billNo,
    reason,
    byName,
    at,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bill_cancellations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBillCancellation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('bill_no')) {
      context.handle(
        _billNoMeta,
        billNo.isAcceptableOrUnknown(data['bill_no']!, _billNoMeta),
      );
    } else if (isInserting) {
      context.missing(_billNoMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('by_name')) {
      context.handle(
        _byNameMeta,
        byName.isAcceptableOrUnknown(data['by_name']!, _byNameMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBillCancellation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBillCancellation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_id'],
      )!,
      billNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_no'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      byName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_name'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  BillCancellations createAlias(String alias) {
    return BillCancellations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbBillCancellation extends DataClass
    implements Insertable<DbBillCancellation> {
  final String id;
  final String billId;
  final String billNo;
  final String reason;
  final String byName;
  final int at;
  final int createdAt;
  final String deviceId;
  const DbBillCancellation({
    required this.id,
    required this.billId,
    required this.billNo,
    required this.reason,
    required this.byName,
    required this.at,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bill_id'] = Variable<String>(billId);
    map['bill_no'] = Variable<String>(billNo);
    map['reason'] = Variable<String>(reason);
    map['by_name'] = Variable<String>(byName);
    map['at'] = Variable<int>(at);
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  BillCancellationsCompanion toCompanion(bool nullToAbsent) {
    return BillCancellationsCompanion(
      id: Value(id),
      billId: Value(billId),
      billNo: Value(billNo),
      reason: Value(reason),
      byName: Value(byName),
      at: Value(at),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbBillCancellation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBillCancellation(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['bill_id']),
      billNo: serializer.fromJson<String>(json['bill_no']),
      reason: serializer.fromJson<String>(json['reason']),
      byName: serializer.fromJson<String>(json['by_name']),
      at: serializer.fromJson<int>(json['at']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bill_id': serializer.toJson<String>(billId),
      'bill_no': serializer.toJson<String>(billNo),
      'reason': serializer.toJson<String>(reason),
      'by_name': serializer.toJson<String>(byName),
      'at': serializer.toJson<int>(at),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbBillCancellation copyWith({
    String? id,
    String? billId,
    String? billNo,
    String? reason,
    String? byName,
    int? at,
    int? createdAt,
    String? deviceId,
  }) => DbBillCancellation(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    billNo: billNo ?? this.billNo,
    reason: reason ?? this.reason,
    byName: byName ?? this.byName,
    at: at ?? this.at,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbBillCancellation copyWithCompanion(BillCancellationsCompanion data) {
    return DbBillCancellation(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      billNo: data.billNo.present ? data.billNo.value : this.billNo,
      reason: data.reason.present ? data.reason.value : this.reason,
      byName: data.byName.present ? data.byName.value : this.byName,
      at: data.at.present ? data.at.value : this.at,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBillCancellation(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('billNo: $billNo, ')
          ..write('reason: $reason, ')
          ..write('byName: $byName, ')
          ..write('at: $at, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, billId, billNo, reason, byName, at, createdAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBillCancellation &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.billNo == this.billNo &&
          other.reason == this.reason &&
          other.byName == this.byName &&
          other.at == this.at &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class BillCancellationsCompanion extends UpdateCompanion<DbBillCancellation> {
  final Value<String> id;
  final Value<String> billId;
  final Value<String> billNo;
  final Value<String> reason;
  final Value<String> byName;
  final Value<int> at;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const BillCancellationsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.billNo = const Value.absent(),
    this.reason = const Value.absent(),
    this.byName = const Value.absent(),
    this.at = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillCancellationsCompanion.insert({
    required String id,
    required String billId,
    required String billNo,
    required String reason,
    this.byName = const Value.absent(),
    required int at,
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       billNo = Value(billNo),
       reason = Value(reason),
       at = Value(at),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbBillCancellation> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<String>? billNo,
    Expression<String>? reason,
    Expression<String>? byName,
    Expression<int>? at,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (billNo != null) 'bill_no': billNo,
      if (reason != null) 'reason': reason,
      if (byName != null) 'by_name': byName,
      if (at != null) 'at': at,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillCancellationsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<String>? billNo,
    Value<String>? reason,
    Value<String>? byName,
    Value<int>? at,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return BillCancellationsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      billNo: billNo ?? this.billNo,
      reason: reason ?? this.reason,
      byName: byName ?? this.byName,
      at: at ?? this.at,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (billNo.present) {
      map['bill_no'] = Variable<String>(billNo.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (byName.present) {
      map['by_name'] = Variable<String>(byName.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillCancellationsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('billNo: $billNo, ')
          ..write('reason: $reason, ')
          ..write('byName: $byName, ')
          ..write('at: $at, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Estimations extends Table with TableInfo<Estimations, DbEstimation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Estimations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _editedOnMeta = const VerificationMeta(
    'editedOn',
  );
  late final GeneratedColumn<int> editedOn = GeneratedColumn<int>(
    'edited_on',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES customers(id)',
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _totalPaiseMeta = const VerificationMeta(
    'totalPaise',
  );
  late final GeneratedColumn<int> totalPaise = GeneratedColumn<int>(
    'total_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _convertedBillIdMeta = const VerificationMeta(
    'convertedBillId',
  );
  late final GeneratedColumn<String> convertedBillId = GeneratedColumn<String>(
    'converted_bill_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    number,
    at,
    editedOn,
    customerId,
    customerName,
    totalPaise,
    lineCount,
    convertedBillId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'estimations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbEstimation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('edited_on')) {
      context.handle(
        _editedOnMeta,
        editedOn.isAcceptableOrUnknown(data['edited_on']!, _editedOnMeta),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('total_paise')) {
      context.handle(
        _totalPaiseMeta,
        totalPaise.isAcceptableOrUnknown(data['total_paise']!, _totalPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPaiseMeta);
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    }
    if (data.containsKey('converted_bill_id')) {
      context.handle(
        _convertedBillIdMeta,
        convertedBillId.isAcceptableOrUnknown(
          data['converted_bill_id']!,
          _convertedBillIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbEstimation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbEstimation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      editedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edited_on'],
      ),
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      totalPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paise'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
      convertedBillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_bill_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Estimations createAlias(String alias) {
    return Estimations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbEstimation extends DataClass implements Insertable<DbEstimation> {
  final String id;
  final String number;
  final int at;
  final int? editedOn;
  final String? customerId;
  final String customerName;
  final int totalPaise;
  final int lineCount;
  final String? convertedBillId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbEstimation({
    required this.id,
    required this.number,
    required this.at,
    this.editedOn,
    this.customerId,
    required this.customerName,
    required this.totalPaise,
    required this.lineCount,
    this.convertedBillId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<String>(number);
    map['at'] = Variable<int>(at);
    if (!nullToAbsent || editedOn != null) {
      map['edited_on'] = Variable<int>(editedOn);
    }
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['customer_name'] = Variable<String>(customerName);
    map['total_paise'] = Variable<int>(totalPaise);
    map['line_count'] = Variable<int>(lineCount);
    if (!nullToAbsent || convertedBillId != null) {
      map['converted_bill_id'] = Variable<String>(convertedBillId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  EstimationsCompanion toCompanion(bool nullToAbsent) {
    return EstimationsCompanion(
      id: Value(id),
      number: Value(number),
      at: Value(at),
      editedOn: editedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(editedOn),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: Value(customerName),
      totalPaise: Value(totalPaise),
      lineCount: Value(lineCount),
      convertedBillId: convertedBillId == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedBillId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbEstimation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbEstimation(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<String>(json['number']),
      at: serializer.fromJson<int>(json['at']),
      editedOn: serializer.fromJson<int?>(json['edited_on']),
      customerId: serializer.fromJson<String?>(json['customer_id']),
      customerName: serializer.fromJson<String>(json['customer_name']),
      totalPaise: serializer.fromJson<int>(json['total_paise']),
      lineCount: serializer.fromJson<int>(json['line_count']),
      convertedBillId: serializer.fromJson<String?>(json['converted_bill_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<String>(number),
      'at': serializer.toJson<int>(at),
      'edited_on': serializer.toJson<int?>(editedOn),
      'customer_id': serializer.toJson<String?>(customerId),
      'customer_name': serializer.toJson<String>(customerName),
      'total_paise': serializer.toJson<int>(totalPaise),
      'line_count': serializer.toJson<int>(lineCount),
      'converted_bill_id': serializer.toJson<String?>(convertedBillId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbEstimation copyWith({
    String? id,
    String? number,
    int? at,
    Value<int?> editedOn = const Value.absent(),
    Value<String?> customerId = const Value.absent(),
    String? customerName,
    int? totalPaise,
    int? lineCount,
    Value<String?> convertedBillId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbEstimation(
    id: id ?? this.id,
    number: number ?? this.number,
    at: at ?? this.at,
    editedOn: editedOn.present ? editedOn.value : this.editedOn,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName ?? this.customerName,
    totalPaise: totalPaise ?? this.totalPaise,
    lineCount: lineCount ?? this.lineCount,
    convertedBillId: convertedBillId.present
        ? convertedBillId.value
        : this.convertedBillId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbEstimation copyWithCompanion(EstimationsCompanion data) {
    return DbEstimation(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      at: data.at.present ? data.at.value : this.at,
      editedOn: data.editedOn.present ? data.editedOn.value : this.editedOn,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      totalPaise: data.totalPaise.present
          ? data.totalPaise.value
          : this.totalPaise,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
      convertedBillId: data.convertedBillId.present
          ? data.convertedBillId.value
          : this.convertedBillId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbEstimation(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('at: $at, ')
          ..write('editedOn: $editedOn, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('lineCount: $lineCount, ')
          ..write('convertedBillId: $convertedBillId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    number,
    at,
    editedOn,
    customerId,
    customerName,
    totalPaise,
    lineCount,
    convertedBillId,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbEstimation &&
          other.id == this.id &&
          other.number == this.number &&
          other.at == this.at &&
          other.editedOn == this.editedOn &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.totalPaise == this.totalPaise &&
          other.lineCount == this.lineCount &&
          other.convertedBillId == this.convertedBillId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class EstimationsCompanion extends UpdateCompanion<DbEstimation> {
  final Value<String> id;
  final Value<String> number;
  final Value<int> at;
  final Value<int?> editedOn;
  final Value<String?> customerId;
  final Value<String> customerName;
  final Value<int> totalPaise;
  final Value<int> lineCount;
  final Value<String?> convertedBillId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const EstimationsCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.at = const Value.absent(),
    this.editedOn = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.totalPaise = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.convertedBillId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EstimationsCompanion.insert({
    required String id,
    required String number,
    required int at,
    this.editedOn = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    required int totalPaise,
    this.lineCount = const Value.absent(),
    this.convertedBillId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       number = Value(number),
       at = Value(at),
       totalPaise = Value(totalPaise),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbEstimation> custom({
    Expression<String>? id,
    Expression<String>? number,
    Expression<int>? at,
    Expression<int>? editedOn,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<int>? totalPaise,
    Expression<int>? lineCount,
    Expression<String>? convertedBillId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (at != null) 'at': at,
      if (editedOn != null) 'edited_on': editedOn,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (totalPaise != null) 'total_paise': totalPaise,
      if (lineCount != null) 'line_count': lineCount,
      if (convertedBillId != null) 'converted_bill_id': convertedBillId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EstimationsCompanion copyWith({
    Value<String>? id,
    Value<String>? number,
    Value<int>? at,
    Value<int?>? editedOn,
    Value<String?>? customerId,
    Value<String>? customerName,
    Value<int>? totalPaise,
    Value<int>? lineCount,
    Value<String?>? convertedBillId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return EstimationsCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      at: at ?? this.at,
      editedOn: editedOn ?? this.editedOn,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalPaise: totalPaise ?? this.totalPaise,
      lineCount: lineCount ?? this.lineCount,
      convertedBillId: convertedBillId ?? this.convertedBillId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (editedOn.present) {
      map['edited_on'] = Variable<int>(editedOn.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (totalPaise.present) {
      map['total_paise'] = Variable<int>(totalPaise.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (convertedBillId.present) {
      map['converted_bill_id'] = Variable<String>(convertedBillId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EstimationsCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('at: $at, ')
          ..write('editedOn: $editedOn, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('lineCount: $lineCount, ')
          ..write('convertedBillId: $convertedBillId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EstimationLines extends Table
    with TableInfo<EstimationLines, DbEstimationLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EstimationLines(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _estimationIdMeta = const VerificationMeta(
    'estimationId',
  );
  late final GeneratedColumn<String> estimationId = GeneratedColumn<String>(
    'estimation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES estimations(id)',
  );
  static const VerificationMeta _lineNoMeta = const VerificationMeta('lineNo');
  late final GeneratedColumn<int> lineNo = GeneratedColumn<int>(
    'line_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES products(id)',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pcs\'',
    defaultValue: const CustomExpression('\'pcs\''),
  );
  static const VerificationMeta _qtyMilliMeta = const VerificationMeta(
    'qtyMilli',
  );
  late final GeneratedColumn<int> qtyMilli = GeneratedColumn<int>(
    'qty_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ratePaiseMeta = const VerificationMeta(
    'ratePaise',
  );
  late final GeneratedColumn<int> ratePaise = GeneratedColumn<int>(
    'rate_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _discountBpMeta = const VerificationMeta(
    'discountBp',
  );
  late final GeneratedColumn<int> discountBp = GeneratedColumn<int>(
    'discount_bp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    estimationId,
    lineNo,
    productId,
    name,
    unit,
    qtyMilli,
    ratePaise,
    discountBp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'estimation_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbEstimationLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('estimation_id')) {
      context.handle(
        _estimationIdMeta,
        estimationId.isAcceptableOrUnknown(
          data['estimation_id']!,
          _estimationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimationIdMeta);
    }
    if (data.containsKey('line_no')) {
      context.handle(
        _lineNoMeta,
        lineNo.isAcceptableOrUnknown(data['line_no']!, _lineNoMeta),
      );
    } else if (isInserting) {
      context.missing(_lineNoMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('qty_milli')) {
      context.handle(
        _qtyMilliMeta,
        qtyMilli.isAcceptableOrUnknown(data['qty_milli']!, _qtyMilliMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMilliMeta);
    }
    if (data.containsKey('rate_paise')) {
      context.handle(
        _ratePaiseMeta,
        ratePaise.isAcceptableOrUnknown(data['rate_paise']!, _ratePaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_ratePaiseMeta);
    }
    if (data.containsKey('discount_bp')) {
      context.handle(
        _discountBpMeta,
        discountBp.isAcceptableOrUnknown(data['discount_bp']!, _discountBpMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbEstimationLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbEstimationLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      estimationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimation_id'],
      )!,
      lineNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_no'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      qtyMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_milli'],
      )!,
      ratePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_paise'],
      )!,
      discountBp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_bp'],
      )!,
    );
  }

  @override
  EstimationLines createAlias(String alias) {
    return EstimationLines(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbEstimationLine extends DataClass
    implements Insertable<DbEstimationLine> {
  final String id;
  final String estimationId;
  final int lineNo;
  final String productId;
  final String name;
  final String unit;
  final int qtyMilli;
  final int ratePaise;
  final int discountBp;
  const DbEstimationLine({
    required this.id,
    required this.estimationId,
    required this.lineNo,
    required this.productId,
    required this.name,
    required this.unit,
    required this.qtyMilli,
    required this.ratePaise,
    required this.discountBp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['estimation_id'] = Variable<String>(estimationId);
    map['line_no'] = Variable<int>(lineNo);
    map['product_id'] = Variable<String>(productId);
    map['name'] = Variable<String>(name);
    map['unit'] = Variable<String>(unit);
    map['qty_milli'] = Variable<int>(qtyMilli);
    map['rate_paise'] = Variable<int>(ratePaise);
    map['discount_bp'] = Variable<int>(discountBp);
    return map;
  }

  EstimationLinesCompanion toCompanion(bool nullToAbsent) {
    return EstimationLinesCompanion(
      id: Value(id),
      estimationId: Value(estimationId),
      lineNo: Value(lineNo),
      productId: Value(productId),
      name: Value(name),
      unit: Value(unit),
      qtyMilli: Value(qtyMilli),
      ratePaise: Value(ratePaise),
      discountBp: Value(discountBp),
    );
  }

  factory DbEstimationLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbEstimationLine(
      id: serializer.fromJson<String>(json['id']),
      estimationId: serializer.fromJson<String>(json['estimation_id']),
      lineNo: serializer.fromJson<int>(json['line_no']),
      productId: serializer.fromJson<String>(json['product_id']),
      name: serializer.fromJson<String>(json['name']),
      unit: serializer.fromJson<String>(json['unit']),
      qtyMilli: serializer.fromJson<int>(json['qty_milli']),
      ratePaise: serializer.fromJson<int>(json['rate_paise']),
      discountBp: serializer.fromJson<int>(json['discount_bp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'estimation_id': serializer.toJson<String>(estimationId),
      'line_no': serializer.toJson<int>(lineNo),
      'product_id': serializer.toJson<String>(productId),
      'name': serializer.toJson<String>(name),
      'unit': serializer.toJson<String>(unit),
      'qty_milli': serializer.toJson<int>(qtyMilli),
      'rate_paise': serializer.toJson<int>(ratePaise),
      'discount_bp': serializer.toJson<int>(discountBp),
    };
  }

  DbEstimationLine copyWith({
    String? id,
    String? estimationId,
    int? lineNo,
    String? productId,
    String? name,
    String? unit,
    int? qtyMilli,
    int? ratePaise,
    int? discountBp,
  }) => DbEstimationLine(
    id: id ?? this.id,
    estimationId: estimationId ?? this.estimationId,
    lineNo: lineNo ?? this.lineNo,
    productId: productId ?? this.productId,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    qtyMilli: qtyMilli ?? this.qtyMilli,
    ratePaise: ratePaise ?? this.ratePaise,
    discountBp: discountBp ?? this.discountBp,
  );
  DbEstimationLine copyWithCompanion(EstimationLinesCompanion data) {
    return DbEstimationLine(
      id: data.id.present ? data.id.value : this.id,
      estimationId: data.estimationId.present
          ? data.estimationId.value
          : this.estimationId,
      lineNo: data.lineNo.present ? data.lineNo.value : this.lineNo,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      unit: data.unit.present ? data.unit.value : this.unit,
      qtyMilli: data.qtyMilli.present ? data.qtyMilli.value : this.qtyMilli,
      ratePaise: data.ratePaise.present ? data.ratePaise.value : this.ratePaise,
      discountBp: data.discountBp.present
          ? data.discountBp.value
          : this.discountBp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbEstimationLine(')
          ..write('id: $id, ')
          ..write('estimationId: $estimationId, ')
          ..write('lineNo: $lineNo, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('ratePaise: $ratePaise, ')
          ..write('discountBp: $discountBp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    estimationId,
    lineNo,
    productId,
    name,
    unit,
    qtyMilli,
    ratePaise,
    discountBp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbEstimationLine &&
          other.id == this.id &&
          other.estimationId == this.estimationId &&
          other.lineNo == this.lineNo &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.unit == this.unit &&
          other.qtyMilli == this.qtyMilli &&
          other.ratePaise == this.ratePaise &&
          other.discountBp == this.discountBp);
}

class EstimationLinesCompanion extends UpdateCompanion<DbEstimationLine> {
  final Value<String> id;
  final Value<String> estimationId;
  final Value<int> lineNo;
  final Value<String> productId;
  final Value<String> name;
  final Value<String> unit;
  final Value<int> qtyMilli;
  final Value<int> ratePaise;
  final Value<int> discountBp;
  final Value<int> rowid;
  const EstimationLinesCompanion({
    this.id = const Value.absent(),
    this.estimationId = const Value.absent(),
    this.lineNo = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.unit = const Value.absent(),
    this.qtyMilli = const Value.absent(),
    this.ratePaise = const Value.absent(),
    this.discountBp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EstimationLinesCompanion.insert({
    required String id,
    required String estimationId,
    required int lineNo,
    required String productId,
    required String name,
    this.unit = const Value.absent(),
    required int qtyMilli,
    required int ratePaise,
    this.discountBp = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       estimationId = Value(estimationId),
       lineNo = Value(lineNo),
       productId = Value(productId),
       name = Value(name),
       qtyMilli = Value(qtyMilli),
       ratePaise = Value(ratePaise);
  static Insertable<DbEstimationLine> custom({
    Expression<String>? id,
    Expression<String>? estimationId,
    Expression<int>? lineNo,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<String>? unit,
    Expression<int>? qtyMilli,
    Expression<int>? ratePaise,
    Expression<int>? discountBp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (estimationId != null) 'estimation_id': estimationId,
      if (lineNo != null) 'line_no': lineNo,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (unit != null) 'unit': unit,
      if (qtyMilli != null) 'qty_milli': qtyMilli,
      if (ratePaise != null) 'rate_paise': ratePaise,
      if (discountBp != null) 'discount_bp': discountBp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EstimationLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? estimationId,
    Value<int>? lineNo,
    Value<String>? productId,
    Value<String>? name,
    Value<String>? unit,
    Value<int>? qtyMilli,
    Value<int>? ratePaise,
    Value<int>? discountBp,
    Value<int>? rowid,
  }) {
    return EstimationLinesCompanion(
      id: id ?? this.id,
      estimationId: estimationId ?? this.estimationId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qtyMilli: qtyMilli ?? this.qtyMilli,
      ratePaise: ratePaise ?? this.ratePaise,
      discountBp: discountBp ?? this.discountBp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (estimationId.present) {
      map['estimation_id'] = Variable<String>(estimationId.value);
    }
    if (lineNo.present) {
      map['line_no'] = Variable<int>(lineNo.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (qtyMilli.present) {
      map['qty_milli'] = Variable<int>(qtyMilli.value);
    }
    if (ratePaise.present) {
      map['rate_paise'] = Variable<int>(ratePaise.value);
    }
    if (discountBp.present) {
      map['discount_bp'] = Variable<int>(discountBp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EstimationLinesCompanion(')
          ..write('id: $id, ')
          ..write('estimationId: $estimationId, ')
          ..write('lineNo: $lineNo, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('ratePaise: $ratePaise, ')
          ..write('discountBp: $discountBp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LedgerEntries extends Table with TableInfo<LedgerEntries, DbLedgerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LedgerEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _partyKindMeta = const VerificationMeta(
    'partyKind',
  );
  late final GeneratedColumn<String> partyKind = GeneratedColumn<String>(
    'party_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _billNoMeta = const VerificationMeta('billNo');
  late final GeneratedColumn<String> billNo = GeneratedColumn<String>(
    'bill_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _byNameMeta = const VerificationMeta('byName');
  late final GeneratedColumn<String> byName = GeneratedColumn<String>(
    'by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _reversesMeta = const VerificationMeta(
    'reverses',
  );
  late final GeneratedColumn<String> reverses = GeneratedColumn<String>(
    'reverses',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _allocationsMeta = const VerificationMeta(
    'allocations',
  );
  late final GeneratedColumn<String> allocations = GeneratedColumn<String>(
    'allocations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _runningPaiseMeta = const VerificationMeta(
    'runningPaise',
  );
  late final GeneratedColumn<int> runningPaise = GeneratedColumn<int>(
    'running_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partyKind,
    partyId,
    kind,
    amountPaise,
    at,
    billNo,
    note,
    byName,
    mode,
    reverses,
    allocations,
    runningPaise,
    refId,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbLedgerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('party_kind')) {
      context.handle(
        _partyKindMeta,
        partyKind.isAcceptableOrUnknown(data['party_kind']!, _partyKindMeta),
      );
    } else if (isInserting) {
      context.missing(_partyKindMeta);
    }
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partyIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('bill_no')) {
      context.handle(
        _billNoMeta,
        billNo.isAcceptableOrUnknown(data['bill_no']!, _billNoMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('by_name')) {
      context.handle(
        _byNameMeta,
        byName.isAcceptableOrUnknown(data['by_name']!, _byNameMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('reverses')) {
      context.handle(
        _reversesMeta,
        reverses.isAcceptableOrUnknown(data['reverses']!, _reversesMeta),
      );
    }
    if (data.containsKey('allocations')) {
      context.handle(
        _allocationsMeta,
        allocations.isAcceptableOrUnknown(
          data['allocations']!,
          _allocationsMeta,
        ),
      );
    }
    if (data.containsKey('running_paise')) {
      context.handle(
        _runningPaiseMeta,
        runningPaise.isAcceptableOrUnknown(
          data['running_paise']!,
          _runningPaiseMeta,
        ),
      );
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbLedgerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbLedgerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_kind'],
      )!,
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      billNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_no'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      byName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_name'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      reverses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reverses'],
      ),
      allocations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allocations'],
      )!,
      runningPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}running_paise'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  LedgerEntries createAlias(String alias) {
    return LedgerEntries(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbLedgerEntry extends DataClass implements Insertable<DbLedgerEntry> {
  final String id;
  final String partyKind;
  final String partyId;
  final String kind;
  final int amountPaise;
  final int at;
  final String? billNo;
  final String note;
  final String byName;
  final String? mode;
  final String? reverses;
  final String allocations;
  final int runningPaise;
  final String? refId;
  final int createdAt;
  final String deviceId;
  const DbLedgerEntry({
    required this.id,
    required this.partyKind,
    required this.partyId,
    required this.kind,
    required this.amountPaise,
    required this.at,
    this.billNo,
    required this.note,
    required this.byName,
    this.mode,
    this.reverses,
    required this.allocations,
    required this.runningPaise,
    this.refId,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['party_kind'] = Variable<String>(partyKind);
    map['party_id'] = Variable<String>(partyId);
    map['kind'] = Variable<String>(kind);
    map['amount_paise'] = Variable<int>(amountPaise);
    map['at'] = Variable<int>(at);
    if (!nullToAbsent || billNo != null) {
      map['bill_no'] = Variable<String>(billNo);
    }
    map['note'] = Variable<String>(note);
    map['by_name'] = Variable<String>(byName);
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || reverses != null) {
      map['reverses'] = Variable<String>(reverses);
    }
    map['allocations'] = Variable<String>(allocations);
    map['running_paise'] = Variable<int>(runningPaise);
    if (!nullToAbsent || refId != null) {
      map['ref_id'] = Variable<String>(refId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  LedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return LedgerEntriesCompanion(
      id: Value(id),
      partyKind: Value(partyKind),
      partyId: Value(partyId),
      kind: Value(kind),
      amountPaise: Value(amountPaise),
      at: Value(at),
      billNo: billNo == null && nullToAbsent
          ? const Value.absent()
          : Value(billNo),
      note: Value(note),
      byName: Value(byName),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      reverses: reverses == null && nullToAbsent
          ? const Value.absent()
          : Value(reverses),
      allocations: Value(allocations),
      runningPaise: Value(runningPaise),
      refId: refId == null && nullToAbsent
          ? const Value.absent()
          : Value(refId),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbLedgerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbLedgerEntry(
      id: serializer.fromJson<String>(json['id']),
      partyKind: serializer.fromJson<String>(json['party_kind']),
      partyId: serializer.fromJson<String>(json['party_id']),
      kind: serializer.fromJson<String>(json['kind']),
      amountPaise: serializer.fromJson<int>(json['amount_paise']),
      at: serializer.fromJson<int>(json['at']),
      billNo: serializer.fromJson<String?>(json['bill_no']),
      note: serializer.fromJson<String>(json['note']),
      byName: serializer.fromJson<String>(json['by_name']),
      mode: serializer.fromJson<String?>(json['mode']),
      reverses: serializer.fromJson<String?>(json['reverses']),
      allocations: serializer.fromJson<String>(json['allocations']),
      runningPaise: serializer.fromJson<int>(json['running_paise']),
      refId: serializer.fromJson<String?>(json['ref_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'party_kind': serializer.toJson<String>(partyKind),
      'party_id': serializer.toJson<String>(partyId),
      'kind': serializer.toJson<String>(kind),
      'amount_paise': serializer.toJson<int>(amountPaise),
      'at': serializer.toJson<int>(at),
      'bill_no': serializer.toJson<String?>(billNo),
      'note': serializer.toJson<String>(note),
      'by_name': serializer.toJson<String>(byName),
      'mode': serializer.toJson<String?>(mode),
      'reverses': serializer.toJson<String?>(reverses),
      'allocations': serializer.toJson<String>(allocations),
      'running_paise': serializer.toJson<int>(runningPaise),
      'ref_id': serializer.toJson<String?>(refId),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbLedgerEntry copyWith({
    String? id,
    String? partyKind,
    String? partyId,
    String? kind,
    int? amountPaise,
    int? at,
    Value<String?> billNo = const Value.absent(),
    String? note,
    String? byName,
    Value<String?> mode = const Value.absent(),
    Value<String?> reverses = const Value.absent(),
    String? allocations,
    int? runningPaise,
    Value<String?> refId = const Value.absent(),
    int? createdAt,
    String? deviceId,
  }) => DbLedgerEntry(
    id: id ?? this.id,
    partyKind: partyKind ?? this.partyKind,
    partyId: partyId ?? this.partyId,
    kind: kind ?? this.kind,
    amountPaise: amountPaise ?? this.amountPaise,
    at: at ?? this.at,
    billNo: billNo.present ? billNo.value : this.billNo,
    note: note ?? this.note,
    byName: byName ?? this.byName,
    mode: mode.present ? mode.value : this.mode,
    reverses: reverses.present ? reverses.value : this.reverses,
    allocations: allocations ?? this.allocations,
    runningPaise: runningPaise ?? this.runningPaise,
    refId: refId.present ? refId.value : this.refId,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbLedgerEntry copyWithCompanion(LedgerEntriesCompanion data) {
    return DbLedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      partyKind: data.partyKind.present ? data.partyKind.value : this.partyKind,
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      at: data.at.present ? data.at.value : this.at,
      billNo: data.billNo.present ? data.billNo.value : this.billNo,
      note: data.note.present ? data.note.value : this.note,
      byName: data.byName.present ? data.byName.value : this.byName,
      mode: data.mode.present ? data.mode.value : this.mode,
      reverses: data.reverses.present ? data.reverses.value : this.reverses,
      allocations: data.allocations.present
          ? data.allocations.value
          : this.allocations,
      runningPaise: data.runningPaise.present
          ? data.runningPaise.value
          : this.runningPaise,
      refId: data.refId.present ? data.refId.value : this.refId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbLedgerEntry(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('kind: $kind, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('at: $at, ')
          ..write('billNo: $billNo, ')
          ..write('note: $note, ')
          ..write('byName: $byName, ')
          ..write('mode: $mode, ')
          ..write('reverses: $reverses, ')
          ..write('allocations: $allocations, ')
          ..write('runningPaise: $runningPaise, ')
          ..write('refId: $refId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partyKind,
    partyId,
    kind,
    amountPaise,
    at,
    billNo,
    note,
    byName,
    mode,
    reverses,
    allocations,
    runningPaise,
    refId,
    createdAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbLedgerEntry &&
          other.id == this.id &&
          other.partyKind == this.partyKind &&
          other.partyId == this.partyId &&
          other.kind == this.kind &&
          other.amountPaise == this.amountPaise &&
          other.at == this.at &&
          other.billNo == this.billNo &&
          other.note == this.note &&
          other.byName == this.byName &&
          other.mode == this.mode &&
          other.reverses == this.reverses &&
          other.allocations == this.allocations &&
          other.runningPaise == this.runningPaise &&
          other.refId == this.refId &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class LedgerEntriesCompanion extends UpdateCompanion<DbLedgerEntry> {
  final Value<String> id;
  final Value<String> partyKind;
  final Value<String> partyId;
  final Value<String> kind;
  final Value<int> amountPaise;
  final Value<int> at;
  final Value<String?> billNo;
  final Value<String> note;
  final Value<String> byName;
  final Value<String?> mode;
  final Value<String?> reverses;
  final Value<String> allocations;
  final Value<int> runningPaise;
  final Value<String?> refId;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const LedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.partyKind = const Value.absent(),
    this.partyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.at = const Value.absent(),
    this.billNo = const Value.absent(),
    this.note = const Value.absent(),
    this.byName = const Value.absent(),
    this.mode = const Value.absent(),
    this.reverses = const Value.absent(),
    this.allocations = const Value.absent(),
    this.runningPaise = const Value.absent(),
    this.refId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerEntriesCompanion.insert({
    required String id,
    required String partyKind,
    required String partyId,
    required String kind,
    required int amountPaise,
    required int at,
    this.billNo = const Value.absent(),
    this.note = const Value.absent(),
    this.byName = const Value.absent(),
    this.mode = const Value.absent(),
    this.reverses = const Value.absent(),
    this.allocations = const Value.absent(),
    this.runningPaise = const Value.absent(),
    this.refId = const Value.absent(),
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partyKind = Value(partyKind),
       partyId = Value(partyId),
       kind = Value(kind),
       amountPaise = Value(amountPaise),
       at = Value(at),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbLedgerEntry> custom({
    Expression<String>? id,
    Expression<String>? partyKind,
    Expression<String>? partyId,
    Expression<String>? kind,
    Expression<int>? amountPaise,
    Expression<int>? at,
    Expression<String>? billNo,
    Expression<String>? note,
    Expression<String>? byName,
    Expression<String>? mode,
    Expression<String>? reverses,
    Expression<String>? allocations,
    Expression<int>? runningPaise,
    Expression<String>? refId,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partyKind != null) 'party_kind': partyKind,
      if (partyId != null) 'party_id': partyId,
      if (kind != null) 'kind': kind,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (at != null) 'at': at,
      if (billNo != null) 'bill_no': billNo,
      if (note != null) 'note': note,
      if (byName != null) 'by_name': byName,
      if (mode != null) 'mode': mode,
      if (reverses != null) 'reverses': reverses,
      if (allocations != null) 'allocations': allocations,
      if (runningPaise != null) 'running_paise': runningPaise,
      if (refId != null) 'ref_id': refId,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? partyKind,
    Value<String>? partyId,
    Value<String>? kind,
    Value<int>? amountPaise,
    Value<int>? at,
    Value<String?>? billNo,
    Value<String>? note,
    Value<String>? byName,
    Value<String?>? mode,
    Value<String?>? reverses,
    Value<String>? allocations,
    Value<int>? runningPaise,
    Value<String?>? refId,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return LedgerEntriesCompanion(
      id: id ?? this.id,
      partyKind: partyKind ?? this.partyKind,
      partyId: partyId ?? this.partyId,
      kind: kind ?? this.kind,
      amountPaise: amountPaise ?? this.amountPaise,
      at: at ?? this.at,
      billNo: billNo ?? this.billNo,
      note: note ?? this.note,
      byName: byName ?? this.byName,
      mode: mode ?? this.mode,
      reverses: reverses ?? this.reverses,
      allocations: allocations ?? this.allocations,
      runningPaise: runningPaise ?? this.runningPaise,
      refId: refId ?? this.refId,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partyKind.present) {
      map['party_kind'] = Variable<String>(partyKind.value);
    }
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (billNo.present) {
      map['bill_no'] = Variable<String>(billNo.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (byName.present) {
      map['by_name'] = Variable<String>(byName.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (reverses.present) {
      map['reverses'] = Variable<String>(reverses.value);
    }
    if (allocations.present) {
      map['allocations'] = Variable<String>(allocations.value);
    }
    if (runningPaise.present) {
      map['running_paise'] = Variable<int>(runningPaise.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('kind: $kind, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('at: $at, ')
          ..write('billNo: $billNo, ')
          ..write('note: $note, ')
          ..write('byName: $byName, ')
          ..write('mode: $mode, ')
          ..write('reverses: $reverses, ')
          ..write('allocations: $allocations, ')
          ..write('runningPaise: $runningPaise, ')
          ..write('refId: $refId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Payments extends Table with TableInfo<Payments, DbPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Payments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _partyKindMeta = const VerificationMeta(
    'partyKind',
  );
  late final GeneratedColumn<String> partyKind = GeneratedColumn<String>(
    'party_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _advancePaiseMeta = const VerificationMeta(
    'advancePaise',
  );
  late final GeneratedColumn<int> advancePaise = GeneratedColumn<int>(
    'advance_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'cash\'',
    defaultValue: const CustomExpression('\'cash\''),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _receiptNoMeta = const VerificationMeta(
    'receiptNo',
  );
  late final GeneratedColumn<String> receiptNo = GeneratedColumn<String>(
    'receipt_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _allocationsMeta = const VerificationMeta(
    'allocations',
  );
  late final GeneratedColumn<String> allocations = GeneratedColumn<String>(
    'allocations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _byNameMeta = const VerificationMeta('byName');
  late final GeneratedColumn<String> byName = GeneratedColumn<String>(
    'by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partyKind,
    partyId,
    amountPaise,
    advancePaise,
    mode,
    at,
    note,
    receiptNo,
    allocations,
    byName,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('party_kind')) {
      context.handle(
        _partyKindMeta,
        partyKind.isAcceptableOrUnknown(data['party_kind']!, _partyKindMeta),
      );
    } else if (isInserting) {
      context.missing(_partyKindMeta);
    }
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partyIdMeta);
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    if (data.containsKey('advance_paise')) {
      context.handle(
        _advancePaiseMeta,
        advancePaise.isAcceptableOrUnknown(
          data['advance_paise']!,
          _advancePaiseMeta,
        ),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('receipt_no')) {
      context.handle(
        _receiptNoMeta,
        receiptNo.isAcceptableOrUnknown(data['receipt_no']!, _receiptNoMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptNoMeta);
    }
    if (data.containsKey('allocations')) {
      context.handle(
        _allocationsMeta,
        allocations.isAcceptableOrUnknown(
          data['allocations']!,
          _allocationsMeta,
        ),
      );
    }
    if (data.containsKey('by_name')) {
      context.handle(
        _byNameMeta,
        byName.isAcceptableOrUnknown(data['by_name']!, _byNameMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_kind'],
      )!,
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      advancePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}advance_paise'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      receiptNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_no'],
      )!,
      allocations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allocations'],
      )!,
      byName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  Payments createAlias(String alias) {
    return Payments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbPayment extends DataClass implements Insertable<DbPayment> {
  final String id;
  final String partyKind;
  final String partyId;
  final int amountPaise;
  final int advancePaise;
  final String mode;
  final int at;
  final String note;
  final String receiptNo;
  final String allocations;
  final String byName;
  final int createdAt;
  final String deviceId;
  const DbPayment({
    required this.id,
    required this.partyKind,
    required this.partyId,
    required this.amountPaise,
    required this.advancePaise,
    required this.mode,
    required this.at,
    required this.note,
    required this.receiptNo,
    required this.allocations,
    required this.byName,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['party_kind'] = Variable<String>(partyKind);
    map['party_id'] = Variable<String>(partyId);
    map['amount_paise'] = Variable<int>(amountPaise);
    map['advance_paise'] = Variable<int>(advancePaise);
    map['mode'] = Variable<String>(mode);
    map['at'] = Variable<int>(at);
    map['note'] = Variable<String>(note);
    map['receipt_no'] = Variable<String>(receiptNo);
    map['allocations'] = Variable<String>(allocations);
    map['by_name'] = Variable<String>(byName);
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      partyKind: Value(partyKind),
      partyId: Value(partyId),
      amountPaise: Value(amountPaise),
      advancePaise: Value(advancePaise),
      mode: Value(mode),
      at: Value(at),
      note: Value(note),
      receiptNo: Value(receiptNo),
      allocations: Value(allocations),
      byName: Value(byName),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPayment(
      id: serializer.fromJson<String>(json['id']),
      partyKind: serializer.fromJson<String>(json['party_kind']),
      partyId: serializer.fromJson<String>(json['party_id']),
      amountPaise: serializer.fromJson<int>(json['amount_paise']),
      advancePaise: serializer.fromJson<int>(json['advance_paise']),
      mode: serializer.fromJson<String>(json['mode']),
      at: serializer.fromJson<int>(json['at']),
      note: serializer.fromJson<String>(json['note']),
      receiptNo: serializer.fromJson<String>(json['receipt_no']),
      allocations: serializer.fromJson<String>(json['allocations']),
      byName: serializer.fromJson<String>(json['by_name']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'party_kind': serializer.toJson<String>(partyKind),
      'party_id': serializer.toJson<String>(partyId),
      'amount_paise': serializer.toJson<int>(amountPaise),
      'advance_paise': serializer.toJson<int>(advancePaise),
      'mode': serializer.toJson<String>(mode),
      'at': serializer.toJson<int>(at),
      'note': serializer.toJson<String>(note),
      'receipt_no': serializer.toJson<String>(receiptNo),
      'allocations': serializer.toJson<String>(allocations),
      'by_name': serializer.toJson<String>(byName),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbPayment copyWith({
    String? id,
    String? partyKind,
    String? partyId,
    int? amountPaise,
    int? advancePaise,
    String? mode,
    int? at,
    String? note,
    String? receiptNo,
    String? allocations,
    String? byName,
    int? createdAt,
    String? deviceId,
  }) => DbPayment(
    id: id ?? this.id,
    partyKind: partyKind ?? this.partyKind,
    partyId: partyId ?? this.partyId,
    amountPaise: amountPaise ?? this.amountPaise,
    advancePaise: advancePaise ?? this.advancePaise,
    mode: mode ?? this.mode,
    at: at ?? this.at,
    note: note ?? this.note,
    receiptNo: receiptNo ?? this.receiptNo,
    allocations: allocations ?? this.allocations,
    byName: byName ?? this.byName,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbPayment copyWithCompanion(PaymentsCompanion data) {
    return DbPayment(
      id: data.id.present ? data.id.value : this.id,
      partyKind: data.partyKind.present ? data.partyKind.value : this.partyKind,
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      advancePaise: data.advancePaise.present
          ? data.advancePaise.value
          : this.advancePaise,
      mode: data.mode.present ? data.mode.value : this.mode,
      at: data.at.present ? data.at.value : this.at,
      note: data.note.present ? data.note.value : this.note,
      receiptNo: data.receiptNo.present ? data.receiptNo.value : this.receiptNo,
      allocations: data.allocations.present
          ? data.allocations.value
          : this.allocations,
      byName: data.byName.present ? data.byName.value : this.byName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPayment(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('advancePaise: $advancePaise, ')
          ..write('mode: $mode, ')
          ..write('at: $at, ')
          ..write('note: $note, ')
          ..write('receiptNo: $receiptNo, ')
          ..write('allocations: $allocations, ')
          ..write('byName: $byName, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partyKind,
    partyId,
    amountPaise,
    advancePaise,
    mode,
    at,
    note,
    receiptNo,
    allocations,
    byName,
    createdAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPayment &&
          other.id == this.id &&
          other.partyKind == this.partyKind &&
          other.partyId == this.partyId &&
          other.amountPaise == this.amountPaise &&
          other.advancePaise == this.advancePaise &&
          other.mode == this.mode &&
          other.at == this.at &&
          other.note == this.note &&
          other.receiptNo == this.receiptNo &&
          other.allocations == this.allocations &&
          other.byName == this.byName &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class PaymentsCompanion extends UpdateCompanion<DbPayment> {
  final Value<String> id;
  final Value<String> partyKind;
  final Value<String> partyId;
  final Value<int> amountPaise;
  final Value<int> advancePaise;
  final Value<String> mode;
  final Value<int> at;
  final Value<String> note;
  final Value<String> receiptNo;
  final Value<String> allocations;
  final Value<String> byName;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.partyKind = const Value.absent(),
    this.partyId = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.advancePaise = const Value.absent(),
    this.mode = const Value.absent(),
    this.at = const Value.absent(),
    this.note = const Value.absent(),
    this.receiptNo = const Value.absent(),
    this.allocations = const Value.absent(),
    this.byName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String partyKind,
    required String partyId,
    required int amountPaise,
    this.advancePaise = const Value.absent(),
    this.mode = const Value.absent(),
    required int at,
    this.note = const Value.absent(),
    required String receiptNo,
    this.allocations = const Value.absent(),
    this.byName = const Value.absent(),
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partyKind = Value(partyKind),
       partyId = Value(partyId),
       amountPaise = Value(amountPaise),
       at = Value(at),
       receiptNo = Value(receiptNo),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbPayment> custom({
    Expression<String>? id,
    Expression<String>? partyKind,
    Expression<String>? partyId,
    Expression<int>? amountPaise,
    Expression<int>? advancePaise,
    Expression<String>? mode,
    Expression<int>? at,
    Expression<String>? note,
    Expression<String>? receiptNo,
    Expression<String>? allocations,
    Expression<String>? byName,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partyKind != null) 'party_kind': partyKind,
      if (partyId != null) 'party_id': partyId,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (advancePaise != null) 'advance_paise': advancePaise,
      if (mode != null) 'mode': mode,
      if (at != null) 'at': at,
      if (note != null) 'note': note,
      if (receiptNo != null) 'receipt_no': receiptNo,
      if (allocations != null) 'allocations': allocations,
      if (byName != null) 'by_name': byName,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? partyKind,
    Value<String>? partyId,
    Value<int>? amountPaise,
    Value<int>? advancePaise,
    Value<String>? mode,
    Value<int>? at,
    Value<String>? note,
    Value<String>? receiptNo,
    Value<String>? allocations,
    Value<String>? byName,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      partyKind: partyKind ?? this.partyKind,
      partyId: partyId ?? this.partyId,
      amountPaise: amountPaise ?? this.amountPaise,
      advancePaise: advancePaise ?? this.advancePaise,
      mode: mode ?? this.mode,
      at: at ?? this.at,
      note: note ?? this.note,
      receiptNo: receiptNo ?? this.receiptNo,
      allocations: allocations ?? this.allocations,
      byName: byName ?? this.byName,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partyKind.present) {
      map['party_kind'] = Variable<String>(partyKind.value);
    }
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (advancePaise.present) {
      map['advance_paise'] = Variable<int>(advancePaise.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (receiptNo.present) {
      map['receipt_no'] = Variable<String>(receiptNo.value);
    }
    if (allocations.present) {
      map['allocations'] = Variable<String>(allocations.value);
    }
    if (byName.present) {
      map['by_name'] = Variable<String>(byName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('advancePaise: $advancePaise, ')
          ..write('mode: $mode, ')
          ..write('at: $at, ')
          ..write('note: $note, ')
          ..write('receiptNo: $receiptNo, ')
          ..write('allocations: $allocations, ')
          ..write('byName: $byName, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PartyBills extends Table with TableInfo<PartyBills, DbPartyBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PartyBills(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _partyKindMeta = const VerificationMeta(
    'partyKind',
  );
  late final GeneratedColumn<String> partyKind = GeneratedColumn<String>(
    'party_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _billNoMeta = const VerificationMeta('billNo');
  late final GeneratedColumn<String> billNo = GeneratedColumn<String>(
    'bill_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _totalPaiseMeta = const VerificationMeta(
    'totalPaise',
  );
  late final GeneratedColumn<int> totalPaise = GeneratedColumn<int>(
    'total_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _paidPaiseMeta = const VerificationMeta(
    'paidPaise',
  );
  late final GeneratedColumn<int> paidPaise = GeneratedColumn<int>(
    'paid_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cancelledMeta = const VerificationMeta(
    'cancelled',
  );
  late final GeneratedColumn<int> cancelled = GeneratedColumn<int>(
    'cancelled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partyKind,
    partyId,
    billNo,
    date,
    totalPaise,
    paidPaise,
    cancelled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'party_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPartyBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('party_kind')) {
      context.handle(
        _partyKindMeta,
        partyKind.isAcceptableOrUnknown(data['party_kind']!, _partyKindMeta),
      );
    } else if (isInserting) {
      context.missing(_partyKindMeta);
    }
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partyIdMeta);
    }
    if (data.containsKey('bill_no')) {
      context.handle(
        _billNoMeta,
        billNo.isAcceptableOrUnknown(data['bill_no']!, _billNoMeta),
      );
    } else if (isInserting) {
      context.missing(_billNoMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('total_paise')) {
      context.handle(
        _totalPaiseMeta,
        totalPaise.isAcceptableOrUnknown(data['total_paise']!, _totalPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPaiseMeta);
    }
    if (data.containsKey('paid_paise')) {
      context.handle(
        _paidPaiseMeta,
        paidPaise.isAcceptableOrUnknown(data['paid_paise']!, _paidPaiseMeta),
      );
    }
    if (data.containsKey('cancelled')) {
      context.handle(
        _cancelledMeta,
        cancelled.isAcceptableOrUnknown(data['cancelled']!, _cancelledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPartyBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPartyBill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_kind'],
      )!,
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      )!,
      billNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_no'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      totalPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paise'],
      )!,
      paidPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_paise'],
      )!,
      cancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled'],
      )!,
    );
  }

  @override
  PartyBills createAlias(String alias) {
    return PartyBills(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbPartyBill extends DataClass implements Insertable<DbPartyBill> {
  final String id;
  final String partyKind;
  final String partyId;
  final String billNo;
  final int date;
  final int totalPaise;
  final int paidPaise;
  final int cancelled;
  const DbPartyBill({
    required this.id,
    required this.partyKind,
    required this.partyId,
    required this.billNo,
    required this.date,
    required this.totalPaise,
    required this.paidPaise,
    required this.cancelled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['party_kind'] = Variable<String>(partyKind);
    map['party_id'] = Variable<String>(partyId);
    map['bill_no'] = Variable<String>(billNo);
    map['date'] = Variable<int>(date);
    map['total_paise'] = Variable<int>(totalPaise);
    map['paid_paise'] = Variable<int>(paidPaise);
    map['cancelled'] = Variable<int>(cancelled);
    return map;
  }

  PartyBillsCompanion toCompanion(bool nullToAbsent) {
    return PartyBillsCompanion(
      id: Value(id),
      partyKind: Value(partyKind),
      partyId: Value(partyId),
      billNo: Value(billNo),
      date: Value(date),
      totalPaise: Value(totalPaise),
      paidPaise: Value(paidPaise),
      cancelled: Value(cancelled),
    );
  }

  factory DbPartyBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPartyBill(
      id: serializer.fromJson<String>(json['id']),
      partyKind: serializer.fromJson<String>(json['party_kind']),
      partyId: serializer.fromJson<String>(json['party_id']),
      billNo: serializer.fromJson<String>(json['bill_no']),
      date: serializer.fromJson<int>(json['date']),
      totalPaise: serializer.fromJson<int>(json['total_paise']),
      paidPaise: serializer.fromJson<int>(json['paid_paise']),
      cancelled: serializer.fromJson<int>(json['cancelled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'party_kind': serializer.toJson<String>(partyKind),
      'party_id': serializer.toJson<String>(partyId),
      'bill_no': serializer.toJson<String>(billNo),
      'date': serializer.toJson<int>(date),
      'total_paise': serializer.toJson<int>(totalPaise),
      'paid_paise': serializer.toJson<int>(paidPaise),
      'cancelled': serializer.toJson<int>(cancelled),
    };
  }

  DbPartyBill copyWith({
    String? id,
    String? partyKind,
    String? partyId,
    String? billNo,
    int? date,
    int? totalPaise,
    int? paidPaise,
    int? cancelled,
  }) => DbPartyBill(
    id: id ?? this.id,
    partyKind: partyKind ?? this.partyKind,
    partyId: partyId ?? this.partyId,
    billNo: billNo ?? this.billNo,
    date: date ?? this.date,
    totalPaise: totalPaise ?? this.totalPaise,
    paidPaise: paidPaise ?? this.paidPaise,
    cancelled: cancelled ?? this.cancelled,
  );
  DbPartyBill copyWithCompanion(PartyBillsCompanion data) {
    return DbPartyBill(
      id: data.id.present ? data.id.value : this.id,
      partyKind: data.partyKind.present ? data.partyKind.value : this.partyKind,
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      billNo: data.billNo.present ? data.billNo.value : this.billNo,
      date: data.date.present ? data.date.value : this.date,
      totalPaise: data.totalPaise.present
          ? data.totalPaise.value
          : this.totalPaise,
      paidPaise: data.paidPaise.present ? data.paidPaise.value : this.paidPaise,
      cancelled: data.cancelled.present ? data.cancelled.value : this.cancelled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPartyBill(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('billNo: $billNo, ')
          ..write('date: $date, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('paidPaise: $paidPaise, ')
          ..write('cancelled: $cancelled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partyKind,
    partyId,
    billNo,
    date,
    totalPaise,
    paidPaise,
    cancelled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPartyBill &&
          other.id == this.id &&
          other.partyKind == this.partyKind &&
          other.partyId == this.partyId &&
          other.billNo == this.billNo &&
          other.date == this.date &&
          other.totalPaise == this.totalPaise &&
          other.paidPaise == this.paidPaise &&
          other.cancelled == this.cancelled);
}

class PartyBillsCompanion extends UpdateCompanion<DbPartyBill> {
  final Value<String> id;
  final Value<String> partyKind;
  final Value<String> partyId;
  final Value<String> billNo;
  final Value<int> date;
  final Value<int> totalPaise;
  final Value<int> paidPaise;
  final Value<int> cancelled;
  final Value<int> rowid;
  const PartyBillsCompanion({
    this.id = const Value.absent(),
    this.partyKind = const Value.absent(),
    this.partyId = const Value.absent(),
    this.billNo = const Value.absent(),
    this.date = const Value.absent(),
    this.totalPaise = const Value.absent(),
    this.paidPaise = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartyBillsCompanion.insert({
    required String id,
    required String partyKind,
    required String partyId,
    required String billNo,
    required int date,
    required int totalPaise,
    this.paidPaise = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partyKind = Value(partyKind),
       partyId = Value(partyId),
       billNo = Value(billNo),
       date = Value(date),
       totalPaise = Value(totalPaise);
  static Insertable<DbPartyBill> custom({
    Expression<String>? id,
    Expression<String>? partyKind,
    Expression<String>? partyId,
    Expression<String>? billNo,
    Expression<int>? date,
    Expression<int>? totalPaise,
    Expression<int>? paidPaise,
    Expression<int>? cancelled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partyKind != null) 'party_kind': partyKind,
      if (partyId != null) 'party_id': partyId,
      if (billNo != null) 'bill_no': billNo,
      if (date != null) 'date': date,
      if (totalPaise != null) 'total_paise': totalPaise,
      if (paidPaise != null) 'paid_paise': paidPaise,
      if (cancelled != null) 'cancelled': cancelled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartyBillsCompanion copyWith({
    Value<String>? id,
    Value<String>? partyKind,
    Value<String>? partyId,
    Value<String>? billNo,
    Value<int>? date,
    Value<int>? totalPaise,
    Value<int>? paidPaise,
    Value<int>? cancelled,
    Value<int>? rowid,
  }) {
    return PartyBillsCompanion(
      id: id ?? this.id,
      partyKind: partyKind ?? this.partyKind,
      partyId: partyId ?? this.partyId,
      billNo: billNo ?? this.billNo,
      date: date ?? this.date,
      totalPaise: totalPaise ?? this.totalPaise,
      paidPaise: paidPaise ?? this.paidPaise,
      cancelled: cancelled ?? this.cancelled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partyKind.present) {
      map['party_kind'] = Variable<String>(partyKind.value);
    }
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (billNo.present) {
      map['bill_no'] = Variable<String>(billNo.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (totalPaise.present) {
      map['total_paise'] = Variable<int>(totalPaise.value);
    }
    if (paidPaise.present) {
      map['paid_paise'] = Variable<int>(paidPaise.value);
    }
    if (cancelled.present) {
      map['cancelled'] = Variable<int>(cancelled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartyBillsCompanion(')
          ..write('id: $id, ')
          ..write('partyKind: $partyKind, ')
          ..write('partyId: $partyId, ')
          ..write('billNo: $billNo, ')
          ..write('date: $date, ')
          ..write('totalPaise: $totalPaise, ')
          ..write('paidPaise: $paidPaise, ')
          ..write('cancelled: $cancelled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PartyBalance extends Table with TableInfo<PartyBalance, DbPartyBalance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PartyBalance(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _partyKindMeta = const VerificationMeta(
    'partyKind',
  );
  late final GeneratedColumn<String> partyKind = GeneratedColumn<String>(
    'party_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _balancePaiseMeta = const VerificationMeta(
    'balancePaise',
  );
  late final GeneratedColumn<int> balancePaise = GeneratedColumn<int>(
    'balance_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastBillAtMeta = const VerificationMeta(
    'lastBillAt',
  );
  late final GeneratedColumn<int> lastBillAt = GeneratedColumn<int>(
    'last_bill_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastPaymentAtMeta = const VerificationMeta(
    'lastPaymentAt',
  );
  late final GeneratedColumn<int> lastPaymentAt = GeneratedColumn<int>(
    'last_payment_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _entryCountMeta = const VerificationMeta(
    'entryCount',
  );
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
    'entry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    partyId,
    partyKind,
    balancePaise,
    lastBillAt,
    lastPaymentAt,
    entryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'party_balance';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPartyBalance> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partyIdMeta);
    }
    if (data.containsKey('party_kind')) {
      context.handle(
        _partyKindMeta,
        partyKind.isAcceptableOrUnknown(data['party_kind']!, _partyKindMeta),
      );
    } else if (isInserting) {
      context.missing(_partyKindMeta);
    }
    if (data.containsKey('balance_paise')) {
      context.handle(
        _balancePaiseMeta,
        balancePaise.isAcceptableOrUnknown(
          data['balance_paise']!,
          _balancePaiseMeta,
        ),
      );
    }
    if (data.containsKey('last_bill_at')) {
      context.handle(
        _lastBillAtMeta,
        lastBillAt.isAcceptableOrUnknown(
          data['last_bill_at']!,
          _lastBillAtMeta,
        ),
      );
    }
    if (data.containsKey('last_payment_at')) {
      context.handle(
        _lastPaymentAtMeta,
        lastPaymentAt.isAcceptableOrUnknown(
          data['last_payment_at']!,
          _lastPaymentAtMeta,
        ),
      );
    }
    if (data.containsKey('entry_count')) {
      context.handle(
        _entryCountMeta,
        entryCount.isAcceptableOrUnknown(data['entry_count']!, _entryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {partyId};
  @override
  DbPartyBalance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPartyBalance(
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      )!,
      partyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_kind'],
      )!,
      balancePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_paise'],
      )!,
      lastBillAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_bill_at'],
      ),
      lastPaymentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_payment_at'],
      ),
      entryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_count'],
      )!,
    );
  }

  @override
  PartyBalance createAlias(String alias) {
    return PartyBalance(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbPartyBalance extends DataClass implements Insertable<DbPartyBalance> {
  final String partyId;
  final String partyKind;
  final int balancePaise;
  final int? lastBillAt;
  final int? lastPaymentAt;
  final int entryCount;
  const DbPartyBalance({
    required this.partyId,
    required this.partyKind,
    required this.balancePaise,
    this.lastBillAt,
    this.lastPaymentAt,
    required this.entryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['party_id'] = Variable<String>(partyId);
    map['party_kind'] = Variable<String>(partyKind);
    map['balance_paise'] = Variable<int>(balancePaise);
    if (!nullToAbsent || lastBillAt != null) {
      map['last_bill_at'] = Variable<int>(lastBillAt);
    }
    if (!nullToAbsent || lastPaymentAt != null) {
      map['last_payment_at'] = Variable<int>(lastPaymentAt);
    }
    map['entry_count'] = Variable<int>(entryCount);
    return map;
  }

  PartyBalanceCompanion toCompanion(bool nullToAbsent) {
    return PartyBalanceCompanion(
      partyId: Value(partyId),
      partyKind: Value(partyKind),
      balancePaise: Value(balancePaise),
      lastBillAt: lastBillAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBillAt),
      lastPaymentAt: lastPaymentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPaymentAt),
      entryCount: Value(entryCount),
    );
  }

  factory DbPartyBalance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPartyBalance(
      partyId: serializer.fromJson<String>(json['party_id']),
      partyKind: serializer.fromJson<String>(json['party_kind']),
      balancePaise: serializer.fromJson<int>(json['balance_paise']),
      lastBillAt: serializer.fromJson<int?>(json['last_bill_at']),
      lastPaymentAt: serializer.fromJson<int?>(json['last_payment_at']),
      entryCount: serializer.fromJson<int>(json['entry_count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'party_id': serializer.toJson<String>(partyId),
      'party_kind': serializer.toJson<String>(partyKind),
      'balance_paise': serializer.toJson<int>(balancePaise),
      'last_bill_at': serializer.toJson<int?>(lastBillAt),
      'last_payment_at': serializer.toJson<int?>(lastPaymentAt),
      'entry_count': serializer.toJson<int>(entryCount),
    };
  }

  DbPartyBalance copyWith({
    String? partyId,
    String? partyKind,
    int? balancePaise,
    Value<int?> lastBillAt = const Value.absent(),
    Value<int?> lastPaymentAt = const Value.absent(),
    int? entryCount,
  }) => DbPartyBalance(
    partyId: partyId ?? this.partyId,
    partyKind: partyKind ?? this.partyKind,
    balancePaise: balancePaise ?? this.balancePaise,
    lastBillAt: lastBillAt.present ? lastBillAt.value : this.lastBillAt,
    lastPaymentAt: lastPaymentAt.present
        ? lastPaymentAt.value
        : this.lastPaymentAt,
    entryCount: entryCount ?? this.entryCount,
  );
  DbPartyBalance copyWithCompanion(PartyBalanceCompanion data) {
    return DbPartyBalance(
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      partyKind: data.partyKind.present ? data.partyKind.value : this.partyKind,
      balancePaise: data.balancePaise.present
          ? data.balancePaise.value
          : this.balancePaise,
      lastBillAt: data.lastBillAt.present
          ? data.lastBillAt.value
          : this.lastBillAt,
      lastPaymentAt: data.lastPaymentAt.present
          ? data.lastPaymentAt.value
          : this.lastPaymentAt,
      entryCount: data.entryCount.present
          ? data.entryCount.value
          : this.entryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPartyBalance(')
          ..write('partyId: $partyId, ')
          ..write('partyKind: $partyKind, ')
          ..write('balancePaise: $balancePaise, ')
          ..write('lastBillAt: $lastBillAt, ')
          ..write('lastPaymentAt: $lastPaymentAt, ')
          ..write('entryCount: $entryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    partyId,
    partyKind,
    balancePaise,
    lastBillAt,
    lastPaymentAt,
    entryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPartyBalance &&
          other.partyId == this.partyId &&
          other.partyKind == this.partyKind &&
          other.balancePaise == this.balancePaise &&
          other.lastBillAt == this.lastBillAt &&
          other.lastPaymentAt == this.lastPaymentAt &&
          other.entryCount == this.entryCount);
}

class PartyBalanceCompanion extends UpdateCompanion<DbPartyBalance> {
  final Value<String> partyId;
  final Value<String> partyKind;
  final Value<int> balancePaise;
  final Value<int?> lastBillAt;
  final Value<int?> lastPaymentAt;
  final Value<int> entryCount;
  final Value<int> rowid;
  const PartyBalanceCompanion({
    this.partyId = const Value.absent(),
    this.partyKind = const Value.absent(),
    this.balancePaise = const Value.absent(),
    this.lastBillAt = const Value.absent(),
    this.lastPaymentAt = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartyBalanceCompanion.insert({
    required String partyId,
    required String partyKind,
    this.balancePaise = const Value.absent(),
    this.lastBillAt = const Value.absent(),
    this.lastPaymentAt = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : partyId = Value(partyId),
       partyKind = Value(partyKind);
  static Insertable<DbPartyBalance> custom({
    Expression<String>? partyId,
    Expression<String>? partyKind,
    Expression<int>? balancePaise,
    Expression<int>? lastBillAt,
    Expression<int>? lastPaymentAt,
    Expression<int>? entryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (partyId != null) 'party_id': partyId,
      if (partyKind != null) 'party_kind': partyKind,
      if (balancePaise != null) 'balance_paise': balancePaise,
      if (lastBillAt != null) 'last_bill_at': lastBillAt,
      if (lastPaymentAt != null) 'last_payment_at': lastPaymentAt,
      if (entryCount != null) 'entry_count': entryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartyBalanceCompanion copyWith({
    Value<String>? partyId,
    Value<String>? partyKind,
    Value<int>? balancePaise,
    Value<int?>? lastBillAt,
    Value<int?>? lastPaymentAt,
    Value<int>? entryCount,
    Value<int>? rowid,
  }) {
    return PartyBalanceCompanion(
      partyId: partyId ?? this.partyId,
      partyKind: partyKind ?? this.partyKind,
      balancePaise: balancePaise ?? this.balancePaise,
      lastBillAt: lastBillAt ?? this.lastBillAt,
      lastPaymentAt: lastPaymentAt ?? this.lastPaymentAt,
      entryCount: entryCount ?? this.entryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (partyKind.present) {
      map['party_kind'] = Variable<String>(partyKind.value);
    }
    if (balancePaise.present) {
      map['balance_paise'] = Variable<int>(balancePaise.value);
    }
    if (lastBillAt.present) {
      map['last_bill_at'] = Variable<int>(lastBillAt.value);
    }
    if (lastPaymentAt.present) {
      map['last_payment_at'] = Variable<int>(lastPaymentAt.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartyBalanceCompanion(')
          ..write('partyId: $partyId, ')
          ..write('partyKind: $partyKind, ')
          ..write('balancePaise: $balancePaise, ')
          ..write('lastBillAt: $lastBillAt, ')
          ..write('lastPaymentAt: $lastPaymentAt, ')
          ..write('entryCount: $entryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DayTotals extends Table with TableInfo<DayTotals, DbDayTotal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DayTotals(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _billsMeta = const VerificationMeta('bills');
  late final GeneratedColumn<int> bills = GeneratedColumn<int>(
    'bills',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _salesPaiseMeta = const VerificationMeta(
    'salesPaise',
  );
  late final GeneratedColumn<int> salesPaise = GeneratedColumn<int>(
    'sales_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _taxablePaiseMeta = const VerificationMeta(
    'taxablePaise',
  );
  late final GeneratedColumn<int> taxablePaise = GeneratedColumn<int>(
    'taxable_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _costPaiseMeta = const VerificationMeta(
    'costPaise',
  );
  late final GeneratedColumn<int> costPaise = GeneratedColumn<int>(
    'cost_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _taxPaiseMeta = const VerificationMeta(
    'taxPaise',
  );
  late final GeneratedColumn<int> taxPaise = GeneratedColumn<int>(
    'tax_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cashPaiseMeta = const VerificationMeta(
    'cashPaise',
  );
  late final GeneratedColumn<int> cashPaise = GeneratedColumn<int>(
    'cash_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _upiPaiseMeta = const VerificationMeta(
    'upiPaise',
  );
  late final GeneratedColumn<int> upiPaise = GeneratedColumn<int>(
    'upi_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cardPaiseMeta = const VerificationMeta(
    'cardPaise',
  );
  late final GeneratedColumn<int> cardPaise = GeneratedColumn<int>(
    'card_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _creditPaiseMeta = const VerificationMeta(
    'creditPaise',
  );
  late final GeneratedColumn<int> creditPaise = GeneratedColumn<int>(
    'credit_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cancelledBillsMeta = const VerificationMeta(
    'cancelledBills',
  );
  late final GeneratedColumn<int> cancelledBills = GeneratedColumn<int>(
    'cancelled_bills',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _cancelledPaiseMeta = const VerificationMeta(
    'cancelledPaise',
  );
  late final GeneratedColumn<int> cancelledPaise = GeneratedColumn<int>(
    'cancelled_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    bills,
    salesPaise,
    taxablePaise,
    costPaise,
    taxPaise,
    cashPaise,
    upiPaise,
    cardPaise,
    creditPaise,
    cancelledBills,
    cancelledPaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_totals';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDayTotal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('bills')) {
      context.handle(
        _billsMeta,
        bills.isAcceptableOrUnknown(data['bills']!, _billsMeta),
      );
    }
    if (data.containsKey('sales_paise')) {
      context.handle(
        _salesPaiseMeta,
        salesPaise.isAcceptableOrUnknown(data['sales_paise']!, _salesPaiseMeta),
      );
    }
    if (data.containsKey('taxable_paise')) {
      context.handle(
        _taxablePaiseMeta,
        taxablePaise.isAcceptableOrUnknown(
          data['taxable_paise']!,
          _taxablePaiseMeta,
        ),
      );
    }
    if (data.containsKey('cost_paise')) {
      context.handle(
        _costPaiseMeta,
        costPaise.isAcceptableOrUnknown(data['cost_paise']!, _costPaiseMeta),
      );
    }
    if (data.containsKey('tax_paise')) {
      context.handle(
        _taxPaiseMeta,
        taxPaise.isAcceptableOrUnknown(data['tax_paise']!, _taxPaiseMeta),
      );
    }
    if (data.containsKey('cash_paise')) {
      context.handle(
        _cashPaiseMeta,
        cashPaise.isAcceptableOrUnknown(data['cash_paise']!, _cashPaiseMeta),
      );
    }
    if (data.containsKey('upi_paise')) {
      context.handle(
        _upiPaiseMeta,
        upiPaise.isAcceptableOrUnknown(data['upi_paise']!, _upiPaiseMeta),
      );
    }
    if (data.containsKey('card_paise')) {
      context.handle(
        _cardPaiseMeta,
        cardPaise.isAcceptableOrUnknown(data['card_paise']!, _cardPaiseMeta),
      );
    }
    if (data.containsKey('credit_paise')) {
      context.handle(
        _creditPaiseMeta,
        creditPaise.isAcceptableOrUnknown(
          data['credit_paise']!,
          _creditPaiseMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_bills')) {
      context.handle(
        _cancelledBillsMeta,
        cancelledBills.isAcceptableOrUnknown(
          data['cancelled_bills']!,
          _cancelledBillsMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_paise')) {
      context.handle(
        _cancelledPaiseMeta,
        cancelledPaise.isAcceptableOrUnknown(
          data['cancelled_paise']!,
          _cancelledPaiseMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DbDayTotal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDayTotal(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      bills: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bills'],
      )!,
      salesPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sales_paise'],
      )!,
      taxablePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taxable_paise'],
      )!,
      costPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_paise'],
      )!,
      taxPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_paise'],
      )!,
      cashPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cash_paise'],
      )!,
      upiPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upi_paise'],
      )!,
      cardPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_paise'],
      )!,
      creditPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_paise'],
      )!,
      cancelledBills: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled_bills'],
      )!,
      cancelledPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled_paise'],
      )!,
    );
  }

  @override
  DayTotals createAlias(String alias) {
    return DayTotals(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbDayTotal extends DataClass implements Insertable<DbDayTotal> {
  final String day;
  final int bills;
  final int salesPaise;
  final int taxablePaise;
  final int costPaise;
  final int taxPaise;
  final int cashPaise;
  final int upiPaise;
  final int cardPaise;
  final int creditPaise;
  final int cancelledBills;
  final int cancelledPaise;
  const DbDayTotal({
    required this.day,
    required this.bills,
    required this.salesPaise,
    required this.taxablePaise,
    required this.costPaise,
    required this.taxPaise,
    required this.cashPaise,
    required this.upiPaise,
    required this.cardPaise,
    required this.creditPaise,
    required this.cancelledBills,
    required this.cancelledPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['bills'] = Variable<int>(bills);
    map['sales_paise'] = Variable<int>(salesPaise);
    map['taxable_paise'] = Variable<int>(taxablePaise);
    map['cost_paise'] = Variable<int>(costPaise);
    map['tax_paise'] = Variable<int>(taxPaise);
    map['cash_paise'] = Variable<int>(cashPaise);
    map['upi_paise'] = Variable<int>(upiPaise);
    map['card_paise'] = Variable<int>(cardPaise);
    map['credit_paise'] = Variable<int>(creditPaise);
    map['cancelled_bills'] = Variable<int>(cancelledBills);
    map['cancelled_paise'] = Variable<int>(cancelledPaise);
    return map;
  }

  DayTotalsCompanion toCompanion(bool nullToAbsent) {
    return DayTotalsCompanion(
      day: Value(day),
      bills: Value(bills),
      salesPaise: Value(salesPaise),
      taxablePaise: Value(taxablePaise),
      costPaise: Value(costPaise),
      taxPaise: Value(taxPaise),
      cashPaise: Value(cashPaise),
      upiPaise: Value(upiPaise),
      cardPaise: Value(cardPaise),
      creditPaise: Value(creditPaise),
      cancelledBills: Value(cancelledBills),
      cancelledPaise: Value(cancelledPaise),
    );
  }

  factory DbDayTotal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDayTotal(
      day: serializer.fromJson<String>(json['day']),
      bills: serializer.fromJson<int>(json['bills']),
      salesPaise: serializer.fromJson<int>(json['sales_paise']),
      taxablePaise: serializer.fromJson<int>(json['taxable_paise']),
      costPaise: serializer.fromJson<int>(json['cost_paise']),
      taxPaise: serializer.fromJson<int>(json['tax_paise']),
      cashPaise: serializer.fromJson<int>(json['cash_paise']),
      upiPaise: serializer.fromJson<int>(json['upi_paise']),
      cardPaise: serializer.fromJson<int>(json['card_paise']),
      creditPaise: serializer.fromJson<int>(json['credit_paise']),
      cancelledBills: serializer.fromJson<int>(json['cancelled_bills']),
      cancelledPaise: serializer.fromJson<int>(json['cancelled_paise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'bills': serializer.toJson<int>(bills),
      'sales_paise': serializer.toJson<int>(salesPaise),
      'taxable_paise': serializer.toJson<int>(taxablePaise),
      'cost_paise': serializer.toJson<int>(costPaise),
      'tax_paise': serializer.toJson<int>(taxPaise),
      'cash_paise': serializer.toJson<int>(cashPaise),
      'upi_paise': serializer.toJson<int>(upiPaise),
      'card_paise': serializer.toJson<int>(cardPaise),
      'credit_paise': serializer.toJson<int>(creditPaise),
      'cancelled_bills': serializer.toJson<int>(cancelledBills),
      'cancelled_paise': serializer.toJson<int>(cancelledPaise),
    };
  }

  DbDayTotal copyWith({
    String? day,
    int? bills,
    int? salesPaise,
    int? taxablePaise,
    int? costPaise,
    int? taxPaise,
    int? cashPaise,
    int? upiPaise,
    int? cardPaise,
    int? creditPaise,
    int? cancelledBills,
    int? cancelledPaise,
  }) => DbDayTotal(
    day: day ?? this.day,
    bills: bills ?? this.bills,
    salesPaise: salesPaise ?? this.salesPaise,
    taxablePaise: taxablePaise ?? this.taxablePaise,
    costPaise: costPaise ?? this.costPaise,
    taxPaise: taxPaise ?? this.taxPaise,
    cashPaise: cashPaise ?? this.cashPaise,
    upiPaise: upiPaise ?? this.upiPaise,
    cardPaise: cardPaise ?? this.cardPaise,
    creditPaise: creditPaise ?? this.creditPaise,
    cancelledBills: cancelledBills ?? this.cancelledBills,
    cancelledPaise: cancelledPaise ?? this.cancelledPaise,
  );
  DbDayTotal copyWithCompanion(DayTotalsCompanion data) {
    return DbDayTotal(
      day: data.day.present ? data.day.value : this.day,
      bills: data.bills.present ? data.bills.value : this.bills,
      salesPaise: data.salesPaise.present
          ? data.salesPaise.value
          : this.salesPaise,
      taxablePaise: data.taxablePaise.present
          ? data.taxablePaise.value
          : this.taxablePaise,
      costPaise: data.costPaise.present ? data.costPaise.value : this.costPaise,
      taxPaise: data.taxPaise.present ? data.taxPaise.value : this.taxPaise,
      cashPaise: data.cashPaise.present ? data.cashPaise.value : this.cashPaise,
      upiPaise: data.upiPaise.present ? data.upiPaise.value : this.upiPaise,
      cardPaise: data.cardPaise.present ? data.cardPaise.value : this.cardPaise,
      creditPaise: data.creditPaise.present
          ? data.creditPaise.value
          : this.creditPaise,
      cancelledBills: data.cancelledBills.present
          ? data.cancelledBills.value
          : this.cancelledBills,
      cancelledPaise: data.cancelledPaise.present
          ? data.cancelledPaise.value
          : this.cancelledPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDayTotal(')
          ..write('day: $day, ')
          ..write('bills: $bills, ')
          ..write('salesPaise: $salesPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('cashPaise: $cashPaise, ')
          ..write('upiPaise: $upiPaise, ')
          ..write('cardPaise: $cardPaise, ')
          ..write('creditPaise: $creditPaise, ')
          ..write('cancelledBills: $cancelledBills, ')
          ..write('cancelledPaise: $cancelledPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    day,
    bills,
    salesPaise,
    taxablePaise,
    costPaise,
    taxPaise,
    cashPaise,
    upiPaise,
    cardPaise,
    creditPaise,
    cancelledBills,
    cancelledPaise,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDayTotal &&
          other.day == this.day &&
          other.bills == this.bills &&
          other.salesPaise == this.salesPaise &&
          other.taxablePaise == this.taxablePaise &&
          other.costPaise == this.costPaise &&
          other.taxPaise == this.taxPaise &&
          other.cashPaise == this.cashPaise &&
          other.upiPaise == this.upiPaise &&
          other.cardPaise == this.cardPaise &&
          other.creditPaise == this.creditPaise &&
          other.cancelledBills == this.cancelledBills &&
          other.cancelledPaise == this.cancelledPaise);
}

class DayTotalsCompanion extends UpdateCompanion<DbDayTotal> {
  final Value<String> day;
  final Value<int> bills;
  final Value<int> salesPaise;
  final Value<int> taxablePaise;
  final Value<int> costPaise;
  final Value<int> taxPaise;
  final Value<int> cashPaise;
  final Value<int> upiPaise;
  final Value<int> cardPaise;
  final Value<int> creditPaise;
  final Value<int> cancelledBills;
  final Value<int> cancelledPaise;
  final Value<int> rowid;
  const DayTotalsCompanion({
    this.day = const Value.absent(),
    this.bills = const Value.absent(),
    this.salesPaise = const Value.absent(),
    this.taxablePaise = const Value.absent(),
    this.costPaise = const Value.absent(),
    this.taxPaise = const Value.absent(),
    this.cashPaise = const Value.absent(),
    this.upiPaise = const Value.absent(),
    this.cardPaise = const Value.absent(),
    this.creditPaise = const Value.absent(),
    this.cancelledBills = const Value.absent(),
    this.cancelledPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayTotalsCompanion.insert({
    required String day,
    this.bills = const Value.absent(),
    this.salesPaise = const Value.absent(),
    this.taxablePaise = const Value.absent(),
    this.costPaise = const Value.absent(),
    this.taxPaise = const Value.absent(),
    this.cashPaise = const Value.absent(),
    this.upiPaise = const Value.absent(),
    this.cardPaise = const Value.absent(),
    this.creditPaise = const Value.absent(),
    this.cancelledBills = const Value.absent(),
    this.cancelledPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<DbDayTotal> custom({
    Expression<String>? day,
    Expression<int>? bills,
    Expression<int>? salesPaise,
    Expression<int>? taxablePaise,
    Expression<int>? costPaise,
    Expression<int>? taxPaise,
    Expression<int>? cashPaise,
    Expression<int>? upiPaise,
    Expression<int>? cardPaise,
    Expression<int>? creditPaise,
    Expression<int>? cancelledBills,
    Expression<int>? cancelledPaise,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (bills != null) 'bills': bills,
      if (salesPaise != null) 'sales_paise': salesPaise,
      if (taxablePaise != null) 'taxable_paise': taxablePaise,
      if (costPaise != null) 'cost_paise': costPaise,
      if (taxPaise != null) 'tax_paise': taxPaise,
      if (cashPaise != null) 'cash_paise': cashPaise,
      if (upiPaise != null) 'upi_paise': upiPaise,
      if (cardPaise != null) 'card_paise': cardPaise,
      if (creditPaise != null) 'credit_paise': creditPaise,
      if (cancelledBills != null) 'cancelled_bills': cancelledBills,
      if (cancelledPaise != null) 'cancelled_paise': cancelledPaise,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayTotalsCompanion copyWith({
    Value<String>? day,
    Value<int>? bills,
    Value<int>? salesPaise,
    Value<int>? taxablePaise,
    Value<int>? costPaise,
    Value<int>? taxPaise,
    Value<int>? cashPaise,
    Value<int>? upiPaise,
    Value<int>? cardPaise,
    Value<int>? creditPaise,
    Value<int>? cancelledBills,
    Value<int>? cancelledPaise,
    Value<int>? rowid,
  }) {
    return DayTotalsCompanion(
      day: day ?? this.day,
      bills: bills ?? this.bills,
      salesPaise: salesPaise ?? this.salesPaise,
      taxablePaise: taxablePaise ?? this.taxablePaise,
      costPaise: costPaise ?? this.costPaise,
      taxPaise: taxPaise ?? this.taxPaise,
      cashPaise: cashPaise ?? this.cashPaise,
      upiPaise: upiPaise ?? this.upiPaise,
      cardPaise: cardPaise ?? this.cardPaise,
      creditPaise: creditPaise ?? this.creditPaise,
      cancelledBills: cancelledBills ?? this.cancelledBills,
      cancelledPaise: cancelledPaise ?? this.cancelledPaise,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (bills.present) {
      map['bills'] = Variable<int>(bills.value);
    }
    if (salesPaise.present) {
      map['sales_paise'] = Variable<int>(salesPaise.value);
    }
    if (taxablePaise.present) {
      map['taxable_paise'] = Variable<int>(taxablePaise.value);
    }
    if (costPaise.present) {
      map['cost_paise'] = Variable<int>(costPaise.value);
    }
    if (taxPaise.present) {
      map['tax_paise'] = Variable<int>(taxPaise.value);
    }
    if (cashPaise.present) {
      map['cash_paise'] = Variable<int>(cashPaise.value);
    }
    if (upiPaise.present) {
      map['upi_paise'] = Variable<int>(upiPaise.value);
    }
    if (cardPaise.present) {
      map['card_paise'] = Variable<int>(cardPaise.value);
    }
    if (creditPaise.present) {
      map['credit_paise'] = Variable<int>(creditPaise.value);
    }
    if (cancelledBills.present) {
      map['cancelled_bills'] = Variable<int>(cancelledBills.value);
    }
    if (cancelledPaise.present) {
      map['cancelled_paise'] = Variable<int>(cancelledPaise.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayTotalsCompanion(')
          ..write('day: $day, ')
          ..write('bills: $bills, ')
          ..write('salesPaise: $salesPaise, ')
          ..write('taxablePaise: $taxablePaise, ')
          ..write('costPaise: $costPaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('cashPaise: $cashPaise, ')
          ..write('upiPaise: $upiPaise, ')
          ..write('cardPaise: $cardPaise, ')
          ..write('creditPaise: $creditPaise, ')
          ..write('cancelledBills: $cancelledBills, ')
          ..write('cancelledPaise: $cancelledPaise, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProductMonth extends Table with TableInfo<ProductMonth, DbProductMonth> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProductMonth(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _qtyMilliMeta = const VerificationMeta(
    'qtyMilli',
  );
  late final GeneratedColumn<int> qtyMilli = GeneratedColumn<int>(
    'qty_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    productId,
    month,
    qtyMilli,
    amountPaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_month';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbProductMonth> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('qty_milli')) {
      context.handle(
        _qtyMilliMeta,
        qtyMilli.isAcceptableOrUnknown(data['qty_milli']!, _qtyMilliMeta),
      );
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId, month};
  @override
  DbProductMonth map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbProductMonth(
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      qtyMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_milli'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
    );
  }

  @override
  ProductMonth createAlias(String alias) {
    return ProductMonth(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(product_id, month)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class DbProductMonth extends DataClass implements Insertable<DbProductMonth> {
  final String productId;
  final String month;
  final int qtyMilli;
  final int amountPaise;
  const DbProductMonth({
    required this.productId,
    required this.month,
    required this.qtyMilli,
    required this.amountPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['month'] = Variable<String>(month);
    map['qty_milli'] = Variable<int>(qtyMilli);
    map['amount_paise'] = Variable<int>(amountPaise);
    return map;
  }

  ProductMonthCompanion toCompanion(bool nullToAbsent) {
    return ProductMonthCompanion(
      productId: Value(productId),
      month: Value(month),
      qtyMilli: Value(qtyMilli),
      amountPaise: Value(amountPaise),
    );
  }

  factory DbProductMonth.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbProductMonth(
      productId: serializer.fromJson<String>(json['product_id']),
      month: serializer.fromJson<String>(json['month']),
      qtyMilli: serializer.fromJson<int>(json['qty_milli']),
      amountPaise: serializer.fromJson<int>(json['amount_paise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'product_id': serializer.toJson<String>(productId),
      'month': serializer.toJson<String>(month),
      'qty_milli': serializer.toJson<int>(qtyMilli),
      'amount_paise': serializer.toJson<int>(amountPaise),
    };
  }

  DbProductMonth copyWith({
    String? productId,
    String? month,
    int? qtyMilli,
    int? amountPaise,
  }) => DbProductMonth(
    productId: productId ?? this.productId,
    month: month ?? this.month,
    qtyMilli: qtyMilli ?? this.qtyMilli,
    amountPaise: amountPaise ?? this.amountPaise,
  );
  DbProductMonth copyWithCompanion(ProductMonthCompanion data) {
    return DbProductMonth(
      productId: data.productId.present ? data.productId.value : this.productId,
      month: data.month.present ? data.month.value : this.month,
      qtyMilli: data.qtyMilli.present ? data.qtyMilli.value : this.qtyMilli,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbProductMonth(')
          ..write('productId: $productId, ')
          ..write('month: $month, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(productId, month, qtyMilli, amountPaise);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbProductMonth &&
          other.productId == this.productId &&
          other.month == this.month &&
          other.qtyMilli == this.qtyMilli &&
          other.amountPaise == this.amountPaise);
}

class ProductMonthCompanion extends UpdateCompanion<DbProductMonth> {
  final Value<String> productId;
  final Value<String> month;
  final Value<int> qtyMilli;
  final Value<int> amountPaise;
  final Value<int> rowid;
  const ProductMonthCompanion({
    this.productId = const Value.absent(),
    this.month = const Value.absent(),
    this.qtyMilli = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductMonthCompanion.insert({
    required String productId,
    required String month,
    this.qtyMilli = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : productId = Value(productId),
       month = Value(month);
  static Insertable<DbProductMonth> custom({
    Expression<String>? productId,
    Expression<String>? month,
    Expression<int>? qtyMilli,
    Expression<int>? amountPaise,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (month != null) 'month': month,
      if (qtyMilli != null) 'qty_milli': qtyMilli,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductMonthCompanion copyWith({
    Value<String>? productId,
    Value<String>? month,
    Value<int>? qtyMilli,
    Value<int>? amountPaise,
    Value<int>? rowid,
  }) {
    return ProductMonthCompanion(
      productId: productId ?? this.productId,
      month: month ?? this.month,
      qtyMilli: qtyMilli ?? this.qtyMilli,
      amountPaise: amountPaise ?? this.amountPaise,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (qtyMilli.present) {
      map['qty_milli'] = Variable<int>(qtyMilli.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductMonthCompanion(')
          ..write('productId: $productId, ')
          ..write('month: $month, ')
          ..write('qtyMilli: $qtyMilli, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Counters extends Table with TableInfo<Counters, DbCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Counters(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [name, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  DbCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCounter(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  Counters createAlias(String alias) {
    return Counters(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbCounter extends DataClass implements Insertable<DbCounter> {
  final String name;
  final int value;
  const DbCounter({required this.name, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<int>(value);
    return map;
  }

  CountersCompanion toCompanion(bool nullToAbsent) {
    return CountersCompanion(name: Value(name), value: Value(value));
  }

  factory DbCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCounter(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<int>(value),
    };
  }

  DbCounter copyWith({String? name, int? value}) =>
      DbCounter(name: name ?? this.name, value: value ?? this.value);
  DbCounter copyWithCompanion(CountersCompanion data) {
    return DbCounter(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCounter(')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCounter &&
          other.name == this.name &&
          other.value == this.value);
}

class CountersCompanion extends UpdateCompanion<DbCounter> {
  final Value<String> name;
  final Value<int> value;
  final Value<int> rowid;
  const CountersCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountersCompanion.insert({
    required String name,
    required int value,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value);
  static Insertable<DbCounter> custom({
    Expression<String>? name,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountersCompanion copyWith({
    Value<String>? name,
    Value<int>? value,
    Value<int>? rowid,
  }) {
    return CountersCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountersCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Reminders extends Table with TableInfo<Reminders, DbReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Reminders(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES customers(id)',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _amountDuePaiseMeta = const VerificationMeta(
    'amountDuePaise',
  );
  late final GeneratedColumn<int> amountDuePaise = GeneratedColumn<int>(
    'amount_due_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _byNameMeta = const VerificationMeta('byName');
  late final GeneratedColumn<String> byName = GeneratedColumn<String>(
    'by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    at,
    amountDuePaise,
    message,
    byName,
    createdAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('amount_due_paise')) {
      context.handle(
        _amountDuePaiseMeta,
        amountDuePaise.isAcceptableOrUnknown(
          data['amount_due_paise']!,
          _amountDuePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountDuePaiseMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('by_name')) {
      context.handle(
        _byNameMeta,
        byName.isAcceptableOrUnknown(data['by_name']!, _byNameMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      amountDuePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_due_paise'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      byName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  Reminders createAlias(String alias) {
    return Reminders(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbReminder extends DataClass implements Insertable<DbReminder> {
  final String id;
  final String customerId;
  final int at;
  final int amountDuePaise;
  final String message;
  final String byName;
  final int createdAt;
  final String deviceId;
  const DbReminder({
    required this.id,
    required this.customerId,
    required this.at,
    required this.amountDuePaise,
    required this.message,
    required this.byName,
    required this.createdAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['at'] = Variable<int>(at);
    map['amount_due_paise'] = Variable<int>(amountDuePaise);
    map['message'] = Variable<String>(message);
    map['by_name'] = Variable<String>(byName);
    map['created_at'] = Variable<int>(createdAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      customerId: Value(customerId),
      at: Value(at),
      amountDuePaise: Value(amountDuePaise),
      message: Value(message),
      byName: Value(byName),
      createdAt: Value(createdAt),
      deviceId: Value(deviceId),
    );
  }

  factory DbReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbReminder(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customer_id']),
      at: serializer.fromJson<int>(json['at']),
      amountDuePaise: serializer.fromJson<int>(json['amount_due_paise']),
      message: serializer.fromJson<String>(json['message']),
      byName: serializer.fromJson<String>(json['by_name']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customer_id': serializer.toJson<String>(customerId),
      'at': serializer.toJson<int>(at),
      'amount_due_paise': serializer.toJson<int>(amountDuePaise),
      'message': serializer.toJson<String>(message),
      'by_name': serializer.toJson<String>(byName),
      'created_at': serializer.toJson<int>(createdAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbReminder copyWith({
    String? id,
    String? customerId,
    int? at,
    int? amountDuePaise,
    String? message,
    String? byName,
    int? createdAt,
    String? deviceId,
  }) => DbReminder(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    at: at ?? this.at,
    amountDuePaise: amountDuePaise ?? this.amountDuePaise,
    message: message ?? this.message,
    byName: byName ?? this.byName,
    createdAt: createdAt ?? this.createdAt,
    deviceId: deviceId ?? this.deviceId,
  );
  DbReminder copyWithCompanion(RemindersCompanion data) {
    return DbReminder(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      at: data.at.present ? data.at.value : this.at,
      amountDuePaise: data.amountDuePaise.present
          ? data.amountDuePaise.value
          : this.amountDuePaise,
      message: data.message.present ? data.message.value : this.message,
      byName: data.byName.present ? data.byName.value : this.byName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbReminder(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('at: $at, ')
          ..write('amountDuePaise: $amountDuePaise, ')
          ..write('message: $message, ')
          ..write('byName: $byName, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    at,
    amountDuePaise,
    message,
    byName,
    createdAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbReminder &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.at == this.at &&
          other.amountDuePaise == this.amountDuePaise &&
          other.message == this.message &&
          other.byName == this.byName &&
          other.createdAt == this.createdAt &&
          other.deviceId == this.deviceId);
}

class RemindersCompanion extends UpdateCompanion<DbReminder> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<int> at;
  final Value<int> amountDuePaise;
  final Value<String> message;
  final Value<String> byName;
  final Value<int> createdAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.at = const Value.absent(),
    this.amountDuePaise = const Value.absent(),
    this.message = const Value.absent(),
    this.byName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String customerId,
    required int at,
    required int amountDuePaise,
    required String message,
    this.byName = const Value.absent(),
    required int createdAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       at = Value(at),
       amountDuePaise = Value(amountDuePaise),
       message = Value(message),
       createdAt = Value(createdAt),
       deviceId = Value(deviceId);
  static Insertable<DbReminder> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<int>? at,
    Expression<int>? amountDuePaise,
    Expression<String>? message,
    Expression<String>? byName,
    Expression<int>? createdAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (at != null) 'at': at,
      if (amountDuePaise != null) 'amount_due_paise': amountDuePaise,
      if (message != null) 'message': message,
      if (byName != null) 'by_name': byName,
      if (createdAt != null) 'created_at': createdAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<int>? at,
    Value<int>? amountDuePaise,
    Value<String>? message,
    Value<String>? byName,
    Value<int>? createdAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      at: at ?? this.at,
      amountDuePaise: amountDuePaise ?? this.amountDuePaise,
      message: message ?? this.message,
      byName: byName ?? this.byName,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (amountDuePaise.present) {
      map['amount_due_paise'] = Variable<int>(amountDuePaise.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (byName.present) {
      map['by_name'] = Variable<String>(byName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('at: $at, ')
          ..write('amountDuePaise: $amountDuePaise, ')
          ..write('message: $message, ')
          ..write('byName: $byName, ')
          ..write('createdAt: $createdAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Records extends Table with TableInfo<Records, DbRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Records(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    data,
    at,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
    );
  }

  @override
  Records createAlias(String alias) {
    return Records(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbRecord extends DataClass implements Insertable<DbRecord> {
  final String id;
  final String kind;
  final String data;
  final int at;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final int version;
  final String hlc;
  const DbRecord({
    required this.id,
    required this.kind,
    required this.data,
    required this.at,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.version,
    required this.hlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['data'] = Variable<String>(data);
    map['at'] = Variable<int>(at);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      data: Value(data),
      at: Value(at),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      hlc: Value(hlc),
    );
  }

  factory DbRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbRecord(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      data: serializer.fromJson<String>(json['data']),
      at: serializer.fromJson<int>(json['at']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      version: serializer.fromJson<int>(json['version']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'data': serializer.toJson<String>(data),
      'at': serializer.toJson<int>(at),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  DbRecord copyWith({
    String? id,
    String? kind,
    String? data,
    int? at,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    int? version,
    String? hlc,
  }) => DbRecord(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    data: data ?? this.data,
    at: at ?? this.at,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    hlc: hlc ?? this.hlc,
  );
  DbRecord copyWithCompanion(RecordsCompanion data) {
    return DbRecord(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      data: data.data.present ? data.data.value : this.data,
      at: data.at.present ? data.at.value : this.at,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbRecord(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('data: $data, ')
          ..write('at: $at, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    data,
    at,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    version,
    hlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbRecord &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.data == this.data &&
          other.at == this.at &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.hlc == this.hlc);
}

class RecordsCompanion extends UpdateCompanion<DbRecord> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> data;
  final Value<int> at;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<String> hlc;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.data = const Value.absent(),
    this.at = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required String kind,
    required String data,
    required int at,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       data = Value(data),
       at = Value(at),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<DbRecord> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? data,
    Expression<int>? at,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (data != null) 'data': data,
      if (at != null) 'at': at,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? data,
    Value<int>? at,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      data: data ?? this.data,
      at: at ?? this.at,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('data: $data, ')
          ..write('at: $at, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Outbox extends Table with TableInfo<Outbox, DbOutbox> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _collMeta = const VerificationMeta('coll');
  late final GeneratedColumn<String> coll = GeneratedColumn<String>(
    'coll',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _docIdMeta = const VerificationMeta('docId');
  late final GeneratedColumn<String> docId = GeneratedColumn<String>(
    'doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'set\'',
    defaultValue: const CustomExpression('\'set\''),
  );
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  late final GeneratedColumn<String> stamp = GeneratedColumn<String>(
    'stamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pending\'',
    defaultValue: const CustomExpression('\'pending\''),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _holdUntilMeta = const VerificationMeta(
    'holdUntil',
  );
  late final GeneratedColumn<int> holdUntil = GeneratedColumn<int>(
    'hold_until',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    coll,
    docId,
    op,
    stamp,
    state,
    attempts,
    lastError,
    holdUntil,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbOutbox> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('coll')) {
      context.handle(
        _collMeta,
        coll.isAcceptableOrUnknown(data['coll']!, _collMeta),
      );
    } else if (isInserting) {
      context.missing(_collMeta);
    }
    if (data.containsKey('doc_id')) {
      context.handle(
        _docIdMeta,
        docId.isAcceptableOrUnknown(data['doc_id']!, _docIdMeta),
      );
    } else if (isInserting) {
      context.missing(_docIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    }
    if (data.containsKey('stamp')) {
      context.handle(
        _stampMeta,
        stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('hold_until')) {
      context.handle(
        _holdUntilMeta,
        holdUntil.isAcceptableOrUnknown(data['hold_until']!, _holdUntilMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  DbOutbox map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbOutbox(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      coll: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coll'],
      )!,
      docId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      stamp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stamp'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      holdUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hold_until'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbOutbox extends DataClass implements Insertable<DbOutbox> {
  final int seq;
  final String coll;
  final String docId;
  final String op;
  final String stamp;
  final String state;
  final int attempts;
  final String? lastError;
  final int holdUntil;
  final int createdAt;
  const DbOutbox({
    required this.seq,
    required this.coll,
    required this.docId,
    required this.op,
    required this.stamp,
    required this.state,
    required this.attempts,
    this.lastError,
    required this.holdUntil,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['coll'] = Variable<String>(coll);
    map['doc_id'] = Variable<String>(docId);
    map['op'] = Variable<String>(op);
    map['stamp'] = Variable<String>(stamp);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['hold_until'] = Variable<int>(holdUntil);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      coll: Value(coll),
      docId: Value(docId),
      op: Value(op),
      stamp: Value(stamp),
      state: Value(state),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      holdUntil: Value(holdUntil),
      createdAt: Value(createdAt),
    );
  }

  factory DbOutbox.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbOutbox(
      seq: serializer.fromJson<int>(json['seq']),
      coll: serializer.fromJson<String>(json['coll']),
      docId: serializer.fromJson<String>(json['doc_id']),
      op: serializer.fromJson<String>(json['op']),
      stamp: serializer.fromJson<String>(json['stamp']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['last_error']),
      holdUntil: serializer.fromJson<int>(json['hold_until']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'coll': serializer.toJson<String>(coll),
      'doc_id': serializer.toJson<String>(docId),
      'op': serializer.toJson<String>(op),
      'stamp': serializer.toJson<String>(stamp),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'last_error': serializer.toJson<String?>(lastError),
      'hold_until': serializer.toJson<int>(holdUntil),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  DbOutbox copyWith({
    int? seq,
    String? coll,
    String? docId,
    String? op,
    String? stamp,
    String? state,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    int? holdUntil,
    int? createdAt,
  }) => DbOutbox(
    seq: seq ?? this.seq,
    coll: coll ?? this.coll,
    docId: docId ?? this.docId,
    op: op ?? this.op,
    stamp: stamp ?? this.stamp,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    holdUntil: holdUntil ?? this.holdUntil,
    createdAt: createdAt ?? this.createdAt,
  );
  DbOutbox copyWithCompanion(OutboxCompanion data) {
    return DbOutbox(
      seq: data.seq.present ? data.seq.value : this.seq,
      coll: data.coll.present ? data.coll.value : this.coll,
      docId: data.docId.present ? data.docId.value : this.docId,
      op: data.op.present ? data.op.value : this.op,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      holdUntil: data.holdUntil.present ? data.holdUntil.value : this.holdUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbOutbox(')
          ..write('seq: $seq, ')
          ..write('coll: $coll, ')
          ..write('docId: $docId, ')
          ..write('op: $op, ')
          ..write('stamp: $stamp, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('holdUntil: $holdUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    coll,
    docId,
    op,
    stamp,
    state,
    attempts,
    lastError,
    holdUntil,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbOutbox &&
          other.seq == this.seq &&
          other.coll == this.coll &&
          other.docId == this.docId &&
          other.op == this.op &&
          other.stamp == this.stamp &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.holdUntil == this.holdUntil &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<DbOutbox> {
  final Value<int> seq;
  final Value<String> coll;
  final Value<String> docId;
  final Value<String> op;
  final Value<String> stamp;
  final Value<String> state;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> holdUntil;
  final Value<int> createdAt;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.coll = const Value.absent(),
    this.docId = const Value.absent(),
    this.op = const Value.absent(),
    this.stamp = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.holdUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String coll,
    required String docId,
    this.op = const Value.absent(),
    this.stamp = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.holdUntil = const Value.absent(),
    required int createdAt,
  }) : coll = Value(coll),
       docId = Value(docId),
       createdAt = Value(createdAt);
  static Insertable<DbOutbox> custom({
    Expression<int>? seq,
    Expression<String>? coll,
    Expression<String>? docId,
    Expression<String>? op,
    Expression<String>? stamp,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? holdUntil,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (coll != null) 'coll': coll,
      if (docId != null) 'doc_id': docId,
      if (op != null) 'op': op,
      if (stamp != null) 'stamp': stamp,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (holdUntil != null) 'hold_until': holdUntil,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? coll,
    Value<String>? docId,
    Value<String>? op,
    Value<String>? stamp,
    Value<String>? state,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<int>? holdUntil,
    Value<int>? createdAt,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      coll: coll ?? this.coll,
      docId: docId ?? this.docId,
      op: op ?? this.op,
      stamp: stamp ?? this.stamp,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      holdUntil: holdUntil ?? this.holdUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (coll.present) {
      map['coll'] = Variable<String>(coll.value);
    }
    if (docId.present) {
      map['doc_id'] = Variable<String>(docId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<String>(stamp.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (holdUntil.present) {
      map['hold_until'] = Variable<int>(holdUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('coll: $coll, ')
          ..write('docId: $docId, ')
          ..write('op: $op, ')
          ..write('stamp: $stamp, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('holdUntil: $holdUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class SyncMeta extends Table with TableInfo<SyncMeta, DbSyncMeta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncMeta(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [name, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSyncMeta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  DbSyncMeta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSyncMeta(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  SyncMeta createAlias(String alias) {
    return SyncMeta(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbSyncMeta extends DataClass implements Insertable<DbSyncMeta> {
  final String name;
  final String value;
  const DbSyncMeta({required this.name, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(name: Value(name), value: Value(value));
  }

  factory DbSyncMeta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSyncMeta(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
    };
  }

  DbSyncMeta copyWith({String? name, String? value}) =>
      DbSyncMeta(name: name ?? this.name, value: value ?? this.value);
  DbSyncMeta copyWithCompanion(SyncMetaCompanion data) {
    return DbSyncMeta(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSyncMeta(')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSyncMeta &&
          other.name == this.name &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<DbSyncMeta> {
  final Value<String> name;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String name,
    required String value,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value);
  static Insertable<DbSyncMeta> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? name,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Audit extends Table with TableInfo<Audit, DbAudit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Audit(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _whatMeta = const VerificationMeta('what');
  late final GeneratedColumn<String> what = GeneratedColumn<String>(
    'what',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _byNameMeta = const VerificationMeta('byName');
  late final GeneratedColumn<String> byName = GeneratedColumn<String>(
    'by_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    what,
    entity,
    entityId,
    field,
    oldValue,
    newValue,
    byName,
    at,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAudit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('what')) {
      context.handle(
        _whatMeta,
        what.isAcceptableOrUnknown(data['what']!, _whatMeta),
      );
    } else if (isInserting) {
      context.missing(_whatMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('by_name')) {
      context.handle(
        _byNameMeta,
        byName.isAcceptableOrUnknown(data['by_name']!, _byNameMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAudit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAudit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      what: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}what'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      byName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_name'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  Audit createAlias(String alias) {
    return Audit(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DbAudit extends DataClass implements Insertable<DbAudit> {
  final String id;
  final String what;
  final String entity;
  final String entityId;
  final String field;
  final String? oldValue;
  final String? newValue;
  final String byName;
  final int at;
  final String deviceId;
  const DbAudit({
    required this.id,
    required this.what,
    required this.entity,
    required this.entityId,
    required this.field,
    this.oldValue,
    this.newValue,
    required this.byName,
    required this.at,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['what'] = Variable<String>(what);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['field'] = Variable<String>(field);
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<String>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<String>(newValue);
    }
    map['by_name'] = Variable<String>(byName);
    map['at'] = Variable<int>(at);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  AuditCompanion toCompanion(bool nullToAbsent) {
    return AuditCompanion(
      id: Value(id),
      what: Value(what),
      entity: Value(entity),
      entityId: Value(entityId),
      field: Value(field),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
      byName: Value(byName),
      at: Value(at),
      deviceId: Value(deviceId),
    );
  }

  factory DbAudit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAudit(
      id: serializer.fromJson<String>(json['id']),
      what: serializer.fromJson<String>(json['what']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      field: serializer.fromJson<String>(json['field']),
      oldValue: serializer.fromJson<String?>(json['old_value']),
      newValue: serializer.fromJson<String?>(json['new_value']),
      byName: serializer.fromJson<String>(json['by_name']),
      at: serializer.fromJson<int>(json['at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'what': serializer.toJson<String>(what),
      'entity': serializer.toJson<String>(entity),
      'entity_id': serializer.toJson<String>(entityId),
      'field': serializer.toJson<String>(field),
      'old_value': serializer.toJson<String?>(oldValue),
      'new_value': serializer.toJson<String?>(newValue),
      'by_name': serializer.toJson<String>(byName),
      'at': serializer.toJson<int>(at),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  DbAudit copyWith({
    String? id,
    String? what,
    String? entity,
    String? entityId,
    String? field,
    Value<String?> oldValue = const Value.absent(),
    Value<String?> newValue = const Value.absent(),
    String? byName,
    int? at,
    String? deviceId,
  }) => DbAudit(
    id: id ?? this.id,
    what: what ?? this.what,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    field: field ?? this.field,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
    byName: byName ?? this.byName,
    at: at ?? this.at,
    deviceId: deviceId ?? this.deviceId,
  );
  DbAudit copyWithCompanion(AuditCompanion data) {
    return DbAudit(
      id: data.id.present ? data.id.value : this.id,
      what: data.what.present ? data.what.value : this.what,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      field: data.field.present ? data.field.value : this.field,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      byName: data.byName.present ? data.byName.value : this.byName,
      at: data.at.present ? data.at.value : this.at,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAudit(')
          ..write('id: $id, ')
          ..write('what: $what, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('byName: $byName, ')
          ..write('at: $at, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    what,
    entity,
    entityId,
    field,
    oldValue,
    newValue,
    byName,
    at,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAudit &&
          other.id == this.id &&
          other.what == this.what &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.field == this.field &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.byName == this.byName &&
          other.at == this.at &&
          other.deviceId == this.deviceId);
}

class AuditCompanion extends UpdateCompanion<DbAudit> {
  final Value<String> id;
  final Value<String> what;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> field;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<String> byName;
  final Value<int> at;
  final Value<String> deviceId;
  final Value<int> rowid;
  const AuditCompanion({
    this.id = const Value.absent(),
    this.what = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.field = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.byName = const Value.absent(),
    this.at = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditCompanion.insert({
    required String id,
    required String what,
    required String entity,
    required String entityId,
    required String field,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.byName = const Value.absent(),
    required int at,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       what = Value(what),
       entity = Value(entity),
       entityId = Value(entityId),
       field = Value(field),
       at = Value(at),
       deviceId = Value(deviceId);
  static Insertable<DbAudit> custom({
    Expression<String>? id,
    Expression<String>? what,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? field,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<String>? byName,
    Expression<int>? at,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (what != null) 'what': what,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (field != null) 'field': field,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (byName != null) 'by_name': byName,
      if (at != null) 'at': at,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditCompanion copyWith({
    Value<String>? id,
    Value<String>? what,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? field,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<String>? byName,
    Value<int>? at,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return AuditCompanion(
      id: id ?? this.id,
      what: what ?? this.what,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      field: field ?? this.field,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      byName: byName ?? this.byName,
      at: at ?? this.at,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (what.present) {
      map['what'] = Variable<String>(what.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (byName.present) {
      map['by_name'] = Variable<String>(byName.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditCompanion(')
          ..write('id: $id, ')
          ..write('what: $what, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('byName: $byName, ')
          ..write('at: $at, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Kv kv = Kv(this);
  late final Categories categories = Categories(this);
  late final Index categoriesName = Index(
    'categories_name',
    'CREATE UNIQUE INDEX categories_name ON categories (name COLLATE NOCASE) WHERE deleted_at IS NULL',
  );
  late final Products products = Products(this);
  late final Index productsName = Index(
    'products_name',
    'CREATE INDEX products_name ON products (name COLLATE NOCASE)',
  );
  late final Index productsBarcode = Index(
    'products_barcode',
    'CREATE INDEX products_barcode ON products (barcode) WHERE barcode <> \'\'',
  );
  late final Index productsCategory = Index(
    'products_category',
    'CREATE INDEX products_category ON products (category)',
  );
  late final Index productsOldId = Index(
    'products_old_id',
    'CREATE UNIQUE INDEX products_old_id ON products (old_id) WHERE old_id IS NOT NULL',
  );
  late final ProductFts productFts = ProductFts(this);
  late final Trigger productsFtsAi = Trigger(
    'CREATE TRIGGER products_fts_ai AFTER INSERT ON products BEGIN INSERT INTO product_fts ("rowid", name, barcode) VALUES (new."rowid", new.name, new.barcode);END',
    'products_fts_ai',
  );
  late final Trigger productsFtsAd = Trigger(
    'CREATE TRIGGER products_fts_ad AFTER DELETE ON products BEGIN INSERT INTO product_fts (product_fts, "rowid", name, barcode) VALUES (\'delete\', old."rowid", old.name, old.barcode);END',
    'products_fts_ad',
  );
  late final Trigger productsFtsAu = Trigger(
    'CREATE TRIGGER products_fts_au AFTER UPDATE OF name, barcode ON products BEGIN INSERT INTO product_fts (product_fts, "rowid", name, barcode) VALUES (\'delete\', old."rowid", old.name, old.barcode);INSERT INTO product_fts ("rowid", name, barcode) VALUES (new."rowid", new.name, new.barcode);END',
    'products_fts_au',
  );
  late final Customers customers = Customers(this);
  late final Index customersName = Index(
    'customers_name',
    'CREATE INDEX customers_name ON customers (name COLLATE NOCASE)',
  );
  late final Index customersPhone = Index(
    'customers_phone',
    'CREATE INDEX customers_phone ON customers (phone) WHERE phone <> \'\'',
  );
  late final Index customersOldId = Index(
    'customers_old_id',
    'CREATE UNIQUE INDEX customers_old_id ON customers (old_id) WHERE old_id IS NOT NULL',
  );
  late final Dealers dealers = Dealers(this);
  late final Index dealersName = Index(
    'dealers_name',
    'CREATE INDEX dealers_name ON dealers (name COLLATE NOCASE)',
  );
  late final Index dealersOldId = Index(
    'dealers_old_id',
    'CREATE UNIQUE INDEX dealers_old_id ON dealers (old_id) WHERE old_id IS NOT NULL',
  );
  late final StockMovements stockMovements = StockMovements(this);
  late final Index stockMovementsProduct = Index(
    'stock_movements_product',
    'CREATE INDEX stock_movements_product ON stock_movements (product_id, at, qty_milli)',
  );
  late final Index stockMovementsRef = Index(
    'stock_movements_ref',
    'CREATE INDEX stock_movements_ref ON stock_movements (ref_id) WHERE ref_id IS NOT NULL',
  );
  late final StockCache stockCache = StockCache(this);
  late final Bills bills = Bills(this);
  late final Index billsNumber = Index(
    'bills_number',
    'CREATE UNIQUE INDEX bills_number ON bills (number)',
  );
  late final Index billsIdem = Index(
    'bills_idem',
    'CREATE UNIQUE INDEX bills_idem ON bills (idem_key)',
  );
  late final Index billsBilledAt = Index(
    'bills_billed_at',
    'CREATE INDEX bills_billed_at ON bills (billed_at DESC, id DESC)',
  );
  late final Index billsCustomer = Index(
    'bills_customer',
    'CREATE INDEX bills_customer ON bills (customer_id, billed_at DESC, id DESC) WHERE customer_id IS NOT NULL',
  );
  late final Index billsOldNo = Index(
    'bills_old_no',
    'CREATE INDEX bills_old_no ON bills (old_bill_no) WHERE old_bill_no IS NOT NULL',
  );
  late final Index billsAmount = Index(
    'bills_amount',
    'CREATE INDEX bills_amount ON bills (total_paise DESC, id DESC)',
  );
  late final Index billsSeq = Index(
    'bills_seq',
    'CREATE INDEX bills_seq ON bills (seq)',
  );
  late final Index billsOpen = Index(
    'bills_open',
    'CREATE INDEX bills_open ON bills (billed_at DESC, id DESC) WHERE balance_paise > 0 AND cancelled = 0',
  );
  late final Index billsCancelled = Index(
    'bills_cancelled',
    'CREATE INDEX bills_cancelled ON bills (billed_at DESC) WHERE cancelled = 1',
  );
  late final Index billsDue = Index(
    'bills_due',
    'CREATE INDEX bills_due ON bills (customer_id, billed_at) WHERE balance_paise > 0',
  );
  late final BillLines billLines = BillLines(this);
  late final Index billLinesBill = Index(
    'bill_lines_bill',
    'CREATE INDEX bill_lines_bill ON bill_lines (bill_id, line_no)',
  );
  late final Index billLinesProduct = Index(
    'bill_lines_product',
    'CREATE INDEX bill_lines_product ON bill_lines (product_id, bill_id)',
  );
  late final BillCancellations billCancellations = BillCancellations(this);
  late final Index billCancellationsBill = Index(
    'bill_cancellations_bill',
    'CREATE UNIQUE INDEX bill_cancellations_bill ON bill_cancellations (bill_id)',
  );
  late final Estimations estimations = Estimations(this);
  late final Index estimationsNumber = Index(
    'estimations_number',
    'CREATE UNIQUE INDEX estimations_number ON estimations (number)',
  );
  late final Index estimationsAt = Index(
    'estimations_at',
    'CREATE INDEX estimations_at ON estimations (at DESC, id DESC)',
  );
  late final EstimationLines estimationLines = EstimationLines(this);
  late final Index estimationLinesEst = Index(
    'estimation_lines_est',
    'CREATE INDEX estimation_lines_est ON estimation_lines (estimation_id, line_no)',
  );
  late final LedgerEntries ledgerEntries = LedgerEntries(this);
  late final Index ledgerParty = Index(
    'ledger_party',
    'CREATE INDEX ledger_party ON ledger_entries (party_id, at DESC, id DESC)',
  );
  late final Index ledgerBill = Index(
    'ledger_bill',
    'CREATE INDEX ledger_bill ON ledger_entries (party_id, bill_no) WHERE bill_no IS NOT NULL',
  );
  late final Index ledgerReverses = Index(
    'ledger_reverses',
    'CREATE INDEX ledger_reverses ON ledger_entries (reverses) WHERE reverses IS NOT NULL',
  );
  late final Payments payments = Payments(this);
  late final Index paymentsReceipt = Index(
    'payments_receipt',
    'CREATE UNIQUE INDEX payments_receipt ON payments (receipt_no)',
  );
  late final Index paymentsParty = Index(
    'payments_party',
    'CREATE INDEX payments_party ON payments (party_id, at DESC, id DESC)',
  );
  late final PartyBills partyBills = PartyBills(this);
  late final Index partyBillsKey = Index(
    'party_bills_key',
    'CREATE UNIQUE INDEX party_bills_key ON party_bills (party_id, bill_no)',
  );
  late final Index partyBillsOpen = Index(
    'party_bills_open',
    'CREATE INDEX party_bills_open ON party_bills (party_id, date) WHERE cancelled = 0 AND total_paise > paid_paise',
  );
  late final PartyBalance partyBalance = PartyBalance(this);
  late final Index partyBalanceOwed = Index(
    'party_balance_owed',
    'CREATE INDEX party_balance_owed ON party_balance (party_kind, balance_paise DESC)',
  );
  late final DayTotals dayTotals = DayTotals(this);
  late final ProductMonth productMonth = ProductMonth(this);
  late final Index productMonthByMonth = Index(
    'product_month_by_month',
    'CREATE INDEX product_month_by_month ON product_month (month, product_id, amount_paise)',
  );
  late final Counters counters = Counters(this);
  late final Reminders reminders = Reminders(this);
  late final Index remindersCustomer = Index(
    'reminders_customer',
    'CREATE INDEX reminders_customer ON reminders (customer_id, at DESC)',
  );
  late final Records records = Records(this);
  late final Index recordsKind = Index(
    'records_kind',
    'CREATE INDEX records_kind ON records (kind, at DESC, id DESC) WHERE deleted_at IS NULL',
  );
  late final Outbox outbox = Outbox(this);
  late final Index outboxDoc = Index(
    'outbox_doc',
    'CREATE UNIQUE INDEX outbox_doc ON outbox (coll, doc_id)',
  );
  late final Index outboxState = Index(
    'outbox_state',
    'CREATE INDEX outbox_state ON outbox (state, seq)',
  );
  late final SyncMeta syncMeta = SyncMeta(this);
  late final Audit audit = Audit(this);
  late final Index auditAt = Index(
    'audit_at',
    'CREATE INDEX audit_at ON audit (at DESC)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    kv,
    categories,
    categoriesName,
    products,
    productsName,
    productsBarcode,
    productsCategory,
    productsOldId,
    productFts,
    productsFtsAi,
    productsFtsAd,
    productsFtsAu,
    customers,
    customersName,
    customersPhone,
    customersOldId,
    dealers,
    dealersName,
    dealersOldId,
    stockMovements,
    stockMovementsProduct,
    stockMovementsRef,
    stockCache,
    bills,
    billsNumber,
    billsIdem,
    billsBilledAt,
    billsCustomer,
    billsOldNo,
    billsAmount,
    billsSeq,
    billsOpen,
    billsCancelled,
    billsDue,
    billLines,
    billLinesBill,
    billLinesProduct,
    billCancellations,
    billCancellationsBill,
    estimations,
    estimationsNumber,
    estimationsAt,
    estimationLines,
    estimationLinesEst,
    ledgerEntries,
    ledgerParty,
    ledgerBill,
    ledgerReverses,
    payments,
    paymentsReceipt,
    paymentsParty,
    partyBills,
    partyBillsKey,
    partyBillsOpen,
    partyBalance,
    partyBalanceOwed,
    dayTotals,
    productMonth,
    productMonthByMonth,
    counters,
    reminders,
    remindersCustomer,
    records,
    recordsKind,
    outbox,
    outboxDoc,
    outboxState,
    syncMeta,
    audit,
    auditAt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'products',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('product_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'products',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('product_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'products',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('product_fts', kind: UpdateKind.insert)],
    ),
  ]);
}

typedef $KvCreateCompanionBuilder = KvCompanion Function({
  required String name,
  required String value,
  required int updatedAt,
  Value<int> rowid,
});
typedef $KvUpdateCompanionBuilder = KvCompanion Function({
  Value<String> name,
  Value<String> value,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $KvFilterComposer extends Composer<_$AppDatabase, Kv> {
  $KvFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $KvOrderingComposer extends Composer<_$AppDatabase, Kv> {
  $KvOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $KvAnnotationComposer extends Composer<_$AppDatabase, Kv> {
  $KvAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $KvTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Kv,
          DbKv,
          $KvFilterComposer,
          $KvOrderingComposer,
          $KvAnnotationComposer,
          $KvCreateCompanionBuilder,
          $KvUpdateCompanionBuilder,
          (DbKv, BaseReferences<_$AppDatabase, Kv, DbKv>),
          DbKv,
          PrefetchHooks Function()
        > {
  $KvTableManager(_$AppDatabase db, Kv table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $KvFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $KvOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $KvAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion(
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => KvCompanion.insert(
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Kv, DbKv>(table),
                  BaseReferences<_$AppDatabase, Kv, DbKv>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $KvProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Kv,
      DbKv,
      $KvFilterComposer,
      $KvOrderingComposer,
      $KvAnnotationComposer,
      $KvCreateCompanionBuilder,
      $KvUpdateCompanionBuilder,
      (DbKv, BaseReferences<_$AppDatabase, Kv, DbKv>),
      DbKv,
      PrefetchHooks Function()
    >;
typedef $CategoriesCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $CategoriesUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

class $CategoriesFilterComposer extends Composer<_$AppDatabase, Categories> {
  $CategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $CategoriesOrderingComposer extends Composer<_$AppDatabase, Categories> {
  $CategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CategoriesAnnotationComposer
    extends Composer<_$AppDatabase, Categories> {
  $CategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $CategoriesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Categories,
          DbCategory,
          $CategoriesFilterComposer,
          $CategoriesOrderingComposer,
          $CategoriesAnnotationComposer,
          $CategoriesCreateCompanionBuilder,
          $CategoriesUpdateCompanionBuilder,
          (DbCategory, BaseReferences<_$AppDatabase, Categories, DbCategory>),
          DbCategory,
          PrefetchHooks Function()
        > {
  $CategoriesTableManager(_$AppDatabase db, Categories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CategoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CategoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Categories, DbCategory>(table),
                  BaseReferences<_$AppDatabase, Categories, DbCategory>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CategoriesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Categories,
      DbCategory,
      $CategoriesFilterComposer,
      $CategoriesOrderingComposer,
      $CategoriesAnnotationComposer,
      $CategoriesCreateCompanionBuilder,
      $CategoriesUpdateCompanionBuilder,
      (DbCategory, BaseReferences<_$AppDatabase, Categories, DbCategory>),
      DbCategory,
      PrefetchHooks Function()
    >;
typedef $ProductsCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String name,
  Value<String> category,
  Value<String> unit,
  required int pricePaise,
  Value<int> costPaise,
  Value<int> gstBp,
  Value<String> hsn,
  Value<String> barcode,
  Value<int> minStockMilli,
  Value<int> active,
  Value<String?> oldId,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $ProductsUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> category,
  Value<String> unit,
  Value<int> pricePaise,
  Value<int> costPaise,
  Value<int> gstBp,
  Value<String> hsn,
  Value<String> barcode,
  Value<int> minStockMilli,
  Value<int> active,
  Value<String?> oldId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

final class $ProductsReferences
    extends BaseReferences<_$AppDatabase, Products, DbProduct> {
  $ProductsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<StockMovements, List<DbStockMovement>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'products__id__stock_movements__product_id',
  );

  $StockMovementsProcessedTableManager get stockMovementsRefs {
    final manager = $StockMovementsTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<StockCache, List<DbStockCache>>
  _stockCacheRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockCache,
    aliasName: 'products__id__stock_cache__product_id',
  );

  $StockCacheProcessedTableManager get stockCacheRefs {
    final manager = $StockCacheTableManager(
      $_db,
      $_db.stockCache,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockCacheRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<BillLines, List<DbBillLine>> _billLinesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.billLines,
    aliasName: 'products__id__bill_lines__product_id',
  );

  $BillLinesProcessedTableManager get billLinesRefs {
    final manager = $BillLinesTableManager(
      $_db,
      $_db.billLines,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_billLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<EstimationLines, List<DbEstimationLine>>
  _estimationLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.estimationLines,
    aliasName: 'products__id__estimation_lines__product_id',
  );

  $EstimationLinesProcessedTableManager get estimationLinesRefs {
    final manager = $EstimationLinesTableManager(
      $_db,
      $_db.estimationLines,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _estimationLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ProductsFilterComposer extends Composer<_$AppDatabase, Products> {
  $ProductsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gstBp => $composableBuilder(
    column: $table.gstBp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hsn => $composableBuilder(
    column: $table.hsn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minStockMilli => $composableBuilder(
    column: $table.minStockMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($StockMovementsFilterComposer f) f,
  ) {
    final $StockMovementsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $StockMovementsFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockCacheRefs(
    Expression<bool> Function($StockCacheFilterComposer f) f,
  ) {
    final $StockCacheFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockCache,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $StockCacheFilterComposer(
            $db: $db,
            $table: $db.stockCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> billLinesRefs(
    Expression<bool> Function($BillLinesFilterComposer f) f,
  ) {
    final $BillLinesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillLinesFilterComposer(
            $db: $db,
            $table: $db.billLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> estimationLinesRefs(
    Expression<bool> Function($EstimationLinesFilterComposer f) f,
  ) {
    final $EstimationLinesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimationLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationLinesFilterComposer(
            $db: $db,
            $table: $db.estimationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ProductsOrderingComposer extends Composer<_$AppDatabase, Products> {
  $ProductsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gstBp => $composableBuilder(
    column: $table.gstBp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hsn => $composableBuilder(
    column: $table.hsn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minStockMilli => $composableBuilder(
    column: $table.minStockMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProductsAnnotationComposer extends Composer<_$AppDatabase, Products> {
  $ProductsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costPaise =>
      $composableBuilder(column: $table.costPaise, builder: (column) => column);

  GeneratedColumn<int> get gstBp =>
      $composableBuilder(column: $table.gstBp, builder: (column) => column);

  GeneratedColumn<String> get hsn =>
      $composableBuilder(column: $table.hsn, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get minStockMilli => $composableBuilder(
    column: $table.minStockMilli,
    builder: (column) => column,
  );

  GeneratedColumn<int> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get oldId =>
      $composableBuilder(column: $table.oldId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($StockMovementsAnnotationComposer a) f,
  ) {
    final $StockMovementsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $StockMovementsAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockCacheRefs<T extends Object>(
    Expression<T> Function($StockCacheAnnotationComposer a) f,
  ) {
    final $StockCacheAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockCache,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $StockCacheAnnotationComposer(
            $db: $db,
            $table: $db.stockCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> billLinesRefs<T extends Object>(
    Expression<T> Function($BillLinesAnnotationComposer a) f,
  ) {
    final $BillLinesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillLinesAnnotationComposer(
            $db: $db,
            $table: $db.billLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> estimationLinesRefs<T extends Object>(
    Expression<T> Function($EstimationLinesAnnotationComposer a) f,
  ) {
    final $EstimationLinesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimationLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationLinesAnnotationComposer(
            $db: $db,
            $table: $db.estimationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ProductsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Products,
          DbProduct,
          $ProductsFilterComposer,
          $ProductsOrderingComposer,
          $ProductsAnnotationComposer,
          $ProductsCreateCompanionBuilder,
          $ProductsUpdateCompanionBuilder,
          (DbProduct, $ProductsReferences),
          DbProduct,
          PrefetchHooks Function({
            bool stockMovementsRefs,
            bool stockCacheRefs,
            bool billLinesRefs,
            bool estimationLinesRefs,
          })
        > {
  $ProductsTableManager(_$AppDatabase db, Products table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProductsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProductsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProductsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> pricePaise = const Value.absent(),
                Value<int> costPaise = const Value.absent(),
                Value<int> gstBp = const Value.absent(),
                Value<String> hsn = const Value.absent(),
                Value<String> barcode = const Value.absent(),
                Value<int> minStockMilli = const Value.absent(),
                Value<int> active = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                name: name,
                category: category,
                unit: unit,
                pricePaise: pricePaise,
                costPaise: costPaise,
                gstBp: gstBp,
                hsn: hsn,
                barcode: barcode,
                minStockMilli: minStockMilli,
                active: active,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> category = const Value.absent(),
                Value<String> unit = const Value.absent(),
                required int pricePaise,
                Value<int> costPaise = const Value.absent(),
                Value<int> gstBp = const Value.absent(),
                Value<String> hsn = const Value.absent(),
                Value<String> barcode = const Value.absent(),
                Value<int> minStockMilli = const Value.absent(),
                Value<int> active = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                name: name,
                category: category,
                unit: unit,
                pricePaise: pricePaise,
                costPaise: costPaise,
                gstBp: gstBp,
                hsn: hsn,
                barcode: barcode,
                minStockMilli: minStockMilli,
                active: active,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Products, DbProduct>(table),
                  $ProductsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                stockMovementsRefs = false,
                stockCacheRefs = false,
                billLinesRefs = false,
                estimationLinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockMovementsRefs) db.stockMovements,
                    if (stockCacheRefs) db.stockCache,
                    if (billLinesRefs) db.billLines,
                    if (estimationLinesRefs) db.estimationLines,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          DbProduct,
                          Products,
                          DbStockMovement
                        >(
                          currentTable: table,
                          referencedTable: $ProductsReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) => $ProductsReferences(
                            db,
                            table,
                            p0,
                          ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stockCacheRefs)
                        await $_getPrefetchedData<
                          DbProduct,
                          Products,
                          DbStockCache
                        >(
                          currentTable: table,
                          referencedTable: $ProductsReferences
                              ._stockCacheRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $ProductsReferences(db, table, p0).stockCacheRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (billLinesRefs)
                        await $_getPrefetchedData<
                          DbProduct,
                          Products,
                          DbBillLine
                        >(
                          currentTable: table,
                          referencedTable: $ProductsReferences
                              ._billLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $ProductsReferences(db, table, p0).billLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (estimationLinesRefs)
                        await $_getPrefetchedData<
                          DbProduct,
                          Products,
                          DbEstimationLine
                        >(
                          currentTable: table,
                          referencedTable: $ProductsReferences
                              ._estimationLinesRefsTable(db),
                          managerFromTypedResult: (p0) => $ProductsReferences(
                            db,
                            table,
                            p0,
                          ).estimationLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $ProductsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Products,
      DbProduct,
      $ProductsFilterComposer,
      $ProductsOrderingComposer,
      $ProductsAnnotationComposer,
      $ProductsCreateCompanionBuilder,
      $ProductsUpdateCompanionBuilder,
      (DbProduct, $ProductsReferences),
      DbProduct,
      PrefetchHooks Function({
        bool stockMovementsRefs,
        bool stockCacheRefs,
        bool billLinesRefs,
        bool estimationLinesRefs,
      })
    >;
typedef $ProductFtsCreateCompanionBuilder = ProductFtsCompanion Function({
  required String name,
  required String barcode,
  Value<int> rowid,
});
typedef $ProductFtsUpdateCompanionBuilder = ProductFtsCompanion Function({
  Value<String> name,
  Value<String> barcode,
  Value<int> rowid,
});

class $ProductFtsFilterComposer extends Composer<_$AppDatabase, ProductFts> {
  $ProductFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );
}

class $ProductFtsOrderingComposer extends Composer<_$AppDatabase, ProductFts> {
  $ProductFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProductFtsAnnotationComposer
    extends Composer<_$AppDatabase, ProductFts> {
  $ProductFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);
}

class $ProductFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ProductFts,
          ProductFt,
          $ProductFtsFilterComposer,
          $ProductFtsOrderingComposer,
          $ProductFtsAnnotationComposer,
          $ProductFtsCreateCompanionBuilder,
          $ProductFtsUpdateCompanionBuilder,
          (ProductFt, BaseReferences<_$AppDatabase, ProductFts, ProductFt>),
          ProductFt,
          PrefetchHooks Function()
        > {
  $ProductFtsTableManager(_$AppDatabase db, ProductFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProductFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProductFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProductFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<String> barcode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ProductFtsCompanion(name: name, barcode: barcode, rowid: rowid),
          createCompanionCallback:
              ({
                required String name,
                required String barcode,
                Value<int> rowid = const Value.absent(),
              }) => ProductFtsCompanion.insert(
                name: name,
                barcode: barcode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ProductFts, ProductFt>(table),
                  BaseReferences<_$AppDatabase, ProductFts, ProductFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProductFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ProductFts,
      ProductFt,
      $ProductFtsFilterComposer,
      $ProductFtsOrderingComposer,
      $ProductFtsAnnotationComposer,
      $ProductFtsCreateCompanionBuilder,
      $ProductFtsUpdateCompanionBuilder,
      (ProductFt, BaseReferences<_$AppDatabase, ProductFts, ProductFt>),
      ProductFt,
      PrefetchHooks Function()
    >;
typedef $CustomersCreateCompanionBuilder = CustomersCompanion Function({
  required String id,
  required String name,
  Value<String> phone,
  Value<String> city,
  Value<String> address,
  Value<String> gstin,
  Value<int> creditLimitPaise,
  Value<String?> oldId,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $CustomersUpdateCompanionBuilder = CustomersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> phone,
  Value<String> city,
  Value<String> address,
  Value<String> gstin,
  Value<int> creditLimitPaise,
  Value<String?> oldId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

final class $CustomersReferences
    extends BaseReferences<_$AppDatabase, Customers, DbCustomer> {
  $CustomersReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Bills, List<DbBill>> _billsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.bills,
    aliasName: 'customers__id__bills__customer_id',
  );

  $BillsProcessedTableManager get billsRefs {
    final manager = $BillsTableManager(
      $_db,
      $_db.bills,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_billsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Estimations, List<DbEstimation>>
  _estimationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.estimations,
    aliasName: 'customers__id__estimations__customer_id',
  );

  $EstimationsProcessedTableManager get estimationsRefs {
    final manager = $EstimationsTableManager(
      $_db,
      $_db.estimations,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_estimationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Reminders, List<DbReminder>> _remindersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'customers__id__reminders__customer_id',
  );

  $RemindersProcessedTableManager get remindersRefs {
    final manager = $RemindersTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $CustomersFilterComposer extends Composer<_$AppDatabase, Customers> {
  $CustomersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> billsRefs(
    Expression<bool> Function($BillsFilterComposer f) f,
  ) {
    final $BillsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsFilterComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> estimationsRefs(
    Expression<bool> Function($EstimationsFilterComposer f) f,
  ) {
    final $EstimationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimations,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationsFilterComposer(
            $db: $db,
            $table: $db.estimations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($RemindersFilterComposer f) f,
  ) {
    final $RemindersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $RemindersFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CustomersOrderingComposer extends Composer<_$AppDatabase, Customers> {
  $CustomersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CustomersAnnotationComposer extends Composer<_$AppDatabase, Customers> {
  $CustomersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oldId =>
      $composableBuilder(column: $table.oldId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  Expression<T> billsRefs<T extends Object>(
    Expression<T> Function($BillsAnnotationComposer a) f,
  ) {
    final $BillsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsAnnotationComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> estimationsRefs<T extends Object>(
    Expression<T> Function($EstimationsAnnotationComposer a) f,
  ) {
    final $EstimationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimations,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationsAnnotationComposer(
            $db: $db,
            $table: $db.estimations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($RemindersAnnotationComposer a) f,
  ) {
    final $RemindersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $RemindersAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CustomersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Customers,
          DbCustomer,
          $CustomersFilterComposer,
          $CustomersOrderingComposer,
          $CustomersAnnotationComposer,
          $CustomersCreateCompanionBuilder,
          $CustomersUpdateCompanionBuilder,
          (DbCustomer, $CustomersReferences),
          DbCustomer,
          PrefetchHooks Function({
            bool billsRefs,
            bool estimationsRefs,
            bool remindersRefs,
          })
        > {
  $CustomersTableManager(_$AppDatabase db, Customers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CustomersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CustomersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CustomersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> gstin = const Value.absent(),
                Value<int> creditLimitPaise = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                city: city,
                address: address,
                gstin: gstin,
                creditLimitPaise: creditLimitPaise,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> phone = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> gstin = const Value.absent(),
                Value<int> creditLimitPaise = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                city: city,
                address: address,
                gstin: gstin,
                creditLimitPaise: creditLimitPaise,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Customers, DbCustomer>(table),
                  $CustomersReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                billsRefs = false,
                estimationsRefs = false,
                remindersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (billsRefs) db.bills,
                    if (estimationsRefs) db.estimations,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (billsRefs)
                        await $_getPrefetchedData<
                          DbCustomer,
                          Customers,
                          DbBill
                        >(
                          currentTable: table,
                          referencedTable: $CustomersReferences._billsRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $CustomersReferences(db, table, p0).billsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (estimationsRefs)
                        await $_getPrefetchedData<
                          DbCustomer,
                          Customers,
                          DbEstimation
                        >(
                          currentTable: table,
                          referencedTable: $CustomersReferences
                              ._estimationsRefsTable(db),
                          managerFromTypedResult: (p0) => $CustomersReferences(
                            db,
                            table,
                            p0,
                          ).estimationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          DbCustomer,
                          Customers,
                          DbReminder
                        >(
                          currentTable: table,
                          referencedTable: $CustomersReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $CustomersReferences(db, table, p0).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $CustomersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Customers,
      DbCustomer,
      $CustomersFilterComposer,
      $CustomersOrderingComposer,
      $CustomersAnnotationComposer,
      $CustomersCreateCompanionBuilder,
      $CustomersUpdateCompanionBuilder,
      (DbCustomer, $CustomersReferences),
      DbCustomer,
      PrefetchHooks Function({
        bool billsRefs,
        bool estimationsRefs,
        bool remindersRefs,
      })
    >;
typedef $DealersCreateCompanionBuilder = DealersCompanion Function({
  required String id,
  required String name,
  Value<String> phone,
  Value<String> city,
  Value<String> address,
  Value<String> gstin,
  Value<String?> oldId,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $DealersUpdateCompanionBuilder = DealersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> phone,
  Value<String> city,
  Value<String> address,
  Value<String> gstin,
  Value<String?> oldId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

class $DealersFilterComposer extends Composer<_$AppDatabase, Dealers> {
  $DealersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $DealersOrderingComposer extends Composer<_$AppDatabase, Dealers> {
  $DealersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldId => $composableBuilder(
    column: $table.oldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DealersAnnotationComposer extends Composer<_$AppDatabase, Dealers> {
  $DealersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get oldId =>
      $composableBuilder(column: $table.oldId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $DealersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Dealers,
          DbDealer,
          $DealersFilterComposer,
          $DealersOrderingComposer,
          $DealersAnnotationComposer,
          $DealersCreateCompanionBuilder,
          $DealersUpdateCompanionBuilder,
          (DbDealer, BaseReferences<_$AppDatabase, Dealers, DbDealer>),
          DbDealer,
          PrefetchHooks Function()
        > {
  $DealersTableManager(_$AppDatabase db, Dealers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DealersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DealersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DealersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> gstin = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DealersCompanion(
                id: id,
                name: name,
                phone: phone,
                city: city,
                address: address,
                gstin: gstin,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> phone = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> gstin = const Value.absent(),
                Value<String?> oldId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DealersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                city: city,
                address: address,
                gstin: gstin,
                oldId: oldId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Dealers, DbDealer>(table),
                  BaseReferences<_$AppDatabase, Dealers, DbDealer>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DealersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Dealers,
      DbDealer,
      $DealersFilterComposer,
      $DealersOrderingComposer,
      $DealersAnnotationComposer,
      $DealersCreateCompanionBuilder,
      $DealersUpdateCompanionBuilder,
      (DbDealer, BaseReferences<_$AppDatabase, Dealers, DbDealer>),
      DbDealer,
      PrefetchHooks Function()
    >;
typedef $StockMovementsCreateCompanionBuilder =
    StockMovementsCompanion Function({
      required String id,
      required String productId,
      required int qtyMilli,
      required String kind,
      Value<String?> refId,
      Value<int> unitCostPaise,
      required int at,
      Value<String> note,
      required int createdAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $StockMovementsUpdateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<int> qtyMilli,
      Value<String> kind,
      Value<String?> refId,
      Value<int> unitCostPaise,
      Value<int> at,
      Value<String> note,
      Value<int> createdAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

final class $StockMovementsReferences
    extends BaseReferences<_$AppDatabase, StockMovements, DbStockMovement> {
  $StockMovementsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Products _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('stock_movements__product_id__products__id');

  $ProductsProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $ProductsTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $StockMovementsFilterComposer
    extends Composer<_$AppDatabase, StockMovements> {
  $StockMovementsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCostPaise => $composableBuilder(
    column: $table.unitCostPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $ProductsFilterComposer get productId {
    final $ProductsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockMovementsOrderingComposer
    extends Composer<_$AppDatabase, StockMovements> {
  $StockMovementsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCostPaise => $composableBuilder(
    column: $table.unitCostPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $ProductsOrderingComposer get productId {
    final $ProductsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockMovementsAnnotationComposer
    extends Composer<_$AppDatabase, StockMovements> {
  $StockMovementsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qtyMilli =>
      $composableBuilder(column: $table.qtyMilli, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<int> get unitCostPaise => $composableBuilder(
    column: $table.unitCostPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $ProductsAnnotationComposer get productId {
    final $ProductsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockMovementsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          StockMovements,
          DbStockMovement,
          $StockMovementsFilterComposer,
          $StockMovementsOrderingComposer,
          $StockMovementsAnnotationComposer,
          $StockMovementsCreateCompanionBuilder,
          $StockMovementsUpdateCompanionBuilder,
          (DbStockMovement, $StockMovementsReferences),
          DbStockMovement,
          PrefetchHooks Function({bool productId})
        > {
  $StockMovementsTableManager(_$AppDatabase db, StockMovements table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $StockMovementsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $StockMovementsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $StockMovementsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> qtyMilli = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> refId = const Value.absent(),
                Value<int> unitCostPaise = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockMovementsCompanion(
                id: id,
                productId: productId,
                qtyMilli: qtyMilli,
                kind: kind,
                refId: refId,
                unitCostPaise: unitCostPaise,
                at: at,
                note: note,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required int qtyMilli,
                required String kind,
                Value<String?> refId = const Value.absent(),
                Value<int> unitCostPaise = const Value.absent(),
                required int at,
                Value<String> note = const Value.absent(),
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => StockMovementsCompanion.insert(
                id: id,
                productId: productId,
                qtyMilli: qtyMilli,
                kind: kind,
                refId: refId,
                unitCostPaise: unitCostPaise,
                at: at,
                note: note,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<StockMovements, DbStockMovement>(table),
                  $StockMovementsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $StockMovementsReferences
                            ._productIdTable(db),
                        referencedColumn: $StockMovementsReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
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

typedef $StockMovementsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      StockMovements,
      DbStockMovement,
      $StockMovementsFilterComposer,
      $StockMovementsOrderingComposer,
      $StockMovementsAnnotationComposer,
      $StockMovementsCreateCompanionBuilder,
      $StockMovementsUpdateCompanionBuilder,
      (DbStockMovement, $StockMovementsReferences),
      DbStockMovement,
      PrefetchHooks Function({bool productId})
    >;
typedef $StockCacheCreateCompanionBuilder = StockCacheCompanion Function({
  required String productId,
  Value<int> qtyMilli,
  Value<int> rowid,
});
typedef $StockCacheUpdateCompanionBuilder = StockCacheCompanion Function({
  Value<String> productId,
  Value<int> qtyMilli,
  Value<int> rowid,
});

final class $StockCacheReferences
    extends BaseReferences<_$AppDatabase, StockCache, DbStockCache> {
  $StockCacheReferences(super.$_db, super.$_table, super.$_typedResult);

  static Products _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('stock_cache__product_id__products__id');

  $ProductsProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $ProductsTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $StockCacheFilterComposer extends Composer<_$AppDatabase, StockCache> {
  $StockCacheFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnFilters(column),
  );

  $ProductsFilterComposer get productId {
    final $ProductsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockCacheOrderingComposer extends Composer<_$AppDatabase, StockCache> {
  $StockCacheOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnOrderings(column),
  );

  $ProductsOrderingComposer get productId {
    final $ProductsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockCacheAnnotationComposer
    extends Composer<_$AppDatabase, StockCache> {
  $StockCacheAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get qtyMilli =>
      $composableBuilder(column: $table.qtyMilli, builder: (column) => column);

  $ProductsAnnotationComposer get productId {
    final $ProductsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $StockCacheTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          StockCache,
          DbStockCache,
          $StockCacheFilterComposer,
          $StockCacheOrderingComposer,
          $StockCacheAnnotationComposer,
          $StockCacheCreateCompanionBuilder,
          $StockCacheUpdateCompanionBuilder,
          (DbStockCache, $StockCacheReferences),
          DbStockCache,
          PrefetchHooks Function({bool productId})
        > {
  $StockCacheTableManager(_$AppDatabase db, StockCache table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $StockCacheFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $StockCacheOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $StockCacheAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> productId = const Value.absent(),
                Value<int> qtyMilli = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockCacheCompanion(
                productId: productId,
                qtyMilli: qtyMilli,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productId,
                Value<int> qtyMilli = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockCacheCompanion.insert(
                productId: productId,
                qtyMilli: qtyMilli,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<StockCache, DbStockCache>(table),
                  $StockCacheReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $StockCacheReferences._productIdTable(
                          db,
                        ),
                        referencedColumn: $StockCacheReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
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

typedef $StockCacheProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      StockCache,
      DbStockCache,
      $StockCacheFilterComposer,
      $StockCacheOrderingComposer,
      $StockCacheAnnotationComposer,
      $StockCacheCreateCompanionBuilder,
      $StockCacheUpdateCompanionBuilder,
      (DbStockCache, $StockCacheReferences),
      DbStockCache,
      PrefetchHooks Function({bool productId})
    >;
typedef $BillsCreateCompanionBuilder = BillsCompanion Function({
  required String id,
  required String number,
  required String series,
  required int seq,
  required int billedAt,
  required String day,
  Value<String?> customerId,
  Value<String> customerName,
  required int totalPaise,
  required int receivedPaise,
  Value<int> balancePaise,
  Value<int> changePaise,
  Value<int> advanceKeptPaise,
  Value<int> taxablePaise,
  Value<int> cgstPaise,
  Value<int> sgstPaise,
  Value<int> igstPaise,
  Value<int> discountPaise,
  Value<int> roundOffPaise,
  Value<int> payMode,
  Value<int> status,
  Value<int> cancelled,
  Value<int> itemCount,
  Value<int> pricesIncludeGst,
  required String idemKey,
  Value<String?> oldBillNo,
  Value<String> note,
  Value<String> createdBy,
  required int createdAt,
  required String deviceId,
  Value<int> rowid,
});
typedef $BillsUpdateCompanionBuilder = BillsCompanion Function({
  Value<String> id,
  Value<String> number,
  Value<String> series,
  Value<int> seq,
  Value<int> billedAt,
  Value<String> day,
  Value<String?> customerId,
  Value<String> customerName,
  Value<int> totalPaise,
  Value<int> receivedPaise,
  Value<int> balancePaise,
  Value<int> changePaise,
  Value<int> advanceKeptPaise,
  Value<int> taxablePaise,
  Value<int> cgstPaise,
  Value<int> sgstPaise,
  Value<int> igstPaise,
  Value<int> discountPaise,
  Value<int> roundOffPaise,
  Value<int> payMode,
  Value<int> status,
  Value<int> cancelled,
  Value<int> itemCount,
  Value<int> pricesIncludeGst,
  Value<String> idemKey,
  Value<String?> oldBillNo,
  Value<String> note,
  Value<String> createdBy,
  Value<int> createdAt,
  Value<String> deviceId,
  Value<int> rowid,
});

final class $BillsReferences
    extends BaseReferences<_$AppDatabase, Bills, DbBill> {
  $BillsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Customers _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('bills__customer_id__customers__id');

  $CustomersProcessedTableManager? get customerId {
    final $_column = $_itemColumn<String>('customer_id');
    if ($_column == null) return null;
    final manager = $CustomersTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<BillLines, List<DbBillLine>> _billLinesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.billLines,
    aliasName: 'bills__id__bill_lines__bill_id',
  );

  $BillLinesProcessedTableManager get billLinesRefs {
    final manager = $BillLinesTableManager(
      $_db,
      $_db.billLines,
    ).filter((f) => f.billId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_billLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<BillCancellations, List<DbBillCancellation>>
  _billCancellationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.billCancellations,
        aliasName: 'bills__id__bill_cancellations__bill_id',
      );

  $BillCancellationsProcessedTableManager get billCancellationsRefs {
    final manager = $BillCancellationsTableManager(
      $_db,
      $_db.billCancellations,
    ).filter((f) => f.billId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _billCancellationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $BillsFilterComposer extends Composer<_$AppDatabase, Bills> {
  $BillsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billedAt => $composableBuilder(
    column: $table.billedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedPaise => $composableBuilder(
    column: $table.receivedPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changePaise => $composableBuilder(
    column: $table.changePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get advanceKeptPaise => $composableBuilder(
    column: $table.advanceKeptPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cgstPaise => $composableBuilder(
    column: $table.cgstPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sgstPaise => $composableBuilder(
    column: $table.sgstPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get igstPaise => $composableBuilder(
    column: $table.igstPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundOffPaise => $composableBuilder(
    column: $table.roundOffPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payMode => $composableBuilder(
    column: $table.payMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pricesIncludeGst => $composableBuilder(
    column: $table.pricesIncludeGst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idemKey => $composableBuilder(
    column: $table.idemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldBillNo => $composableBuilder(
    column: $table.oldBillNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $CustomersFilterComposer get customerId {
    final $CustomersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> billLinesRefs(
    Expression<bool> Function($BillLinesFilterComposer f) f,
  ) {
    final $BillLinesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billLines,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillLinesFilterComposer(
            $db: $db,
            $table: $db.billLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> billCancellationsRefs(
    Expression<bool> Function($BillCancellationsFilterComposer f) f,
  ) {
    final $BillCancellationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billCancellations,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillCancellationsFilterComposer(
            $db: $db,
            $table: $db.billCancellations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $BillsOrderingComposer extends Composer<_$AppDatabase, Bills> {
  $BillsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billedAt => $composableBuilder(
    column: $table.billedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedPaise => $composableBuilder(
    column: $table.receivedPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changePaise => $composableBuilder(
    column: $table.changePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get advanceKeptPaise => $composableBuilder(
    column: $table.advanceKeptPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cgstPaise => $composableBuilder(
    column: $table.cgstPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sgstPaise => $composableBuilder(
    column: $table.sgstPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get igstPaise => $composableBuilder(
    column: $table.igstPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundOffPaise => $composableBuilder(
    column: $table.roundOffPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payMode => $composableBuilder(
    column: $table.payMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pricesIncludeGst => $composableBuilder(
    column: $table.pricesIncludeGst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idemKey => $composableBuilder(
    column: $table.idemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldBillNo => $composableBuilder(
    column: $table.oldBillNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $CustomersOrderingComposer get customerId {
    final $CustomersOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillsAnnotationComposer extends Composer<_$AppDatabase, Bills> {
  $BillsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get billedAt =>
      $composableBuilder(column: $table.billedAt, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedPaise => $composableBuilder(
    column: $table.receivedPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get changePaise => $composableBuilder(
    column: $table.changePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get advanceKeptPaise => $composableBuilder(
    column: $table.advanceKeptPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cgstPaise =>
      $composableBuilder(column: $table.cgstPaise, builder: (column) => column);

  GeneratedColumn<int> get sgstPaise =>
      $composableBuilder(column: $table.sgstPaise, builder: (column) => column);

  GeneratedColumn<int> get igstPaise =>
      $composableBuilder(column: $table.igstPaise, builder: (column) => column);

  GeneratedColumn<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roundOffPaise => $composableBuilder(
    column: $table.roundOffPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payMode =>
      $composableBuilder(column: $table.payMode, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get cancelled =>
      $composableBuilder(column: $table.cancelled, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get pricesIncludeGst => $composableBuilder(
    column: $table.pricesIncludeGst,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idemKey =>
      $composableBuilder(column: $table.idemKey, builder: (column) => column);

  GeneratedColumn<String> get oldBillNo =>
      $composableBuilder(column: $table.oldBillNo, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $CustomersAnnotationComposer get customerId {
    final $CustomersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> billLinesRefs<T extends Object>(
    Expression<T> Function($BillLinesAnnotationComposer a) f,
  ) {
    final $BillLinesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billLines,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillLinesAnnotationComposer(
            $db: $db,
            $table: $db.billLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> billCancellationsRefs<T extends Object>(
    Expression<T> Function($BillCancellationsAnnotationComposer a) f,
  ) {
    final $BillCancellationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.billCancellations,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillCancellationsAnnotationComposer(
            $db: $db,
            $table: $db.billCancellations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $BillsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Bills,
          DbBill,
          $BillsFilterComposer,
          $BillsOrderingComposer,
          $BillsAnnotationComposer,
          $BillsCreateCompanionBuilder,
          $BillsUpdateCompanionBuilder,
          (DbBill, $BillsReferences),
          DbBill,
          PrefetchHooks Function({
            bool customerId,
            bool billLinesRefs,
            bool billCancellationsRefs,
          })
        > {
  $BillsTableManager(_$AppDatabase db, Bills table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BillsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BillsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BillsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<String> series = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> billedAt = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<int> totalPaise = const Value.absent(),
                Value<int> receivedPaise = const Value.absent(),
                Value<int> balancePaise = const Value.absent(),
                Value<int> changePaise = const Value.absent(),
                Value<int> advanceKeptPaise = const Value.absent(),
                Value<int> taxablePaise = const Value.absent(),
                Value<int> cgstPaise = const Value.absent(),
                Value<int> sgstPaise = const Value.absent(),
                Value<int> igstPaise = const Value.absent(),
                Value<int> discountPaise = const Value.absent(),
                Value<int> roundOffPaise = const Value.absent(),
                Value<int> payMode = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> cancelled = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> pricesIncludeGst = const Value.absent(),
                Value<String> idemKey = const Value.absent(),
                Value<String?> oldBillNo = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion(
                id: id,
                number: number,
                series: series,
                seq: seq,
                billedAt: billedAt,
                day: day,
                customerId: customerId,
                customerName: customerName,
                totalPaise: totalPaise,
                receivedPaise: receivedPaise,
                balancePaise: balancePaise,
                changePaise: changePaise,
                advanceKeptPaise: advanceKeptPaise,
                taxablePaise: taxablePaise,
                cgstPaise: cgstPaise,
                sgstPaise: sgstPaise,
                igstPaise: igstPaise,
                discountPaise: discountPaise,
                roundOffPaise: roundOffPaise,
                payMode: payMode,
                status: status,
                cancelled: cancelled,
                itemCount: itemCount,
                pricesIncludeGst: pricesIncludeGst,
                idemKey: idemKey,
                oldBillNo: oldBillNo,
                note: note,
                createdBy: createdBy,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String number,
                required String series,
                required int seq,
                required int billedAt,
                required String day,
                Value<String?> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                required int totalPaise,
                required int receivedPaise,
                Value<int> balancePaise = const Value.absent(),
                Value<int> changePaise = const Value.absent(),
                Value<int> advanceKeptPaise = const Value.absent(),
                Value<int> taxablePaise = const Value.absent(),
                Value<int> cgstPaise = const Value.absent(),
                Value<int> sgstPaise = const Value.absent(),
                Value<int> igstPaise = const Value.absent(),
                Value<int> discountPaise = const Value.absent(),
                Value<int> roundOffPaise = const Value.absent(),
                Value<int> payMode = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> cancelled = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> pricesIncludeGst = const Value.absent(),
                required String idemKey,
                Value<String?> oldBillNo = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion.insert(
                id: id,
                number: number,
                series: series,
                seq: seq,
                billedAt: billedAt,
                day: day,
                customerId: customerId,
                customerName: customerName,
                totalPaise: totalPaise,
                receivedPaise: receivedPaise,
                balancePaise: balancePaise,
                changePaise: changePaise,
                advanceKeptPaise: advanceKeptPaise,
                taxablePaise: taxablePaise,
                cgstPaise: cgstPaise,
                sgstPaise: sgstPaise,
                igstPaise: igstPaise,
                discountPaise: discountPaise,
                roundOffPaise: roundOffPaise,
                payMode: payMode,
                status: status,
                cancelled: cancelled,
                itemCount: itemCount,
                pricesIncludeGst: pricesIncludeGst,
                idemKey: idemKey,
                oldBillNo: oldBillNo,
                note: note,
                createdBy: createdBy,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Bills, DbBill>(table),
                  $BillsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                customerId = false,
                billLinesRefs = false,
                billCancellationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (billLinesRefs) db.billLines,
                    if (billCancellationsRefs) db.billCancellations,
                  ],
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
                        if (customerId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.customerId,
                            referencedTable: $BillsReferences._customerIdTable(
                              db,
                            ),
                            referencedColumn: $BillsReferences
                                ._customerIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (billLinesRefs)
                        await $_getPrefetchedData<DbBill, Bills, DbBillLine>(
                          currentTable: table,
                          referencedTable: $BillsReferences._billLinesRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $BillsReferences(db, table, p0).billLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.billId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (billCancellationsRefs)
                        await $_getPrefetchedData<
                          DbBill,
                          Bills,
                          DbBillCancellation
                        >(
                          currentTable: table,
                          referencedTable: $BillsReferences
                              ._billCancellationsRefsTable(db),
                          managerFromTypedResult: (p0) => $BillsReferences(
                            db,
                            table,
                            p0,
                          ).billCancellationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.billId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $BillsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Bills,
      DbBill,
      $BillsFilterComposer,
      $BillsOrderingComposer,
      $BillsAnnotationComposer,
      $BillsCreateCompanionBuilder,
      $BillsUpdateCompanionBuilder,
      (DbBill, $BillsReferences),
      DbBill,
      PrefetchHooks Function({
        bool customerId,
        bool billLinesRefs,
        bool billCancellationsRefs,
      })
    >;
typedef $BillLinesCreateCompanionBuilder = BillLinesCompanion Function({
  required String id,
  required String billId,
  required int lineNo,
  required String productId,
  required String name,
  Value<String> unit,
  required int qtyMilli,
  required int ratePaise,
  Value<int> costPaise,
  Value<int> discountBp,
  Value<int> gstBp,
  required int grossPaise,
  Value<int> discountPaise,
  required int taxablePaise,
  required int taxPaise,
  required int totalPaise,
  Value<int> rowid,
});
typedef $BillLinesUpdateCompanionBuilder = BillLinesCompanion Function({
  Value<String> id,
  Value<String> billId,
  Value<int> lineNo,
  Value<String> productId,
  Value<String> name,
  Value<String> unit,
  Value<int> qtyMilli,
  Value<int> ratePaise,
  Value<int> costPaise,
  Value<int> discountBp,
  Value<int> gstBp,
  Value<int> grossPaise,
  Value<int> discountPaise,
  Value<int> taxablePaise,
  Value<int> taxPaise,
  Value<int> totalPaise,
  Value<int> rowid,
});

final class $BillLinesReferences
    extends BaseReferences<_$AppDatabase, BillLines, DbBillLine> {
  $BillLinesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Bills _billIdTable(_$AppDatabase db) =>
      db.bills.createAlias('bill_lines__bill_id__bills__id');

  $BillsProcessedTableManager get billId {
    final $_column = $_itemColumn<String>('bill_id')!;

    final manager = $BillsTableManager(
      $_db,
      $_db.bills,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_billIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Products _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('bill_lines__product_id__products__id');

  $ProductsProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $ProductsTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $BillLinesFilterComposer extends Composer<_$AppDatabase, BillLines> {
  $BillLinesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratePaise => $composableBuilder(
    column: $table.ratePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gstBp => $composableBuilder(
    column: $table.gstBp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grossPaise => $composableBuilder(
    column: $table.grossPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnFilters(column),
  );

  $BillsFilterComposer get billId {
    final $BillsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsFilterComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsFilterComposer get productId {
    final $ProductsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillLinesOrderingComposer extends Composer<_$AppDatabase, BillLines> {
  $BillLinesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratePaise => $composableBuilder(
    column: $table.ratePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gstBp => $composableBuilder(
    column: $table.gstBp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grossPaise => $composableBuilder(
    column: $table.grossPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnOrderings(column),
  );

  $BillsOrderingComposer get billId {
    final $BillsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsOrderingComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsOrderingComposer get productId {
    final $ProductsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillLinesAnnotationComposer extends Composer<_$AppDatabase, BillLines> {
  $BillLinesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineNo =>
      $composableBuilder(column: $table.lineNo, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get qtyMilli =>
      $composableBuilder(column: $table.qtyMilli, builder: (column) => column);

  GeneratedColumn<int> get ratePaise =>
      $composableBuilder(column: $table.ratePaise, builder: (column) => column);

  GeneratedColumn<int> get costPaise =>
      $composableBuilder(column: $table.costPaise, builder: (column) => column);

  GeneratedColumn<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gstBp =>
      $composableBuilder(column: $table.gstBp, builder: (column) => column);

  GeneratedColumn<int> get grossPaise => $composableBuilder(
    column: $table.grossPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountPaise => $composableBuilder(
    column: $table.discountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxPaise =>
      $composableBuilder(column: $table.taxPaise, builder: (column) => column);

  GeneratedColumn<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => column,
  );

  $BillsAnnotationComposer get billId {
    final $BillsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsAnnotationComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsAnnotationComposer get productId {
    final $ProductsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillLinesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          BillLines,
          DbBillLine,
          $BillLinesFilterComposer,
          $BillLinesOrderingComposer,
          $BillLinesAnnotationComposer,
          $BillLinesCreateCompanionBuilder,
          $BillLinesUpdateCompanionBuilder,
          (DbBillLine, $BillLinesReferences),
          DbBillLine,
          PrefetchHooks Function({bool billId, bool productId})
        > {
  $BillLinesTableManager(_$AppDatabase db, BillLines table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BillLinesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BillLinesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BillLinesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<int> lineNo = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> qtyMilli = const Value.absent(),
                Value<int> ratePaise = const Value.absent(),
                Value<int> costPaise = const Value.absent(),
                Value<int> discountBp = const Value.absent(),
                Value<int> gstBp = const Value.absent(),
                Value<int> grossPaise = const Value.absent(),
                Value<int> discountPaise = const Value.absent(),
                Value<int> taxablePaise = const Value.absent(),
                Value<int> taxPaise = const Value.absent(),
                Value<int> totalPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillLinesCompanion(
                id: id,
                billId: billId,
                lineNo: lineNo,
                productId: productId,
                name: name,
                unit: unit,
                qtyMilli: qtyMilli,
                ratePaise: ratePaise,
                costPaise: costPaise,
                discountBp: discountBp,
                gstBp: gstBp,
                grossPaise: grossPaise,
                discountPaise: discountPaise,
                taxablePaise: taxablePaise,
                taxPaise: taxPaise,
                totalPaise: totalPaise,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required int lineNo,
                required String productId,
                required String name,
                Value<String> unit = const Value.absent(),
                required int qtyMilli,
                required int ratePaise,
                Value<int> costPaise = const Value.absent(),
                Value<int> discountBp = const Value.absent(),
                Value<int> gstBp = const Value.absent(),
                required int grossPaise,
                Value<int> discountPaise = const Value.absent(),
                required int taxablePaise,
                required int taxPaise,
                required int totalPaise,
                Value<int> rowid = const Value.absent(),
              }) => BillLinesCompanion.insert(
                id: id,
                billId: billId,
                lineNo: lineNo,
                productId: productId,
                name: name,
                unit: unit,
                qtyMilli: qtyMilli,
                ratePaise: ratePaise,
                costPaise: costPaise,
                discountBp: discountBp,
                gstBp: gstBp,
                grossPaise: grossPaise,
                discountPaise: discountPaise,
                taxablePaise: taxablePaise,
                taxPaise: taxPaise,
                totalPaise: totalPaise,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BillLines, DbBillLine>(table),
                  $BillLinesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({billId = false, productId = false}) {
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
                    if (billId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.billId,
                        referencedTable: $BillLinesReferences._billIdTable(db),
                        referencedColumn: $BillLinesReferences
                            ._billIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $BillLinesReferences._productIdTable(
                          db,
                        ),
                        referencedColumn: $BillLinesReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
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

typedef $BillLinesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      BillLines,
      DbBillLine,
      $BillLinesFilterComposer,
      $BillLinesOrderingComposer,
      $BillLinesAnnotationComposer,
      $BillLinesCreateCompanionBuilder,
      $BillLinesUpdateCompanionBuilder,
      (DbBillLine, $BillLinesReferences),
      DbBillLine,
      PrefetchHooks Function({bool billId, bool productId})
    >;
typedef $BillCancellationsCreateCompanionBuilder =
    BillCancellationsCompanion Function({
      required String id,
      required String billId,
      required String billNo,
      required String reason,
      Value<String> byName,
      required int at,
      required int createdAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $BillCancellationsUpdateCompanionBuilder =
    BillCancellationsCompanion Function({
      Value<String> id,
      Value<String> billId,
      Value<String> billNo,
      Value<String> reason,
      Value<String> byName,
      Value<int> at,
      Value<int> createdAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

final class $BillCancellationsReferences
    extends
        BaseReferences<_$AppDatabase, BillCancellations, DbBillCancellation> {
  $BillCancellationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Bills _billIdTable(_$AppDatabase db) =>
      db.bills.createAlias('bill_cancellations__bill_id__bills__id');

  $BillsProcessedTableManager get billId {
    final $_column = $_itemColumn<String>('bill_id')!;

    final manager = $BillsTableManager(
      $_db,
      $_db.bills,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_billIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $BillCancellationsFilterComposer
    extends Composer<_$AppDatabase, BillCancellations> {
  $BillCancellationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $BillsFilterComposer get billId {
    final $BillsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsFilterComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillCancellationsOrderingComposer
    extends Composer<_$AppDatabase, BillCancellations> {
  $BillCancellationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $BillsOrderingComposer get billId {
    final $BillsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsOrderingComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillCancellationsAnnotationComposer
    extends Composer<_$AppDatabase, BillCancellations> {
  $BillCancellationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billNo =>
      $composableBuilder(column: $table.billNo, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get byName =>
      $composableBuilder(column: $table.byName, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $BillsAnnotationComposer get billId {
    final $BillsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $BillsAnnotationComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $BillCancellationsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          BillCancellations,
          DbBillCancellation,
          $BillCancellationsFilterComposer,
          $BillCancellationsOrderingComposer,
          $BillCancellationsAnnotationComposer,
          $BillCancellationsCreateCompanionBuilder,
          $BillCancellationsUpdateCompanionBuilder,
          (DbBillCancellation, $BillCancellationsReferences),
          DbBillCancellation,
          PrefetchHooks Function({bool billId})
        > {
  $BillCancellationsTableManager(_$AppDatabase db, BillCancellations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BillCancellationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BillCancellationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BillCancellationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<String> billNo = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillCancellationsCompanion(
                id: id,
                billId: billId,
                billNo: billNo,
                reason: reason,
                byName: byName,
                at: at,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required String billNo,
                required String reason,
                Value<String> byName = const Value.absent(),
                required int at,
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => BillCancellationsCompanion.insert(
                id: id,
                billId: billId,
                billNo: billNo,
                reason: reason,
                byName: byName,
                at: at,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BillCancellations, DbBillCancellation>(table),
                  $BillCancellationsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({billId = false}) {
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
                    if (billId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.billId,
                        referencedTable: $BillCancellationsReferences
                            ._billIdTable(db),
                        referencedColumn: $BillCancellationsReferences
                            ._billIdTable(db)
                            .id,
                      ) as T;
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

typedef $BillCancellationsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      BillCancellations,
      DbBillCancellation,
      $BillCancellationsFilterComposer,
      $BillCancellationsOrderingComposer,
      $BillCancellationsAnnotationComposer,
      $BillCancellationsCreateCompanionBuilder,
      $BillCancellationsUpdateCompanionBuilder,
      (DbBillCancellation, $BillCancellationsReferences),
      DbBillCancellation,
      PrefetchHooks Function({bool billId})
    >;
typedef $EstimationsCreateCompanionBuilder = EstimationsCompanion Function({
  required String id,
  required String number,
  required int at,
  Value<int?> editedOn,
  Value<String?> customerId,
  Value<String> customerName,
  required int totalPaise,
  Value<int> lineCount,
  Value<String?> convertedBillId,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $EstimationsUpdateCompanionBuilder = EstimationsCompanion Function({
  Value<String> id,
  Value<String> number,
  Value<int> at,
  Value<int?> editedOn,
  Value<String?> customerId,
  Value<String> customerName,
  Value<int> totalPaise,
  Value<int> lineCount,
  Value<String?> convertedBillId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

final class $EstimationsReferences
    extends BaseReferences<_$AppDatabase, Estimations, DbEstimation> {
  $EstimationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Customers _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('estimations__customer_id__customers__id');

  $CustomersProcessedTableManager? get customerId {
    final $_column = $_itemColumn<String>('customer_id');
    if ($_column == null) return null;
    final manager = $CustomersTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<EstimationLines, List<DbEstimationLine>>
  _estimationLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.estimationLines,
    aliasName: 'estimations__id__estimation_lines__estimation_id',
  );

  $EstimationLinesProcessedTableManager get estimationLinesRefs {
    final manager = $EstimationLinesTableManager(
      $_db,
      $_db.estimationLines,
    ).filter((f) => f.estimationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _estimationLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $EstimationsFilterComposer extends Composer<_$AppDatabase, Estimations> {
  $EstimationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editedOn => $composableBuilder(
    column: $table.editedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convertedBillId => $composableBuilder(
    column: $table.convertedBillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  $CustomersFilterComposer get customerId {
    final $CustomersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> estimationLinesRefs(
    Expression<bool> Function($EstimationLinesFilterComposer f) f,
  ) {
    final $EstimationLinesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimationLines,
      getReferencedColumn: (t) => t.estimationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationLinesFilterComposer(
            $db: $db,
            $table: $db.estimationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $EstimationsOrderingComposer
    extends Composer<_$AppDatabase, Estimations> {
  $EstimationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editedOn => $composableBuilder(
    column: $table.editedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convertedBillId => $composableBuilder(
    column: $table.convertedBillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  $CustomersOrderingComposer get customerId {
    final $CustomersOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $EstimationsAnnotationComposer
    extends Composer<_$AppDatabase, Estimations> {
  $EstimationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get editedOn =>
      $composableBuilder(column: $table.editedOn, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);

  GeneratedColumn<String> get convertedBillId => $composableBuilder(
    column: $table.convertedBillId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  $CustomersAnnotationComposer get customerId {
    final $CustomersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> estimationLinesRefs<T extends Object>(
    Expression<T> Function($EstimationLinesAnnotationComposer a) f,
  ) {
    final $EstimationLinesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.estimationLines,
      getReferencedColumn: (t) => t.estimationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationLinesAnnotationComposer(
            $db: $db,
            $table: $db.estimationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $EstimationsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Estimations,
          DbEstimation,
          $EstimationsFilterComposer,
          $EstimationsOrderingComposer,
          $EstimationsAnnotationComposer,
          $EstimationsCreateCompanionBuilder,
          $EstimationsUpdateCompanionBuilder,
          (DbEstimation, $EstimationsReferences),
          DbEstimation,
          PrefetchHooks Function({bool customerId, bool estimationLinesRefs})
        > {
  $EstimationsTableManager(_$AppDatabase db, Estimations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EstimationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EstimationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EstimationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int?> editedOn = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<int> totalPaise = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<String?> convertedBillId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstimationsCompanion(
                id: id,
                number: number,
                at: at,
                editedOn: editedOn,
                customerId: customerId,
                customerName: customerName,
                totalPaise: totalPaise,
                lineCount: lineCount,
                convertedBillId: convertedBillId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String number,
                required int at,
                Value<int?> editedOn = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                required int totalPaise,
                Value<int> lineCount = const Value.absent(),
                Value<String?> convertedBillId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstimationsCompanion.insert(
                id: id,
                number: number,
                at: at,
                editedOn: editedOn,
                customerId: customerId,
                customerName: customerName,
                totalPaise: totalPaise,
                lineCount: lineCount,
                convertedBillId: convertedBillId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Estimations, DbEstimation>(table),
                  $EstimationsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({customerId = false, estimationLinesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (estimationLinesRefs) db.estimationLines,
                  ],
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
                        if (customerId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.customerId,
                            referencedTable: $EstimationsReferences
                                ._customerIdTable(db),
                            referencedColumn: $EstimationsReferences
                                ._customerIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (estimationLinesRefs)
                        await $_getPrefetchedData<
                          DbEstimation,
                          Estimations,
                          DbEstimationLine
                        >(
                          currentTable: table,
                          referencedTable: $EstimationsReferences
                              ._estimationLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $EstimationsReferences(
                                db,
                                table,
                                p0,
                              ).estimationLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.estimationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $EstimationsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Estimations,
      DbEstimation,
      $EstimationsFilterComposer,
      $EstimationsOrderingComposer,
      $EstimationsAnnotationComposer,
      $EstimationsCreateCompanionBuilder,
      $EstimationsUpdateCompanionBuilder,
      (DbEstimation, $EstimationsReferences),
      DbEstimation,
      PrefetchHooks Function({bool customerId, bool estimationLinesRefs})
    >;
typedef $EstimationLinesCreateCompanionBuilder =
    EstimationLinesCompanion Function({
      required String id,
      required String estimationId,
      required int lineNo,
      required String productId,
      required String name,
      Value<String> unit,
      required int qtyMilli,
      required int ratePaise,
      Value<int> discountBp,
      Value<int> rowid,
    });
typedef $EstimationLinesUpdateCompanionBuilder =
    EstimationLinesCompanion Function({
      Value<String> id,
      Value<String> estimationId,
      Value<int> lineNo,
      Value<String> productId,
      Value<String> name,
      Value<String> unit,
      Value<int> qtyMilli,
      Value<int> ratePaise,
      Value<int> discountBp,
      Value<int> rowid,
    });

final class $EstimationLinesReferences
    extends BaseReferences<_$AppDatabase, EstimationLines, DbEstimationLine> {
  $EstimationLinesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Estimations _estimationIdTable(_$AppDatabase db) => db.estimations
      .createAlias('estimation_lines__estimation_id__estimations__id');

  $EstimationsProcessedTableManager get estimationId {
    final $_column = $_itemColumn<String>('estimation_id')!;

    final manager = $EstimationsTableManager(
      $_db,
      $_db.estimations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_estimationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Products _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('estimation_lines__product_id__products__id');

  $ProductsProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $ProductsTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $EstimationLinesFilterComposer
    extends Composer<_$AppDatabase, EstimationLines> {
  $EstimationLinesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratePaise => $composableBuilder(
    column: $table.ratePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => ColumnFilters(column),
  );

  $EstimationsFilterComposer get estimationId {
    final $EstimationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.estimationId,
      referencedTable: $db.estimations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationsFilterComposer(
            $db: $db,
            $table: $db.estimations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsFilterComposer get productId {
    final $ProductsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $EstimationLinesOrderingComposer
    extends Composer<_$AppDatabase, EstimationLines> {
  $EstimationLinesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratePaise => $composableBuilder(
    column: $table.ratePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => ColumnOrderings(column),
  );

  $EstimationsOrderingComposer get estimationId {
    final $EstimationsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.estimationId,
      referencedTable: $db.estimations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationsOrderingComposer(
            $db: $db,
            $table: $db.estimations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsOrderingComposer get productId {
    final $ProductsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $EstimationLinesAnnotationComposer
    extends Composer<_$AppDatabase, EstimationLines> {
  $EstimationLinesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineNo =>
      $composableBuilder(column: $table.lineNo, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get qtyMilli =>
      $composableBuilder(column: $table.qtyMilli, builder: (column) => column);

  GeneratedColumn<int> get ratePaise =>
      $composableBuilder(column: $table.ratePaise, builder: (column) => column);

  GeneratedColumn<int> get discountBp => $composableBuilder(
    column: $table.discountBp,
    builder: (column) => column,
  );

  $EstimationsAnnotationComposer get estimationId {
    final $EstimationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.estimationId,
      referencedTable: $db.estimations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $EstimationsAnnotationComposer(
            $db: $db,
            $table: $db.estimations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $ProductsAnnotationComposer get productId {
    final $ProductsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProductsAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $EstimationLinesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          EstimationLines,
          DbEstimationLine,
          $EstimationLinesFilterComposer,
          $EstimationLinesOrderingComposer,
          $EstimationLinesAnnotationComposer,
          $EstimationLinesCreateCompanionBuilder,
          $EstimationLinesUpdateCompanionBuilder,
          (DbEstimationLine, $EstimationLinesReferences),
          DbEstimationLine,
          PrefetchHooks Function({bool estimationId, bool productId})
        > {
  $EstimationLinesTableManager(_$AppDatabase db, EstimationLines table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EstimationLinesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EstimationLinesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EstimationLinesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> estimationId = const Value.absent(),
                Value<int> lineNo = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> qtyMilli = const Value.absent(),
                Value<int> ratePaise = const Value.absent(),
                Value<int> discountBp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstimationLinesCompanion(
                id: id,
                estimationId: estimationId,
                lineNo: lineNo,
                productId: productId,
                name: name,
                unit: unit,
                qtyMilli: qtyMilli,
                ratePaise: ratePaise,
                discountBp: discountBp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String estimationId,
                required int lineNo,
                required String productId,
                required String name,
                Value<String> unit = const Value.absent(),
                required int qtyMilli,
                required int ratePaise,
                Value<int> discountBp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstimationLinesCompanion.insert(
                id: id,
                estimationId: estimationId,
                lineNo: lineNo,
                productId: productId,
                name: name,
                unit: unit,
                qtyMilli: qtyMilli,
                ratePaise: ratePaise,
                discountBp: discountBp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<EstimationLines, DbEstimationLine>(table),
                  $EstimationLinesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({estimationId = false, productId = false}) {
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
                    if (estimationId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.estimationId,
                        referencedTable: $EstimationLinesReferences
                            ._estimationIdTable(db),
                        referencedColumn: $EstimationLinesReferences
                            ._estimationIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (productId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.productId,
                        referencedTable: $EstimationLinesReferences
                            ._productIdTable(db),
                        referencedColumn: $EstimationLinesReferences
                            ._productIdTable(db)
                            .id,
                      ) as T;
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

typedef $EstimationLinesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      EstimationLines,
      DbEstimationLine,
      $EstimationLinesFilterComposer,
      $EstimationLinesOrderingComposer,
      $EstimationLinesAnnotationComposer,
      $EstimationLinesCreateCompanionBuilder,
      $EstimationLinesUpdateCompanionBuilder,
      (DbEstimationLine, $EstimationLinesReferences),
      DbEstimationLine,
      PrefetchHooks Function({bool estimationId, bool productId})
    >;
typedef $LedgerEntriesCreateCompanionBuilder = LedgerEntriesCompanion Function({
  required String id,
  required String partyKind,
  required String partyId,
  required String kind,
  required int amountPaise,
  required int at,
  Value<String?> billNo,
  Value<String> note,
  Value<String> byName,
  Value<String?> mode,
  Value<String?> reverses,
  Value<String> allocations,
  Value<int> runningPaise,
  Value<String?> refId,
  required int createdAt,
  required String deviceId,
  Value<int> rowid,
});
typedef $LedgerEntriesUpdateCompanionBuilder = LedgerEntriesCompanion Function({
  Value<String> id,
  Value<String> partyKind,
  Value<String> partyId,
  Value<String> kind,
  Value<int> amountPaise,
  Value<int> at,
  Value<String?> billNo,
  Value<String> note,
  Value<String> byName,
  Value<String?> mode,
  Value<String?> reverses,
  Value<String> allocations,
  Value<int> runningPaise,
  Value<String?> refId,
  Value<int> createdAt,
  Value<String> deviceId,
  Value<int> rowid,
});

class $LedgerEntriesFilterComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reverses => $composableBuilder(
    column: $table.reverses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runningPaise => $composableBuilder(
    column: $table.runningPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $LedgerEntriesOrderingComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reverses => $composableBuilder(
    column: $table.reverses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runningPaise => $composableBuilder(
    column: $table.runningPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $LedgerEntriesAnnotationComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partyKind =>
      $composableBuilder(column: $table.partyKind, builder: (column) => column);

  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get billNo =>
      $composableBuilder(column: $table.billNo, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get byName =>
      $composableBuilder(column: $table.byName, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get reverses =>
      $composableBuilder(column: $table.reverses, builder: (column) => column);

  GeneratedColumn<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runningPaise => $composableBuilder(
    column: $table.runningPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $LedgerEntriesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          LedgerEntries,
          DbLedgerEntry,
          $LedgerEntriesFilterComposer,
          $LedgerEntriesOrderingComposer,
          $LedgerEntriesAnnotationComposer,
          $LedgerEntriesCreateCompanionBuilder,
          $LedgerEntriesUpdateCompanionBuilder,
          (
            DbLedgerEntry,
            BaseReferences<_$AppDatabase, LedgerEntries, DbLedgerEntry>,
          ),
          DbLedgerEntry,
          PrefetchHooks Function()
        > {
  $LedgerEntriesTableManager(_$AppDatabase db, LedgerEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LedgerEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LedgerEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LedgerEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partyKind = const Value.absent(),
                Value<String> partyId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String?> billNo = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> reverses = const Value.absent(),
                Value<String> allocations = const Value.absent(),
                Value<int> runningPaise = const Value.absent(),
                Value<String?> refId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                kind: kind,
                amountPaise: amountPaise,
                at: at,
                billNo: billNo,
                note: note,
                byName: byName,
                mode: mode,
                reverses: reverses,
                allocations: allocations,
                runningPaise: runningPaise,
                refId: refId,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partyKind,
                required String partyId,
                required String kind,
                required int amountPaise,
                required int at,
                Value<String?> billNo = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<String?> reverses = const Value.absent(),
                Value<String> allocations = const Value.absent(),
                Value<int> runningPaise = const Value.absent(),
                Value<String?> refId = const Value.absent(),
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion.insert(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                kind: kind,
                amountPaise: amountPaise,
                at: at,
                billNo: billNo,
                note: note,
                byName: byName,
                mode: mode,
                reverses: reverses,
                allocations: allocations,
                runningPaise: runningPaise,
                refId: refId,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<LedgerEntries, DbLedgerEntry>(table),
                  BaseReferences<_$AppDatabase, LedgerEntries, DbLedgerEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $LedgerEntriesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      LedgerEntries,
      DbLedgerEntry,
      $LedgerEntriesFilterComposer,
      $LedgerEntriesOrderingComposer,
      $LedgerEntriesAnnotationComposer,
      $LedgerEntriesCreateCompanionBuilder,
      $LedgerEntriesUpdateCompanionBuilder,
      (
        DbLedgerEntry,
        BaseReferences<_$AppDatabase, LedgerEntries, DbLedgerEntry>,
      ),
      DbLedgerEntry,
      PrefetchHooks Function()
    >;
typedef $PaymentsCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String partyKind,
  required String partyId,
  required int amountPaise,
  Value<int> advancePaise,
  Value<String> mode,
  required int at,
  Value<String> note,
  required String receiptNo,
  Value<String> allocations,
  Value<String> byName,
  required int createdAt,
  required String deviceId,
  Value<int> rowid,
});
typedef $PaymentsUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> partyKind,
  Value<String> partyId,
  Value<int> amountPaise,
  Value<int> advancePaise,
  Value<String> mode,
  Value<int> at,
  Value<String> note,
  Value<String> receiptNo,
  Value<String> allocations,
  Value<String> byName,
  Value<int> createdAt,
  Value<String> deviceId,
  Value<int> rowid,
});

class $PaymentsFilterComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get advancePaise => $composableBuilder(
    column: $table.advancePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptNo => $composableBuilder(
    column: $table.receiptNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $PaymentsOrderingComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get advancePaise => $composableBuilder(
    column: $table.advancePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptNo => $composableBuilder(
    column: $table.receiptNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PaymentsAnnotationComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partyKind =>
      $composableBuilder(column: $table.partyKind, builder: (column) => column);

  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get advancePaise => $composableBuilder(
    column: $table.advancePaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get receiptNo =>
      $composableBuilder(column: $table.receiptNo, builder: (column) => column);

  GeneratedColumn<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => column,
  );

  GeneratedColumn<String> get byName =>
      $composableBuilder(column: $table.byName, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $PaymentsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Payments,
          DbPayment,
          $PaymentsFilterComposer,
          $PaymentsOrderingComposer,
          $PaymentsAnnotationComposer,
          $PaymentsCreateCompanionBuilder,
          $PaymentsUpdateCompanionBuilder,
          (DbPayment, BaseReferences<_$AppDatabase, Payments, DbPayment>),
          DbPayment,
          PrefetchHooks Function()
        > {
  $PaymentsTableManager(_$AppDatabase db, Payments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PaymentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PaymentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PaymentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partyKind = const Value.absent(),
                Value<String> partyId = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<int> advancePaise = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> receiptNo = const Value.absent(),
                Value<String> allocations = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                amountPaise: amountPaise,
                advancePaise: advancePaise,
                mode: mode,
                at: at,
                note: note,
                receiptNo: receiptNo,
                allocations: allocations,
                byName: byName,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partyKind,
                required String partyId,
                required int amountPaise,
                Value<int> advancePaise = const Value.absent(),
                Value<String> mode = const Value.absent(),
                required int at,
                Value<String> note = const Value.absent(),
                required String receiptNo,
                Value<String> allocations = const Value.absent(),
                Value<String> byName = const Value.absent(),
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                amountPaise: amountPaise,
                advancePaise: advancePaise,
                mode: mode,
                at: at,
                note: note,
                receiptNo: receiptNo,
                allocations: allocations,
                byName: byName,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Payments, DbPayment>(table),
                  BaseReferences<_$AppDatabase, Payments, DbPayment>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PaymentsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Payments,
      DbPayment,
      $PaymentsFilterComposer,
      $PaymentsOrderingComposer,
      $PaymentsAnnotationComposer,
      $PaymentsCreateCompanionBuilder,
      $PaymentsUpdateCompanionBuilder,
      (DbPayment, BaseReferences<_$AppDatabase, Payments, DbPayment>),
      DbPayment,
      PrefetchHooks Function()
    >;
typedef $PartyBillsCreateCompanionBuilder = PartyBillsCompanion Function({
  required String id,
  required String partyKind,
  required String partyId,
  required String billNo,
  required int date,
  required int totalPaise,
  Value<int> paidPaise,
  Value<int> cancelled,
  Value<int> rowid,
});
typedef $PartyBillsUpdateCompanionBuilder = PartyBillsCompanion Function({
  Value<String> id,
  Value<String> partyKind,
  Value<String> partyId,
  Value<String> billNo,
  Value<int> date,
  Value<int> totalPaise,
  Value<int> paidPaise,
  Value<int> cancelled,
  Value<int> rowid,
});

class $PartyBillsFilterComposer extends Composer<_$AppDatabase, PartyBills> {
  $PartyBillsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidPaise => $composableBuilder(
    column: $table.paidPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnFilters(column),
  );
}

class $PartyBillsOrderingComposer extends Composer<_$AppDatabase, PartyBills> {
  $PartyBillsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billNo => $composableBuilder(
    column: $table.billNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidPaise => $composableBuilder(
    column: $table.paidPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PartyBillsAnnotationComposer
    extends Composer<_$AppDatabase, PartyBills> {
  $PartyBillsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partyKind =>
      $composableBuilder(column: $table.partyKind, builder: (column) => column);

  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<String> get billNo =>
      $composableBuilder(column: $table.billNo, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get totalPaise => $composableBuilder(
    column: $table.totalPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidPaise =>
      $composableBuilder(column: $table.paidPaise, builder: (column) => column);

  GeneratedColumn<int> get cancelled =>
      $composableBuilder(column: $table.cancelled, builder: (column) => column);
}

class $PartyBillsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          PartyBills,
          DbPartyBill,
          $PartyBillsFilterComposer,
          $PartyBillsOrderingComposer,
          $PartyBillsAnnotationComposer,
          $PartyBillsCreateCompanionBuilder,
          $PartyBillsUpdateCompanionBuilder,
          (DbPartyBill, BaseReferences<_$AppDatabase, PartyBills, DbPartyBill>),
          DbPartyBill,
          PrefetchHooks Function()
        > {
  $PartyBillsTableManager(_$AppDatabase db, PartyBills table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PartyBillsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PartyBillsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PartyBillsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partyKind = const Value.absent(),
                Value<String> partyId = const Value.absent(),
                Value<String> billNo = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<int> totalPaise = const Value.absent(),
                Value<int> paidPaise = const Value.absent(),
                Value<int> cancelled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartyBillsCompanion(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                billNo: billNo,
                date: date,
                totalPaise: totalPaise,
                paidPaise: paidPaise,
                cancelled: cancelled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partyKind,
                required String partyId,
                required String billNo,
                required int date,
                required int totalPaise,
                Value<int> paidPaise = const Value.absent(),
                Value<int> cancelled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartyBillsCompanion.insert(
                id: id,
                partyKind: partyKind,
                partyId: partyId,
                billNo: billNo,
                date: date,
                totalPaise: totalPaise,
                paidPaise: paidPaise,
                cancelled: cancelled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PartyBills, DbPartyBill>(table),
                  BaseReferences<_$AppDatabase, PartyBills, DbPartyBill>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PartyBillsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      PartyBills,
      DbPartyBill,
      $PartyBillsFilterComposer,
      $PartyBillsOrderingComposer,
      $PartyBillsAnnotationComposer,
      $PartyBillsCreateCompanionBuilder,
      $PartyBillsUpdateCompanionBuilder,
      (DbPartyBill, BaseReferences<_$AppDatabase, PartyBills, DbPartyBill>),
      DbPartyBill,
      PrefetchHooks Function()
    >;
typedef $PartyBalanceCreateCompanionBuilder = PartyBalanceCompanion Function({
  required String partyId,
  required String partyKind,
  Value<int> balancePaise,
  Value<int?> lastBillAt,
  Value<int?> lastPaymentAt,
  Value<int> entryCount,
  Value<int> rowid,
});
typedef $PartyBalanceUpdateCompanionBuilder = PartyBalanceCompanion Function({
  Value<String> partyId,
  Value<String> partyKind,
  Value<int> balancePaise,
  Value<int?> lastBillAt,
  Value<int?> lastPaymentAt,
  Value<int> entryCount,
  Value<int> rowid,
});

class $PartyBalanceFilterComposer
    extends Composer<_$AppDatabase, PartyBalance> {
  $PartyBalanceFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBillAt => $composableBuilder(
    column: $table.lastBillAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPaymentAt => $composableBuilder(
    column: $table.lastPaymentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $PartyBalanceOrderingComposer
    extends Composer<_$AppDatabase, PartyBalance> {
  $PartyBalanceOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyKind => $composableBuilder(
    column: $table.partyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBillAt => $composableBuilder(
    column: $table.lastBillAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPaymentAt => $composableBuilder(
    column: $table.lastPaymentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PartyBalanceAnnotationComposer
    extends Composer<_$AppDatabase, PartyBalance> {
  $PartyBalanceAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<String> get partyKind =>
      $composableBuilder(column: $table.partyKind, builder: (column) => column);

  GeneratedColumn<int> get balancePaise => $composableBuilder(
    column: $table.balancePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBillAt => $composableBuilder(
    column: $table.lastBillAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPaymentAt => $composableBuilder(
    column: $table.lastPaymentAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => column,
  );
}

class $PartyBalanceTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          PartyBalance,
          DbPartyBalance,
          $PartyBalanceFilterComposer,
          $PartyBalanceOrderingComposer,
          $PartyBalanceAnnotationComposer,
          $PartyBalanceCreateCompanionBuilder,
          $PartyBalanceUpdateCompanionBuilder,
          (
            DbPartyBalance,
            BaseReferences<_$AppDatabase, PartyBalance, DbPartyBalance>,
          ),
          DbPartyBalance,
          PrefetchHooks Function()
        > {
  $PartyBalanceTableManager(_$AppDatabase db, PartyBalance table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PartyBalanceFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PartyBalanceOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PartyBalanceAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> partyId = const Value.absent(),
                Value<String> partyKind = const Value.absent(),
                Value<int> balancePaise = const Value.absent(),
                Value<int?> lastBillAt = const Value.absent(),
                Value<int?> lastPaymentAt = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartyBalanceCompanion(
                partyId: partyId,
                partyKind: partyKind,
                balancePaise: balancePaise,
                lastBillAt: lastBillAt,
                lastPaymentAt: lastPaymentAt,
                entryCount: entryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String partyId,
                required String partyKind,
                Value<int> balancePaise = const Value.absent(),
                Value<int?> lastBillAt = const Value.absent(),
                Value<int?> lastPaymentAt = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartyBalanceCompanion.insert(
                partyId: partyId,
                partyKind: partyKind,
                balancePaise: balancePaise,
                lastBillAt: lastBillAt,
                lastPaymentAt: lastPaymentAt,
                entryCount: entryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PartyBalance, DbPartyBalance>(table),
                  BaseReferences<_$AppDatabase, PartyBalance, DbPartyBalance>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PartyBalanceProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      PartyBalance,
      DbPartyBalance,
      $PartyBalanceFilterComposer,
      $PartyBalanceOrderingComposer,
      $PartyBalanceAnnotationComposer,
      $PartyBalanceCreateCompanionBuilder,
      $PartyBalanceUpdateCompanionBuilder,
      (
        DbPartyBalance,
        BaseReferences<_$AppDatabase, PartyBalance, DbPartyBalance>,
      ),
      DbPartyBalance,
      PrefetchHooks Function()
    >;
typedef $DayTotalsCreateCompanionBuilder = DayTotalsCompanion Function({
  required String day,
  Value<int> bills,
  Value<int> salesPaise,
  Value<int> taxablePaise,
  Value<int> costPaise,
  Value<int> taxPaise,
  Value<int> cashPaise,
  Value<int> upiPaise,
  Value<int> cardPaise,
  Value<int> creditPaise,
  Value<int> cancelledBills,
  Value<int> cancelledPaise,
  Value<int> rowid,
});
typedef $DayTotalsUpdateCompanionBuilder = DayTotalsCompanion Function({
  Value<String> day,
  Value<int> bills,
  Value<int> salesPaise,
  Value<int> taxablePaise,
  Value<int> costPaise,
  Value<int> taxPaise,
  Value<int> cashPaise,
  Value<int> upiPaise,
  Value<int> cardPaise,
  Value<int> creditPaise,
  Value<int> cancelledBills,
  Value<int> cancelledPaise,
  Value<int> rowid,
});

class $DayTotalsFilterComposer extends Composer<_$AppDatabase, DayTotals> {
  $DayTotalsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bills => $composableBuilder(
    column: $table.bills,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get salesPaise => $composableBuilder(
    column: $table.salesPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cashPaise => $composableBuilder(
    column: $table.cashPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upiPaise => $composableBuilder(
    column: $table.upiPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardPaise => $composableBuilder(
    column: $table.cardPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditPaise => $composableBuilder(
    column: $table.creditPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelledBills => $composableBuilder(
    column: $table.cancelledBills,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelledPaise => $composableBuilder(
    column: $table.cancelledPaise,
    builder: (column) => ColumnFilters(column),
  );
}

class $DayTotalsOrderingComposer extends Composer<_$AppDatabase, DayTotals> {
  $DayTotalsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bills => $composableBuilder(
    column: $table.bills,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get salesPaise => $composableBuilder(
    column: $table.salesPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPaise => $composableBuilder(
    column: $table.costPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cashPaise => $composableBuilder(
    column: $table.cashPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upiPaise => $composableBuilder(
    column: $table.upiPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardPaise => $composableBuilder(
    column: $table.cardPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditPaise => $composableBuilder(
    column: $table.creditPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelledBills => $composableBuilder(
    column: $table.cancelledBills,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelledPaise => $composableBuilder(
    column: $table.cancelledPaise,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DayTotalsAnnotationComposer extends Composer<_$AppDatabase, DayTotals> {
  $DayTotalsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get bills =>
      $composableBuilder(column: $table.bills, builder: (column) => column);

  GeneratedColumn<int> get salesPaise => $composableBuilder(
    column: $table.salesPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxablePaise => $composableBuilder(
    column: $table.taxablePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costPaise =>
      $composableBuilder(column: $table.costPaise, builder: (column) => column);

  GeneratedColumn<int> get taxPaise =>
      $composableBuilder(column: $table.taxPaise, builder: (column) => column);

  GeneratedColumn<int> get cashPaise =>
      $composableBuilder(column: $table.cashPaise, builder: (column) => column);

  GeneratedColumn<int> get upiPaise =>
      $composableBuilder(column: $table.upiPaise, builder: (column) => column);

  GeneratedColumn<int> get cardPaise =>
      $composableBuilder(column: $table.cardPaise, builder: (column) => column);

  GeneratedColumn<int> get creditPaise => $composableBuilder(
    column: $table.creditPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cancelledBills => $composableBuilder(
    column: $table.cancelledBills,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cancelledPaise => $composableBuilder(
    column: $table.cancelledPaise,
    builder: (column) => column,
  );
}

class $DayTotalsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          DayTotals,
          DbDayTotal,
          $DayTotalsFilterComposer,
          $DayTotalsOrderingComposer,
          $DayTotalsAnnotationComposer,
          $DayTotalsCreateCompanionBuilder,
          $DayTotalsUpdateCompanionBuilder,
          (DbDayTotal, BaseReferences<_$AppDatabase, DayTotals, DbDayTotal>),
          DbDayTotal,
          PrefetchHooks Function()
        > {
  $DayTotalsTableManager(_$AppDatabase db, DayTotals table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DayTotalsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DayTotalsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DayTotalsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<int> bills = const Value.absent(),
                Value<int> salesPaise = const Value.absent(),
                Value<int> taxablePaise = const Value.absent(),
                Value<int> costPaise = const Value.absent(),
                Value<int> taxPaise = const Value.absent(),
                Value<int> cashPaise = const Value.absent(),
                Value<int> upiPaise = const Value.absent(),
                Value<int> cardPaise = const Value.absent(),
                Value<int> creditPaise = const Value.absent(),
                Value<int> cancelledBills = const Value.absent(),
                Value<int> cancelledPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayTotalsCompanion(
                day: day,
                bills: bills,
                salesPaise: salesPaise,
                taxablePaise: taxablePaise,
                costPaise: costPaise,
                taxPaise: taxPaise,
                cashPaise: cashPaise,
                upiPaise: upiPaise,
                cardPaise: cardPaise,
                creditPaise: creditPaise,
                cancelledBills: cancelledBills,
                cancelledPaise: cancelledPaise,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                Value<int> bills = const Value.absent(),
                Value<int> salesPaise = const Value.absent(),
                Value<int> taxablePaise = const Value.absent(),
                Value<int> costPaise = const Value.absent(),
                Value<int> taxPaise = const Value.absent(),
                Value<int> cashPaise = const Value.absent(),
                Value<int> upiPaise = const Value.absent(),
                Value<int> cardPaise = const Value.absent(),
                Value<int> creditPaise = const Value.absent(),
                Value<int> cancelledBills = const Value.absent(),
                Value<int> cancelledPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayTotalsCompanion.insert(
                day: day,
                bills: bills,
                salesPaise: salesPaise,
                taxablePaise: taxablePaise,
                costPaise: costPaise,
                taxPaise: taxPaise,
                cashPaise: cashPaise,
                upiPaise: upiPaise,
                cardPaise: cardPaise,
                creditPaise: creditPaise,
                cancelledBills: cancelledBills,
                cancelledPaise: cancelledPaise,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<DayTotals, DbDayTotal>(table),
                  BaseReferences<_$AppDatabase, DayTotals, DbDayTotal>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DayTotalsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      DayTotals,
      DbDayTotal,
      $DayTotalsFilterComposer,
      $DayTotalsOrderingComposer,
      $DayTotalsAnnotationComposer,
      $DayTotalsCreateCompanionBuilder,
      $DayTotalsUpdateCompanionBuilder,
      (DbDayTotal, BaseReferences<_$AppDatabase, DayTotals, DbDayTotal>),
      DbDayTotal,
      PrefetchHooks Function()
    >;
typedef $ProductMonthCreateCompanionBuilder = ProductMonthCompanion Function({
  required String productId,
  required String month,
  Value<int> qtyMilli,
  Value<int> amountPaise,
  Value<int> rowid,
});
typedef $ProductMonthUpdateCompanionBuilder = ProductMonthCompanion Function({
  Value<String> productId,
  Value<String> month,
  Value<int> qtyMilli,
  Value<int> amountPaise,
  Value<int> rowid,
});

class $ProductMonthFilterComposer
    extends Composer<_$AppDatabase, ProductMonth> {
  $ProductMonthFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );
}

class $ProductMonthOrderingComposer
    extends Composer<_$AppDatabase, ProductMonth> {
  $ProductMonthOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyMilli => $composableBuilder(
    column: $table.qtyMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProductMonthAnnotationComposer
    extends Composer<_$AppDatabase, ProductMonth> {
  $ProductMonthAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get qtyMilli =>
      $composableBuilder(column: $table.qtyMilli, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );
}

class $ProductMonthTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ProductMonth,
          DbProductMonth,
          $ProductMonthFilterComposer,
          $ProductMonthOrderingComposer,
          $ProductMonthAnnotationComposer,
          $ProductMonthCreateCompanionBuilder,
          $ProductMonthUpdateCompanionBuilder,
          (
            DbProductMonth,
            BaseReferences<_$AppDatabase, ProductMonth, DbProductMonth>,
          ),
          DbProductMonth,
          PrefetchHooks Function()
        > {
  $ProductMonthTableManager(_$AppDatabase db, ProductMonth table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProductMonthFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProductMonthOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProductMonthAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> productId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> qtyMilli = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductMonthCompanion(
                productId: productId,
                month: month,
                qtyMilli: qtyMilli,
                amountPaise: amountPaise,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productId,
                required String month,
                Value<int> qtyMilli = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductMonthCompanion.insert(
                productId: productId,
                month: month,
                qtyMilli: qtyMilli,
                amountPaise: amountPaise,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ProductMonth, DbProductMonth>(table),
                  BaseReferences<_$AppDatabase, ProductMonth, DbProductMonth>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProductMonthProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ProductMonth,
      DbProductMonth,
      $ProductMonthFilterComposer,
      $ProductMonthOrderingComposer,
      $ProductMonthAnnotationComposer,
      $ProductMonthCreateCompanionBuilder,
      $ProductMonthUpdateCompanionBuilder,
      (
        DbProductMonth,
        BaseReferences<_$AppDatabase, ProductMonth, DbProductMonth>,
      ),
      DbProductMonth,
      PrefetchHooks Function()
    >;
typedef $CountersCreateCompanionBuilder = CountersCompanion Function({
  required String name,
  required int value,
  Value<int> rowid,
});
typedef $CountersUpdateCompanionBuilder = CountersCompanion Function({
  Value<String> name,
  Value<int> value,
  Value<int> rowid,
});

class $CountersFilterComposer extends Composer<_$AppDatabase, Counters> {
  $CountersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $CountersOrderingComposer extends Composer<_$AppDatabase, Counters> {
  $CountersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CountersAnnotationComposer extends Composer<_$AppDatabase, Counters> {
  $CountersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $CountersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Counters,
          DbCounter,
          $CountersFilterComposer,
          $CountersOrderingComposer,
          $CountersAnnotationComposer,
          $CountersCreateCompanionBuilder,
          $CountersUpdateCompanionBuilder,
          (DbCounter, BaseReferences<_$AppDatabase, Counters, DbCounter>),
          DbCounter,
          PrefetchHooks Function()
        > {
  $CountersTableManager(_$AppDatabase db, Counters table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CountersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CountersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CountersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CountersCompanion(name: name, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String name,
                required int value,
                Value<int> rowid = const Value.absent(),
              }) => CountersCompanion.insert(
                name: name,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Counters, DbCounter>(table),
                  BaseReferences<_$AppDatabase, Counters, DbCounter>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CountersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Counters,
      DbCounter,
      $CountersFilterComposer,
      $CountersOrderingComposer,
      $CountersAnnotationComposer,
      $CountersCreateCompanionBuilder,
      $CountersUpdateCompanionBuilder,
      (DbCounter, BaseReferences<_$AppDatabase, Counters, DbCounter>),
      DbCounter,
      PrefetchHooks Function()
    >;
typedef $RemindersCreateCompanionBuilder = RemindersCompanion Function({
  required String id,
  required String customerId,
  required int at,
  required int amountDuePaise,
  required String message,
  Value<String> byName,
  required int createdAt,
  required String deviceId,
  Value<int> rowid,
});
typedef $RemindersUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> id,
  Value<String> customerId,
  Value<int> at,
  Value<int> amountDuePaise,
  Value<String> message,
  Value<String> byName,
  Value<int> createdAt,
  Value<String> deviceId,
  Value<int> rowid,
});

final class $RemindersReferences
    extends BaseReferences<_$AppDatabase, Reminders, DbReminder> {
  $RemindersReferences(super.$_db, super.$_table, super.$_typedResult);

  static Customers _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('reminders__customer_id__customers__id');

  $CustomersProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $CustomersTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $RemindersFilterComposer extends Composer<_$AppDatabase, Reminders> {
  $RemindersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountDuePaise => $composableBuilder(
    column: $table.amountDuePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $CustomersFilterComposer get customerId {
    final $CustomersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RemindersOrderingComposer extends Composer<_$AppDatabase, Reminders> {
  $RemindersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountDuePaise => $composableBuilder(
    column: $table.amountDuePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $CustomersOrderingComposer get customerId {
    final $CustomersOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RemindersAnnotationComposer extends Composer<_$AppDatabase, Reminders> {
  $RemindersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get amountDuePaise => $composableBuilder(
    column: $table.amountDuePaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get byName =>
      $composableBuilder(column: $table.byName, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $CustomersAnnotationComposer get customerId {
    final $CustomersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CustomersAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $RemindersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Reminders,
          DbReminder,
          $RemindersFilterComposer,
          $RemindersOrderingComposer,
          $RemindersAnnotationComposer,
          $RemindersCreateCompanionBuilder,
          $RemindersUpdateCompanionBuilder,
          (DbReminder, $RemindersReferences),
          DbReminder,
          PrefetchHooks Function({bool customerId})
        > {
  $RemindersTableManager(_$AppDatabase db, Reminders table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RemindersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RemindersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RemindersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> amountDuePaise = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                customerId: customerId,
                at: at,
                amountDuePaise: amountDuePaise,
                message: message,
                byName: byName,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required int at,
                required int amountDuePaise,
                required String message,
                Value<String> byName = const Value.absent(),
                required int createdAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                customerId: customerId,
                at: at,
                amountDuePaise: amountDuePaise,
                message: message,
                byName: byName,
                createdAt: createdAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Reminders, DbReminder>(table),
                  $RemindersReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({customerId = false}) {
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
                    if (customerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.customerId,
                        referencedTable: $RemindersReferences._customerIdTable(
                          db,
                        ),
                        referencedColumn: $RemindersReferences
                            ._customerIdTable(db)
                            .id,
                      ) as T;
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

typedef $RemindersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Reminders,
      DbReminder,
      $RemindersFilterComposer,
      $RemindersOrderingComposer,
      $RemindersAnnotationComposer,
      $RemindersCreateCompanionBuilder,
      $RemindersUpdateCompanionBuilder,
      (DbReminder, $RemindersReferences),
      DbReminder,
      PrefetchHooks Function({bool customerId})
    >;
typedef $RecordsCreateCompanionBuilder = RecordsCompanion Function({
  required String id,
  required String kind,
  required String data,
  required int at,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});
typedef $RecordsUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> data,
  Value<int> at,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<int> version,
  Value<String> hlc,
  Value<int> rowid,
});

class $RecordsFilterComposer extends Composer<_$AppDatabase, Records> {
  $RecordsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );
}

class $RecordsOrderingComposer extends Composer<_$AppDatabase, Records> {
  $RecordsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $RecordsAnnotationComposer extends Composer<_$AppDatabase, Records> {
  $RecordsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $RecordsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Records,
          DbRecord,
          $RecordsFilterComposer,
          $RecordsOrderingComposer,
          $RecordsAnnotationComposer,
          $RecordsCreateCompanionBuilder,
          $RecordsUpdateCompanionBuilder,
          (DbRecord, BaseReferences<_$AppDatabase, Records, DbRecord>),
          DbRecord,
          PrefetchHooks Function()
        > {
  $RecordsTableManager(_$AppDatabase db, Records table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RecordsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RecordsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RecordsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                kind: kind,
                data: data,
                at: at,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String data,
                required int at,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                kind: kind,
                data: data,
                at: at,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                version: version,
                hlc: hlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Records, DbRecord>(table),
                  BaseReferences<_$AppDatabase, Records, DbRecord>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $RecordsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Records,
      DbRecord,
      $RecordsFilterComposer,
      $RecordsOrderingComposer,
      $RecordsAnnotationComposer,
      $RecordsCreateCompanionBuilder,
      $RecordsUpdateCompanionBuilder,
      (DbRecord, BaseReferences<_$AppDatabase, Records, DbRecord>),
      DbRecord,
      PrefetchHooks Function()
    >;
typedef $OutboxCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String coll,
  required String docId,
  Value<String> op,
  Value<String> stamp,
  Value<String> state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> holdUntil,
  required int createdAt,
});
typedef $OutboxUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> coll,
  Value<String> docId,
  Value<String> op,
  Value<String> stamp,
  Value<String> state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> holdUntil,
  Value<int> createdAt,
});

class $OutboxFilterComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coll => $composableBuilder(
    column: $table.coll,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docId => $composableBuilder(
    column: $table.docId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holdUntil => $composableBuilder(
    column: $table.holdUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $OutboxOrderingComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coll => $composableBuilder(
    column: $table.coll,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docId => $composableBuilder(
    column: $table.docId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdUntil => $composableBuilder(
    column: $table.holdUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $OutboxAnnotationComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get coll =>
      $composableBuilder(column: $table.coll, builder: (column) => column);

  GeneratedColumn<String> get docId =>
      $composableBuilder(column: $table.docId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get holdUntil =>
      $composableBuilder(column: $table.holdUntil, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $OutboxTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Outbox,
          DbOutbox,
          $OutboxFilterComposer,
          $OutboxOrderingComposer,
          $OutboxAnnotationComposer,
          $OutboxCreateCompanionBuilder,
          $OutboxUpdateCompanionBuilder,
          (DbOutbox, BaseReferences<_$AppDatabase, Outbox, DbOutbox>),
          DbOutbox,
          PrefetchHooks Function()
        > {
  $OutboxTableManager(_$AppDatabase db, Outbox table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OutboxFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OutboxOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OutboxAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> coll = const Value.absent(),
                Value<String> docId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> stamp = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> holdUntil = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                coll: coll,
                docId: docId,
                op: op,
                stamp: stamp,
                state: state,
                attempts: attempts,
                lastError: lastError,
                holdUntil: holdUntil,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String coll,
                required String docId,
                Value<String> op = const Value.absent(),
                Value<String> stamp = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> holdUntil = const Value.absent(),
                required int createdAt,
              }) => OutboxCompanion.insert(
                seq: seq,
                coll: coll,
                docId: docId,
                op: op,
                stamp: stamp,
                state: state,
                attempts: attempts,
                lastError: lastError,
                holdUntil: holdUntil,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Outbox, DbOutbox>(table),
                  BaseReferences<_$AppDatabase, Outbox, DbOutbox>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $OutboxProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Outbox,
      DbOutbox,
      $OutboxFilterComposer,
      $OutboxOrderingComposer,
      $OutboxAnnotationComposer,
      $OutboxCreateCompanionBuilder,
      $OutboxUpdateCompanionBuilder,
      (DbOutbox, BaseReferences<_$AppDatabase, Outbox, DbOutbox>),
      DbOutbox,
      PrefetchHooks Function()
    >;
typedef $SyncMetaCreateCompanionBuilder = SyncMetaCompanion Function({
  required String name,
  required String value,
  Value<int> rowid,
});
typedef $SyncMetaUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> name,
  Value<String> value,
  Value<int> rowid,
});

class $SyncMetaFilterComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $SyncMetaOrderingComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SyncMetaAnnotationComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $SyncMetaTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SyncMeta,
          DbSyncMeta,
          $SyncMetaFilterComposer,
          $SyncMetaOrderingComposer,
          $SyncMetaAnnotationComposer,
          $SyncMetaCreateCompanionBuilder,
          $SyncMetaUpdateCompanionBuilder,
          (DbSyncMeta, BaseReferences<_$AppDatabase, SyncMeta, DbSyncMeta>),
          DbSyncMeta,
          PrefetchHooks Function()
        > {
  $SyncMetaTableManager(_$AppDatabase db, SyncMeta table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncMetaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncMetaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncMetaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(name: name, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String name,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                name: name,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncMeta, DbSyncMeta>(table),
                  BaseReferences<_$AppDatabase, SyncMeta, DbSyncMeta>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SyncMetaProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SyncMeta,
      DbSyncMeta,
      $SyncMetaFilterComposer,
      $SyncMetaOrderingComposer,
      $SyncMetaAnnotationComposer,
      $SyncMetaCreateCompanionBuilder,
      $SyncMetaUpdateCompanionBuilder,
      (DbSyncMeta, BaseReferences<_$AppDatabase, SyncMeta, DbSyncMeta>),
      DbSyncMeta,
      PrefetchHooks Function()
    >;
typedef $AuditCreateCompanionBuilder = AuditCompanion Function({
  required String id,
  required String what,
  required String entity,
  required String entityId,
  required String field,
  Value<String?> oldValue,
  Value<String?> newValue,
  Value<String> byName,
  required int at,
  required String deviceId,
  Value<int> rowid,
});
typedef $AuditUpdateCompanionBuilder = AuditCompanion Function({
  Value<String> id,
  Value<String> what,
  Value<String> entity,
  Value<String> entityId,
  Value<String> field,
  Value<String?> oldValue,
  Value<String?> newValue,
  Value<String> byName,
  Value<int> at,
  Value<String> deviceId,
  Value<int> rowid,
});

class $AuditFilterComposer extends Composer<_$AppDatabase, Audit> {
  $AuditFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get what => $composableBuilder(
    column: $table.what,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $AuditOrderingComposer extends Composer<_$AppDatabase, Audit> {
  $AuditOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get what => $composableBuilder(
    column: $table.what,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byName => $composableBuilder(
    column: $table.byName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AuditAnnotationComposer extends Composer<_$AppDatabase, Audit> {
  $AuditAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get what =>
      $composableBuilder(column: $table.what, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<String> get byName =>
      $composableBuilder(column: $table.byName, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $AuditTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Audit,
          DbAudit,
          $AuditFilterComposer,
          $AuditOrderingComposer,
          $AuditAnnotationComposer,
          $AuditCreateCompanionBuilder,
          $AuditUpdateCompanionBuilder,
          (DbAudit, BaseReferences<_$AppDatabase, Audit, DbAudit>),
          DbAudit,
          PrefetchHooks Function()
        > {
  $AuditTableManager(_$AppDatabase db, Audit table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AuditFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AuditOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AuditAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> what = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<String> byName = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditCompanion(
                id: id,
                what: what,
                entity: entity,
                entityId: entityId,
                field: field,
                oldValue: oldValue,
                newValue: newValue,
                byName: byName,
                at: at,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String what,
                required String entity,
                required String entityId,
                required String field,
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<String> byName = const Value.absent(),
                required int at,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => AuditCompanion.insert(
                id: id,
                what: what,
                entity: entity,
                entityId: entityId,
                field: field,
                oldValue: oldValue,
                newValue: newValue,
                byName: byName,
                at: at,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Audit, DbAudit>(table),
                  BaseReferences<_$AppDatabase, Audit, DbAudit>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AuditProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Audit,
      DbAudit,
      $AuditFilterComposer,
      $AuditOrderingComposer,
      $AuditAnnotationComposer,
      $AuditCreateCompanionBuilder,
      $AuditUpdateCompanionBuilder,
      (DbAudit, BaseReferences<_$AppDatabase, Audit, DbAudit>),
      DbAudit,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $KvTableManager get kv => $KvTableManager(_db, _db.kv);
  $CategoriesTableManager get categories =>
      $CategoriesTableManager(_db, _db.categories);
  $ProductsTableManager get products =>
      $ProductsTableManager(_db, _db.products);
  $ProductFtsTableManager get productFts =>
      $ProductFtsTableManager(_db, _db.productFts);
  $CustomersTableManager get customers =>
      $CustomersTableManager(_db, _db.customers);
  $DealersTableManager get dealers => $DealersTableManager(_db, _db.dealers);
  $StockMovementsTableManager get stockMovements =>
      $StockMovementsTableManager(_db, _db.stockMovements);
  $StockCacheTableManager get stockCache =>
      $StockCacheTableManager(_db, _db.stockCache);
  $BillsTableManager get bills => $BillsTableManager(_db, _db.bills);
  $BillLinesTableManager get billLines =>
      $BillLinesTableManager(_db, _db.billLines);
  $BillCancellationsTableManager get billCancellations =>
      $BillCancellationsTableManager(_db, _db.billCancellations);
  $EstimationsTableManager get estimations =>
      $EstimationsTableManager(_db, _db.estimations);
  $EstimationLinesTableManager get estimationLines =>
      $EstimationLinesTableManager(_db, _db.estimationLines);
  $LedgerEntriesTableManager get ledgerEntries =>
      $LedgerEntriesTableManager(_db, _db.ledgerEntries);
  $PaymentsTableManager get payments =>
      $PaymentsTableManager(_db, _db.payments);
  $PartyBillsTableManager get partyBills =>
      $PartyBillsTableManager(_db, _db.partyBills);
  $PartyBalanceTableManager get partyBalance =>
      $PartyBalanceTableManager(_db, _db.partyBalance);
  $DayTotalsTableManager get dayTotals =>
      $DayTotalsTableManager(_db, _db.dayTotals);
  $ProductMonthTableManager get productMonth =>
      $ProductMonthTableManager(_db, _db.productMonth);
  $CountersTableManager get counters =>
      $CountersTableManager(_db, _db.counters);
  $RemindersTableManager get reminders =>
      $RemindersTableManager(_db, _db.reminders);
  $RecordsTableManager get records => $RecordsTableManager(_db, _db.records);
  $OutboxTableManager get outbox => $OutboxTableManager(_db, _db.outbox);
  $SyncMetaTableManager get syncMeta =>
      $SyncMetaTableManager(_db, _db.syncMeta);
  $AuditTableManager get audit => $AuditTableManager(_db, _db.audit);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_reminder_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMedicationReminderModelCollection on Isar {
  IsarCollection<MedicationReminderModel> get medicationReminderModels =>
      this.collection();
}

const MedicationReminderModelSchema = CollectionSchema(
  name: r'MedicationReminderModel',
  id: 2250329537037263535,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'dosage': PropertySchema(
      id: 1,
      name: r'dosage',
      type: IsarType.string,
    ),
    r'endDate': PropertySchema(
      id: 2,
      name: r'endDate',
      type: IsarType.dateTime,
    ),
    r'isActive': PropertySchema(
      id: 3,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'lastSnoozedAt': PropertySchema(
      id: 4,
      name: r'lastSnoozedAt',
      type: IsarType.dateTime,
    ),
    r'lastTakenAt': PropertySchema(
      id: 5,
      name: r'lastTakenAt',
      type: IsarType.dateTime,
    ),
    r'medicineName': PropertySchema(
      id: 6,
      name: r'medicineName',
      type: IsarType.string,
    ),
    r'notes': PropertySchema(
      id: 7,
      name: r'notes',
      type: IsarType.string,
    ),
    r'notificationIds': PropertySchema(
      id: 8,
      name: r'notificationIds',
      type: IsarType.longList,
    ),
    r'owner': PropertySchema(
      id: 9,
      name: r'owner',
      type: IsarType.object,
      target: r'ReminderOwnerEmbedded',
    ),
    r'route': PropertySchema(
      id: 10,
      name: r'route',
      type: IsarType.string,
    ),
    r'saveToHealthRecord': PropertySchema(
      id: 11,
      name: r'saveToHealthRecord',
      type: IsarType.bool,
    ),
    r'startDate': PropertySchema(
      id: 12,
      name: r'startDate',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(
      id: 13,
      name: r'status',
      type: IsarType.string,
    ),
    r'times': PropertySchema(
      id: 14,
      name: r'times',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 15,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _medicationReminderModelEstimateSize,
  serialize: _medicationReminderModelSerialize,
  deserialize: _medicationReminderModelDeserialize,
  deserializeProp: _medicationReminderModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'medicineName': IndexSchema(
      id: 819219057635901769,
      name: r'medicineName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'medicineName',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {r'ReminderOwnerEmbedded': ReminderOwnerEmbeddedSchema},
  getId: _medicationReminderModelGetId,
  getLinks: _medicationReminderModelGetLinks,
  attach: _medicationReminderModelAttach,
  version: '3.1.0+1',
);

int _medicationReminderModelEstimateSize(
  MedicationReminderModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.dosage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.medicineName.length * 3;
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.notificationIds.length * 8;
  bytesCount += 3 +
      ReminderOwnerEmbeddedSchema.estimateSize(
          object.owner, allOffsets[ReminderOwnerEmbedded]!, allOffsets);
  {
    final value = object.route;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.times.length * 3;
  {
    for (var i = 0; i < object.times.length; i++) {
      final value = object.times[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _medicationReminderModelSerialize(
  MedicationReminderModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.dosage);
  writer.writeDateTime(offsets[2], object.endDate);
  writer.writeBool(offsets[3], object.isActive);
  writer.writeDateTime(offsets[4], object.lastSnoozedAt);
  writer.writeDateTime(offsets[5], object.lastTakenAt);
  writer.writeString(offsets[6], object.medicineName);
  writer.writeString(offsets[7], object.notes);
  writer.writeLongList(offsets[8], object.notificationIds);
  writer.writeObject<ReminderOwnerEmbedded>(
    offsets[9],
    allOffsets,
    ReminderOwnerEmbeddedSchema.serialize,
    object.owner,
  );
  writer.writeString(offsets[10], object.route);
  writer.writeBool(offsets[11], object.saveToHealthRecord);
  writer.writeDateTime(offsets[12], object.startDate);
  writer.writeString(offsets[13], object.status);
  writer.writeStringList(offsets[14], object.times);
  writer.writeDateTime(offsets[15], object.updatedAt);
}

MedicationReminderModel _medicationReminderModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MedicationReminderModel();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.dosage = reader.readStringOrNull(offsets[1]);
  object.endDate = reader.readDateTimeOrNull(offsets[2]);
  object.id = id;
  object.lastSnoozedAt = reader.readDateTimeOrNull(offsets[4]);
  object.lastTakenAt = reader.readDateTimeOrNull(offsets[5]);
  object.medicineName = reader.readString(offsets[6]);
  object.notes = reader.readStringOrNull(offsets[7]);
  object.notificationIds = reader.readLongList(offsets[8]) ?? [];
  object.owner = reader.readObjectOrNull<ReminderOwnerEmbedded>(
        offsets[9],
        ReminderOwnerEmbeddedSchema.deserialize,
        allOffsets,
      ) ??
      ReminderOwnerEmbedded();
  object.route = reader.readStringOrNull(offsets[10]);
  object.saveToHealthRecord = reader.readBool(offsets[11]);
  object.startDate = reader.readDateTime(offsets[12]);
  object.status = reader.readString(offsets[13]);
  object.times = reader.readStringList(offsets[14]) ?? [];
  object.updatedAt = reader.readDateTimeOrNull(offsets[15]);
  return object;
}

P _medicationReminderModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLongList(offset) ?? []) as P;
    case 9:
      return (reader.readObjectOrNull<ReminderOwnerEmbedded>(
            offset,
            ReminderOwnerEmbeddedSchema.deserialize,
            allOffsets,
          ) ??
          ReminderOwnerEmbedded()) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readDateTime(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readStringList(offset) ?? []) as P;
    case 15:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _medicationReminderModelGetId(MedicationReminderModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _medicationReminderModelGetLinks(
    MedicationReminderModel object) {
  return [];
}

void _medicationReminderModelAttach(
    IsarCollection<dynamic> col, Id id, MedicationReminderModel object) {
  object.id = id;
}

extension MedicationReminderModelQueryWhereSort
    on QueryBuilder<MedicationReminderModel, MedicationReminderModel, QWhere> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MedicationReminderModelQueryWhere on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QWhereClause> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> medicineNameEqualTo(String medicineName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'medicineName',
        value: [medicineName],
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> medicineNameNotEqualTo(String medicineName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'medicineName',
              lower: [],
              upper: [medicineName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'medicineName',
              lower: [medicineName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'medicineName',
              lower: [medicineName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'medicineName',
              lower: [],
              upper: [medicineName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> statusEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterWhereClause> statusNotEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MedicationReminderModelQueryFilter on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QFilterCondition> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dosage',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dosage',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dosage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      dosageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dosage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      dosageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dosage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dosage',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> dosageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dosage',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'endDate',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'endDate',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> endDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSnoozedAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSnoozedAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSnoozedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSnoozedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSnoozedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastSnoozedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSnoozedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastTakenAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastTakenAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTakenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastTakenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastTakenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> lastTakenAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastTakenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'medicineName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      medicineNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'medicineName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      medicineNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'medicineName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'medicineName',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> medicineNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'medicineName',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notificationIds',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notificationIds',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notificationIds',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notificationIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> notificationIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'notificationIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'route',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'route',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'route',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      routeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'route',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      routeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'route',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'route',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> routeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'route',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> saveToHealthRecordEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'saveToHealthRecord',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> startDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> startDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> startDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> startDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'times',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      timesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'times',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
          QAfterFilterCondition>
      timesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'times',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'times',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'times',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> timesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'times',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MedicationReminderModelQueryObject on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QFilterCondition> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel,
      QAfterFilterCondition> owner(FilterQuery<ReminderOwnerEmbedded> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'owner');
    });
  }
}

extension MedicationReminderModelQueryLinks on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QFilterCondition> {}

extension MedicationReminderModelQuerySortBy
    on QueryBuilder<MedicationReminderModel, MedicationReminderModel, QSortBy> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByDosage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByDosageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByLastSnoozedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnoozedAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByLastSnoozedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnoozedAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByLastTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTakenAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByLastTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTakenAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByMedicineName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'medicineName', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByMedicineNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'medicineName', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByRoute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByRouteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortBySaveToHealthRecord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saveToHealthRecord', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortBySaveToHealthRecordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saveToHealthRecord', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MedicationReminderModelQuerySortThenBy on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QSortThenBy> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByDosage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByDosageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dosage', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByLastSnoozedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnoozedAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByLastSnoozedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnoozedAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByLastTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTakenAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByLastTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTakenAt', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByMedicineName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'medicineName', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByMedicineNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'medicineName', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByRoute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByRouteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenBySaveToHealthRecord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saveToHealthRecord', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenBySaveToHealthRecordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saveToHealthRecord', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MedicationReminderModelQueryWhereDistinct on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QDistinct> {
  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByDosage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dosage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endDate');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByLastSnoozedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSnoozedAt');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByLastTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastTakenAt');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByMedicineName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'medicineName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByNotificationIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notificationIds');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByRoute({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'route', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctBySaveToHealthRecord() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'saveToHealthRecord');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startDate');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByTimes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'times');
    });
  }

  QueryBuilder<MedicationReminderModel, MedicationReminderModel, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension MedicationReminderModelQueryProperty on QueryBuilder<
    MedicationReminderModel, MedicationReminderModel, QQueryProperty> {
  QueryBuilder<MedicationReminderModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MedicationReminderModel, String?, QQueryOperations>
      dosageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dosage');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime?, QQueryOperations>
      endDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endDate');
    });
  }

  QueryBuilder<MedicationReminderModel, bool, QQueryOperations>
      isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime?, QQueryOperations>
      lastSnoozedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSnoozedAt');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime?, QQueryOperations>
      lastTakenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastTakenAt');
    });
  }

  QueryBuilder<MedicationReminderModel, String, QQueryOperations>
      medicineNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'medicineName');
    });
  }

  QueryBuilder<MedicationReminderModel, String?, QQueryOperations>
      notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<MedicationReminderModel, List<int>, QQueryOperations>
      notificationIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notificationIds');
    });
  }

  QueryBuilder<MedicationReminderModel, ReminderOwnerEmbedded, QQueryOperations>
      ownerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner');
    });
  }

  QueryBuilder<MedicationReminderModel, String?, QQueryOperations>
      routeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'route');
    });
  }

  QueryBuilder<MedicationReminderModel, bool, QQueryOperations>
      saveToHealthRecordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'saveToHealthRecord');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime, QQueryOperations>
      startDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startDate');
    });
  }

  QueryBuilder<MedicationReminderModel, String, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<MedicationReminderModel, List<String>, QQueryOperations>
      timesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'times');
    });
  }

  QueryBuilder<MedicationReminderModel, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

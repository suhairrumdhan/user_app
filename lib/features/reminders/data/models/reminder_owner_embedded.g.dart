// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_owner_embedded.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const ReminderOwnerEmbeddedSchema = Schema(
  name: r'ReminderOwnerEmbedded',
  id: -5228880097712440067,
  properties: {
    r'beneficiaryId': PropertySchema(
      id: 0,
      name: r'beneficiaryId',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    ),
    r'relation': PropertySchema(
      id: 2,
      name: r'relation',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 3,
      name: r'type',
      type: IsarType.string,
    )
  },
  estimateSize: _reminderOwnerEmbeddedEstimateSize,
  serialize: _reminderOwnerEmbeddedSerialize,
  deserialize: _reminderOwnerEmbeddedDeserialize,
  deserializeProp: _reminderOwnerEmbeddedDeserializeProp,
);

int _reminderOwnerEmbeddedEstimateSize(
  ReminderOwnerEmbedded object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.beneficiaryId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.relation.length * 3;
  bytesCount += 3 + object.type.length * 3;
  return bytesCount;
}

void _reminderOwnerEmbeddedSerialize(
  ReminderOwnerEmbedded object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.beneficiaryId);
  writer.writeString(offsets[1], object.name);
  writer.writeString(offsets[2], object.relation);
  writer.writeString(offsets[3], object.type);
}

ReminderOwnerEmbedded _reminderOwnerEmbeddedDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReminderOwnerEmbedded();
  object.beneficiaryId = reader.readString(offsets[0]);
  object.name = reader.readString(offsets[1]);
  object.relation = reader.readString(offsets[2]);
  object.type = reader.readString(offsets[3]);
  return object;
}

P _reminderOwnerEmbeddedDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension ReminderOwnerEmbeddedQueryFilter on QueryBuilder<
    ReminderOwnerEmbedded, ReminderOwnerEmbedded, QFilterCondition> {
  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'beneficiaryId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      beneficiaryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'beneficiaryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      beneficiaryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'beneficiaryId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beneficiaryId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> beneficiaryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'beneficiaryId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      relationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      relationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> relationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      typeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
          QAfterFilterCondition>
      typeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'type',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<ReminderOwnerEmbedded, ReminderOwnerEmbedded,
      QAfterFilterCondition> typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'type',
        value: '',
      ));
    });
  }
}

extension ReminderOwnerEmbeddedQueryObject on QueryBuilder<
    ReminderOwnerEmbedded, ReminderOwnerEmbedded, QFilterCondition> {}

import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/insurance/models/insurance_model.dart';

void main() {
  test('new insurance document belongs to exactly one beneficiary', () {
    final model = InsuranceModel.fromMap('child-1', {
      'companyCode': 'C1',
      'companyName': 'Company One',
      'policyNumber': 'POLICY-CHILD-1',
      'beneficiaryId': 'child-1',
      'beneficiaryType': 'family',
      'beneficiaryName': 'Child One',
      'coveredMemberIds': ['child-1'],
    });

    expect(model.beneficiaryId, 'child-1');
    expect(model.cardNumber, 'POLICY-CHILD-1');
    expect(model.coveredMemberIds, ['child-1']);

    final map = model.toMap();
    expect(map['policyNumber'], 'POLICY-CHILD-1');
    expect(map['beneficiaryId'], 'child-1');
    expect(map['coveredMemberIds'], ['child-1']);
  });

  test('single-beneficiary legacy document remains readable', () {
    final model = InsuranceModel.fromMap('legacy', {
      'companyCode': 'C2',
      'companyName': 'Company Two',
      'cardNumber': 'OLD-CARD',
      'coveredMemberIds': ['self'],
    });

    expect(model.beneficiaryId, 'self');
    expect(model.beneficiaryType, 'self');
    expect(model.cardNumber, 'OLD-CARD');
  });
}

import 'package:cqmu_cwc/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('登录返回解析 fullEmployee.extend.emplId 并可持久化往返', () {
    final CwcSession session = CwcSession.fromLogin(<String, dynamic>{
      'accessToken': 't',
      'userId': 'U1',
      'userNo': '2026001',
      'fullEmployee': <String, dynamic>{
        'extend': <String, dynamic>{'emplId': 'E1'},
      },
    });

    expect(session.emplId, 'E1');
    expect(CwcSession.tryDecode(session.encode())?.emplId, 'E1');
    expect(
      CwcSession.fromLogin(<String, dynamic>{
        'accessToken': 't',
        'userId': 'U2',
      }).emplId,
      '',
    );
  });
}

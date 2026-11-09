import 'package:cqmu_cwc/services/cwc_client.dart';
import 'package:cqmu_cwc/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('密码使用 AES-128-ECB/PKCS7 + Base64', () {
    expect(encryptPassword('test123'), 'Cu2rdd4Gy8U3cOkDPJEXzg==');
  });

  test('每次图形验证码 token 为 32 位', () {
    final String token = randomToken();
    expect(token.length, 32);
    expect(RegExp(r'^[a-z0-9]+$').hasMatch(token), isTrue);
  });
}

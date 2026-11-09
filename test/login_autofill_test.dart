import 'dart:convert';

import 'package:cqmu_cwc/pages/login_page.dart';
import 'package:cqmu_cwc/services/app_state.dart';
import 'package:cqmu_cwc/services/cwc_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Map<String, Object> body) => http.Response(
  jsonEncode(body),
  200,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('已保存三要素时自动填充、发送验证码并聚焦验证码框', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cwc_last_userno': '2026001',
      'cwc_last_password': 'secret',
      'cwc_last_openid': 'OPENID',
    });

    int sends = 0;
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path == '/employee/sendLoginCode') {
        sends++;
        return _json(<String, Object>{
          'status': 'SUCCESS',
          'message': '操作成功',
          'data': '138****0000',
        });
      }
      return _json(<String, Object>{
        'status': 'FAIL',
        'message': '未实现',
        'data': '',
      });
    });

    final AppState app = AppState(client: CwcClient(client: client));
    await tester.pumpWidget(MaterialApp(home: LoginPage(app: app)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sends, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('login-userno')))
          .controller!
          .text,
      '2026001',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('login-password')))
          .controller!
          .text,
      'secret',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('login-openid')))
          .controller!
          .text,
      'OPENID',
    );
    expect(find.textContaining('验证码已发送至 138****0000'), findsOneWidget);
    expect(find.textContaining('后重发'), findsOneWidget);

    final EditableText code = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login-logincode')),
        matching: find.byType(EditableText),
      ),
    );
    expect(code.focusNode.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

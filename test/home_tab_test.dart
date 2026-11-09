import 'dart:convert';

import 'package:cqmu_cwc/models/session.dart';
import 'package:cqmu_cwc/pages/home_page.dart';
import 'package:cqmu_cwc/services/app_state.dart';
import 'package:cqmu_cwc/services/cwc_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Object? data) => http.Response(
  jsonEncode(<String, Object?>{
    'status': 'SUCCESS',
    'message': '操作成功',
    'data': data,
  }),
  200,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('首页默认展示电子卡余额、状态与账户号', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    final AppState app = AppState(
      client: CwcClient(
        client: MockClient((http.Request request) async {
          calls.add(request.url.path);
          if (request.url.path == '/eaccount/info') {
            return _ok(<String, Object?>{
              'eaccountId': '226843',
              'empId': 'U1',
              'eaccountValue': 22.98,
              'eaccountValue1': 0.0,
              'eaccountValue2': 0.0,
              'eaccountStatus': '正常',
            });
          }
          return _ok(null);
        }),
      ),
    )..session = const CwcSession(
        accessToken: 'token',
        userId: 'U1',
        userNo: '2026001',
        userName: '测试用户',
      );

    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(calls, contains('/eaccount/info'));
    expect(calls, isNot(contains('/employee/account')));
    expect(find.text('电子卡余额'), findsOneWidget);
    expect(find.text('¥ 22.98'), findsOneWidget);
    expect(find.text('状态 正常'), findsOneWidget);
    expect(find.text('账户号 226843'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

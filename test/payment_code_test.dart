import 'dart:convert';

import 'package:cqmu_cwc/models/session.dart';
import 'package:cqmu_cwc/pages/home_page.dart';
import 'package:cqmu_cwc/pages/payment_code_page.dart';
import 'package:cqmu_cwc/services/app_state.dart';
import 'package:cqmu_cwc/services/cwc_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const CwcSession _session = CwcSession(
  accessToken: 'token-1',
  userId: 'U1',
  emplId: 'E1',
  userNo: '2026001',
  userName: '测试用户',
);

http.Response _ok(Object? data) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'status': 'SUCCESS',
      'message': '',
      'data': data,
    }),
    200,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

AppState _app(Future<http.Response> Function(http.Request) handler) {
  return AppState(client: CwcClient(client: MockClient(handler)))
    ..session = _session;
}

Future<void> _pumpPage(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(MaterialApp(home: PaymentCodePage(app: app)));
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('额度校验通过后取码并展示二维码与倒计时', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    final Map<String, String> bodies = <String, String>{};
    final AppState app = _app((http.Request request) async {
      calls.add(request.url.path);
      bodies[request.url.path] = request.body;
      return switch (request.url.path) {
        '/eaccount/pay/check' => _ok(<String, Object?>{'over': false}),
        '/eaccount/transKey' => _ok('PAY-CODE-A'),
        _ => _ok(<String, Object?>{'isPay': '未使用'}),
      };
    });

    await _pumpPage(tester, app);

    expect(calls, <String>['/eaccount/pay/check', '/eaccount/transKey']);
    expect(
      Uri.splitQueryString(bodies['/eaccount/pay/check']!),
      <String, String>{'empId': 'E1'},
    );
    expect(
      Uri.splitQueryString(bodies['/eaccount/transKey']!),
      <String, String>{'empId': 'E1'},
    );
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);
    expect(find.text('60 秒后自动刷新'), findsOneWidget);
    expect(find.text('测试用户'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('消费超限时要求密码，校验通过后继续取码', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    Map<String, String> passwordParams = <String, String>{};
    final AppState app = _app((http.Request request) async {
      calls.add(request.url.path);
      switch (request.url.path) {
        case '/eaccount/pay/check':
          return _ok(<String, Object?>{'over': true});
        case '/employee/check':
          passwordParams = Uri.splitQueryString(request.body);
          return _ok(null);
        case '/eaccount/transKey':
          return _ok('PAY-CODE-B');
      }
      return _ok(<String, Object?>{'isPay': '未使用'});
    });

    await _pumpPage(tester, app);
    expect(find.text('消费超限'), findsOneWidget);
    expect(find.text('请输入登录密码后继续。'), findsOneWidget);
    expect(calls, <String>['/eaccount/pay/check']);

    await tester.enterText(find.byKey(const Key('payment-password')), 'secret123');
    await tester.pump();
    await tester.tap(find.byKey(const Key('payment-password-ok')));
    await tester.pump();
    await _pumpAsync(tester);

    expect(passwordParams['empId'], 'E1');
    expect(passwordParams['pwd'], 'secret123');
    expect(
      calls,
      <String>['/eaccount/pay/check', '/employee/check', '/eaccount/transKey'],
    );
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('轮询到已使用后弹出支付成功，关闭后重新取码', (WidgetTester tester) async {
    int transKeyCount = 0;
    final AppState app = _app((http.Request request) async {
      switch (request.url.path) {
        case '/eaccount/pay/check':
          return _ok(<String, Object?>{'over': false});
        case '/eaccount/transKey':
          transKeyCount++;
          return _ok('PAY-CODE-$transKeyCount');
        case '/eaccount/transKey/result':
          return _ok(<String, Object?>{
            'isPay': '已使用',
            'amount': '3.50',
            'payDate': '2026-11-09 18:00:00',
            'marketName': '一食堂',
            'accountValue': '12.00',
            'walletId': 0,
          });
      }
      return _ok(null);
    });

    await _pumpPage(tester, app);
    expect(transKeyCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await _pumpAsync(tester);

    expect(find.text('支付成功'), findsOneWidget);
    expect(find.text('¥3.50'), findsOneWidget);
    expect(find.text('一食堂'), findsOneWidget);
    expect(find.text('2026-11-09 18:00:00'), findsOneWidget);
    expect(find.text('电子卡余额'), findsOneWidget);
    expect(find.text('¥12.00'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pump();
    await _pumpAsync(tester);
    expect(transKeyCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('二维码过期后自动重新取码', (WidgetTester tester) async {
    int transKeyCount = 0;
    int resultCount = 0;
    final AppState app = _app((http.Request request) async {
      switch (request.url.path) {
        case '/eaccount/pay/check':
          return _ok(<String, Object?>{'over': false});
        case '/eaccount/transKey':
          transKeyCount++;
          return _ok('PAY-CODE-$transKeyCount');
        case '/eaccount/transKey/result':
          resultCount++;
          return _ok(<String, Object?>{
            'isPay': resultCount == 1 ? '二维码已过期' : '未使用',
          });
      }
      return _ok(null);
    });

    await _pumpPage(tester, app);
    expect(transKeyCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await _pumpAsync(tester);

    expect(resultCount, 1);
    expect(transKeyCount, 2);
    expect(find.text('60 秒后自动刷新'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('主界面右上角与导航栏中间都有付款码入口', (WidgetTester tester) async {
    final AppState app = _app((http.Request request) async => _ok(null));
    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    await _pumpAsync(tester);

    expect(find.byKey(const Key('home-payment-code')), findsOneWidget);
    expect(find.byKey(const Key('home-payment-code-fab')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-payment-code')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpAsync(tester);
    expect(find.byType(PaymentCodePage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

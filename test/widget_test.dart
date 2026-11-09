import 'package:cqmu_cwc/app.dart';
import 'package:cqmu_cwc/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('未登录时显示登录页与四个输入框', (WidgetTester tester) async {
    await tester.pumpWidget(const CwcApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('重医一卡通'), findsWidgets);
    expect(find.byKey(const Key('login-userno')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.byKey(const Key('login-openid')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('缺少字段时提示，不发请求', (WidgetTester tester) async {
    await tester.pumpWidget(const CwcApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('请填写学号、密码和微信 OpenID'), findsOneWidget);
  });
}

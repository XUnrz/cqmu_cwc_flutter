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

const CwcSession _session = CwcSession(
  accessToken: 'token-1',
  userId: 'U1',
  emplId: 'E1',
  userNo: '2026001',
  userName: '测试用户',
);

Future<void> _pumpAsync(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('水控选项卡按需加载房间与最近设备', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    final AppState app = AppState(
      client: CwcClient(
        client: MockClient((http.Request request) async {
          calls.add(request.url.path);
          return switch (request.url.path) {
            '/eaccount/info' => _ok(<String, Object?>{
              'eaccountValue': 22.98,
              'eaccountStatus': '正常',
            }),
            '/water/getEmployeeRoom' => _ok(<String, Object?>{
              'roomName': '1栋101',
              'roomNo': '1101',
              'deviceno': 'DEV-DORM',
            }),
            '/water/water4G/getLatestDeviceNo' => _ok('DEV-001'),
            _ => _ok(null),
          };
        }),
      ),
    )..session = _session;

    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    await _pumpAsync(tester);

    expect(find.text('水控'), findsOneWidget);
    expect(calls, isNot(contains('/water/getEmployeeRoom')));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('水控'),
      ),
    );
    await _pumpAsync(tester);

    expect(calls, contains('/water/getEmployeeRoom'));
    expect(calls, contains('/water/water4G/getLatestDeviceNo'));
    expect(find.text('1栋101'), findsOneWidget);
    expect(find.text('默认设备：DEV-DORM'), findsOneWidget);
    expect(find.text('最近使用：DEV-001'), findsOneWidget);
    expect(find.text('扫码用水'), findsOneWidget);
    expect(find.text('用水订单'), findsOneWidget);
    expect(find.text('绑定设备'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('扫码用水开阀后可以关阀并等待订单', (WidgetTester tester) async {
    final Map<String, String> bodies = <String, String>{};
    final AppState app = AppState(
      client: CwcClient(
        client: MockClient((http.Request request) async {
          bodies[request.url.path] = request.body;
          return switch (request.url.path) {
            '/water/getEmployeeRoom' => _ok(<String, Object?>{
              'roomName': '1栋101',
              'roomNo': '1101',
              'deviceno': 'DEV-DORM',
            }),
            '/water/water4G/getLatestDeviceNo' => _ok('DEV-001'),
            '/water/water4G/scanning' => _ok(<String, Object?>{
              'id': 965000,
              'orderSn': '20261109201958039430',
              'freeznamount': 10.0,
            }),
            '/water/water4G/createorderissuccess' => _ok('1'),
            '/water/water4G/activesetttleaccounts' => _ok('结算成功'),
            _ => _ok(null),
          };
        }),
      ),
    )..session = _session;

    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    await _pumpAsync(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('水控'),
      ),
    );
    await _pumpAsync(tester);

    await tester.tap(find.text('扫码用水'));
    await _pumpAsync(tester);

    expect(find.text('选择水控设备'), findsOneWidget);
    expect(find.text('当前寝室设备'), findsOneWidget);
    expect(find.text('DEV-DORM'), findsOneWidget);

    await tester.ensureVisible(find.text('开阀用水'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开阀用水'));
    await _pumpAsync(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      Uri.splitQueryString(bodies['/water/water4G/scanning']!),
      <String, String>{'deviceno': 'DEV-DORM', 'empid': 'U1'},
    );
    expect(
      Uri.splitQueryString(bodies['/water/water4G/createorderissuccess']!),
      <String, String>{'ordersn': '965000'},
    );
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('关阀结算'), findsOneWidget);
    expect(find.textContaining('已暂扣 ¥10.00'), findsOneWidget);

    await tester.ensureVisible(find.text('关阀结算'));
    await tester.pump();
    await tester.tap(find.text('关阀结算'));
    await _pumpAsync(tester);

    expect(
      Uri.splitQueryString(bodies['/water/water4G/activesetttleaccounts']!),
      <String, String>{'ordersn': '965000'},
    );
    expect(find.text('已关阀，等待订单生成'), findsOneWidget);
    expect(find.textContaining('已结算并返还暂扣押金'), findsOneWidget);
    expect(find.textContaining('结账后 60 秒可再开阀'), findsOneWidget);

    // 等“已关阀”提示消失，避免 SnackBar 挡住扫码按钮。
    await tester.pump(const Duration(seconds: 5));
    await tester.ensureVisible(find.text('扫码用水'));
    await tester.pump();
    await tester.tap(find.text('扫码用水'));
    await _pumpAsync(tester);
    expect(find.textContaining('秒后再开阀'), findsOneWidget);
    expect(find.text('选择水控设备'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('进入水控选项卡自动切入未结算订单', (WidgetTester tester) async {
    final Map<String, String> bodies = <String, String>{};
    final AppState app = AppState(
      client: CwcClient(
        client: MockClient((http.Request request) async {
          bodies[request.url.path] = request.body;
          return switch (request.url.path) {
            '/water/getEmployeeRoom' => _ok(<String, Object?>{
              'roomName': '竹苑5221',
            }),
            '/water/water4G/getLatestDeviceNo' => _ok('DEV-001'),
            '/water/water4G/orderingTips' => _ok(<Object?>[
              <String, Object?>{
                'VALVECODE': 'DEV-DORM',
                'ORDERSN': 965000,
                'FREEZNAMOUNT': 10.0,
                'CREATETIME': '2026-11-09T12:19:58.492+0000',
              },
            ]),
            '/water/water4G/activesetttleaccounts' => _ok('结算成功'),
            _ => _ok(null),
          };
        }),
      ),
    )..session = _session;

    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    await _pumpAsync(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('水控'),
      ),
    );
    await _pumpAsync(tester);

    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('设备 DEV-DORM'), findsOneWidget);
    expect(find.text('关阀结算'), findsOneWidget);
    expect(find.textContaining('已暂扣 ¥10.00'), findsOneWidget);

    await tester.ensureVisible(find.text('关阀结算'));
    await tester.pump();
    await tester.tap(find.text('关阀结算'));
    await _pumpAsync(tester);

    expect(
      Uri.splitQueryString(bodies['/water/water4G/activesetttleaccounts']!),
      <String, String>{'ordersn': '965000'},
    );
    expect(find.text('已关阀，等待订单生成'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('用水订单按水控流水字段展示', (WidgetTester tester) async {
    final AppState app = AppState(
      client: CwcClient(
        client: MockClient((http.Request request) async {
          return switch (request.url.path) {
            '/water/getEmployeeRoom' => _ok(<String, Object?>{
              'roomName': '1栋101',
            }),
            '/water/water4G/getLatestDeviceNo' => _ok('DEV-001'),
            '/water/water4G/query4GWaterPage' => _ok(<Object?>[
              <String, Object?>{
                'id': 1313516495809744897,
                'amount': -0.01,
                'cardValue': 22.97,
                'status': 1,
                'occurTime': '2026-11-09 19:34:24',
                'transCode': 1015,
                'transCodeName': '水控在线扣费',
                'deviceNo': '000000000000000000000001',
                'marketName': '4G水控',
                'walletId': 'W-1',
                'waterstatus': '1',
                'usetime': '65',
              },
            ]),
            _ => _ok(null),
          };
        }),
      ),
    )..session = _session;

    await tester.pumpWidget(MaterialApp(home: HomePage(app: app)));
    await _pumpAsync(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('水控'),
      ),
    );
    await _pumpAsync(tester);

    await tester.tap(find.text('用水订单'));
    await _pumpAsync(tester);

    expect(find.text('水控在线扣费'), findsOneWidget);
    expect(find.text('4G水控 · 2026-11-09 19:34:24'), findsOneWidget);
    expect(find.text('-¥ 0.01'), findsOneWidget);
    expect(find.text('余额 ¥22.97'), findsOneWidget);
    expect(find.text('状态 1'), findsOneWidget);
    expect(find.text('水控状态 1'), findsOneWidget);
    expect(find.text('用时 65'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:cqmu_cwc/data/api_catalog.dart';
import 'package:cqmu_cwc/data/catalog_index.dart';
import 'package:cqmu_cwc/models/session.dart';
import 'package:cqmu_cwc/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('目录收录全部接口且字段完整', () {
    expect(apiCatalog.length, 286);
    expect(catalogModules.length, greaterThan(20));
    for (final endpoint in apiCatalog) {
      expect(endpoint.path.startsWith('/'), isTrue);
      expect(endpoint.method, anyOf('GET', 'POST'));
      expect(endpoint.module.isNotEmpty, isTrue);
    }
    expect(endpointByPath('/card/info/get')?.requireToken, isTrue);
    expect(endpointByPath('/login/doLogin')?.encryptPassword, isTrue);
    expect(endpointByPath('/filecontroller/upload')?.isUpload, isTrue);
  });

  test('参数模板自动带入会话值与文档默认值', () {
    const CwcSession session = CwcSession(
      accessToken: 'token',
      userId: 'U1',
      userNo: '2026001',
      openId: 'OPENID',
    );
    final Map<String, String> params = endpointParams(
      endpointByPath('/card/transaction/page')!,
      session,
    );
    expect(params['empId'], 'U1');
    expect(params['page'], '1');
    expect(params['pageSize'], '10');
    expect(params['accountType'], '2');

    final Map<String, String> menus = endpointParams(
      endpointByPath('/baseconfig/v2/menus')!,
      session,
    );
    expect(menus['userId'], 'U1');

    final Map<String, String> water = endpointParams(
      endpointByPath('/water/water4G/query4GWaterPage')!,
      session,
    );
    expect(water['empId'], 'U1');
    expect(water['openid'], 'OPENID');
    expect(water['transCode'], '1015');
  });

  test('充值记录与消费统计默认带最近 30 天日期', () {
    final (String start, String end) = recentDateRange(
      today: DateTime(2026, 11, 9),
    );
    expect(start, '2026-10-10');
    expect(end, '2026-11-09');

    for (final String path in <String>[
      '/fee/balance/queryRechargePage',
      '/market/transaction/sum/page',
    ]) {
      final Map<String, String> params = dateRangeDefaults(path);
      expect(params['startTime'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(params['endTime'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    }
    expect(dateRangeDefaults('/card/info/get'), isEmpty);
  });
}

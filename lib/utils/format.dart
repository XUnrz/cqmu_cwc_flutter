import 'dart:convert';
import 'dart:math';

const String _tokenChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

String randomToken([int length = 32]) {
  final Random random = Random.secure();
  return List<String>.generate(
    length,
    (_) => _tokenChars[random.nextInt(_tokenChars.length)],
  ).join();
}

/// 美化 JSON，超长截断，避免日志区卡顿。
String prettyJson(Object? data, {int limit = 12000}) {
  String text;
  try {
    text = const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    text = '$data';
  }
  if (text.length > limit) {
    text = '${text.substring(0, limit)}\n...（共 ${text.length} 字符，已截断）';
  }
  return text;
}

/// 兼容 data.list / data.rows / data.records / data 为数组四种列表形态。
List<dynamic> listRows(Object? data) {
  if (data is List) return data;
  if (data is! Map) return const <dynamic>[];
  for (final String key in const <String>['list', 'rows', 'records']) {
    final Object? v = data[key];
    if (v is List) return v;
  }
  return const <dynamic>[];
}

/// 行显示名：多个常见字段依次回退。
String rowName(Object? row) {
  if (row is! Map) return '$row';
  for (final String key in const <String>[
    'name',
    'userName',
    'empName',
    'title',
    'roomName',
    'shopName',
    'carNo',
    'month',
  ]) {
    final Object? v = row[key];
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return '$v';
  }
  return '';
}

/// 金额展示：字符串金额原样保留，数字最多两位小数。
String moneyText(Object? value) {
  if (value == null || value == '') return '—';
  if (value is num) return value.toStringAsFixed(2);
  return '$value';
}

String maskToken(String token) {
  if (token.isEmpty) return '—';
  if (token.length <= 10) return '${token.substring(0, 2)}****';
  return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
}

/// yyyy-MM-dd，与 H5 日期选择器提交格式一致。
String dateText(DateTime date) {
  final String m = date.month.toString().padLeft(2, '0');
  final String d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

import 'dart:async';
import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/session.dart';
import '../utils/format.dart';

/// 真实接口地址（H5 里的 basePath 是反向代理地址，端口地址可直接访问）。
const String cwcBaseUrl = 'http://cycwc.cqmu.edu.cn:38080';

const String _aesKey = 'lyy4pGK2Iw0XtQPq';

/// AES-128-ECB / PKCS7，输出 Base64（与后端 doLogin 解密方式一致）。
String encryptPassword(String plain) {
  final enc.Encrypter encrypter = enc.Encrypter(
    enc.AES(enc.Key.fromUtf8(_aesKey), mode: enc.AESMode.ecb),
  );
  return encrypter.encrypt(plain).base64;
}

class CwcException implements Exception {
  CwcException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

bool isSuccess(Map<String, dynamic> response) =>
    response['status'] == 'SUCCESS';

String messageOf(Map<String, dynamic> response) =>
    '${response['message'] ?? ''}'.trim();

Object? dataOf(Map<String, dynamic> response) => response['data'];

/// 一卡通后端请求封装。
///
/// 所有业务接口都用表单提交（`application/x-www-form-urlencoded`），
/// 登录态放在请求头 `accessToken`，响应统一为 `{status, message, data}`。
class CwcClient {
  CwcClient({http.Client? client, this.baseUrl = cwcBaseUrl})
      : _client = client ?? http.Client();

  static const Duration timeout = Duration(seconds: 20);

  final http.Client _client;
  final String baseUrl;

  /// 收到登录失效响应时回调（主界面用来回登录页）。
  void Function()? onTokenExpired;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? params,
    String? token,
  }) =>
      _request('GET', path, params, token: token);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? params,
    String? token,
  }) =>
      _request('POST', path, params, token: token);

  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, String>? params,
    String? token,
  }) =>
      _request('POST', path, params, token: token);

  /// 按目录里的 method 调用（GET 走 query，POST 走表单）。
  Future<Map<String, dynamic>> request(
    String method,
    String path,
    Map<String, String> params, {
    String? token,
  }) =>
      _request(method, path, params, token: token);

  /// 发送短信登录验证码，返回后端提示（通常是脱敏手机号）。
  Future<String> sendLoginCode(String userNo) async {
    final Map<String, dynamic> r =
        await post('/employee/sendLoginCode', params: <String, String>{'userNo': userNo});
    if (!isSuccess(r)) throw CwcException(messageOf(r));
    return '${dataOf(r) ?? ''}';
  }

  /// 账号密码登录（密码在客户端做 AES 加密）。
  Future<CwcSession> login({
    required String userNo,
    required String password,
    required String openId,
    String loginCode = '',
    String validateCode = '',
  }) async {
    final Map<String, dynamic> r = await post(
      '/login/doLogin',
      params: <String, String>{
        'userno': userNo,
        'password': encryptPassword(password),
        'openId': openId,
        'validateCode': validateCode,
        'token': randomToken(),
        'loginCode': loginCode,
      },
    );
    if (!isSuccess(r)) throw CwcException(messageOf(r));
    final Object? data = dataOf(r);
    if (data is! Map) throw CwcException('登录返回缺少 data');
    final CwcSession session = CwcSession.fromLogin(
      data.cast<String, dynamic>(),
      openId: openId,
      fallbackUserNo: userNo,
    );
    if (!session.isLoggedIn) throw CwcException('登录返回缺少 accessToken');
    return session;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, String>? params, {
    String? token,
  }) async {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      if (token != null && token.isNotEmpty) 'accessToken': token,
    };
    // Web 端禁止设置 User-Agent / Origin 等受限头，原生端模拟微信浏览器。
    if (!kIsWeb) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 '
          'MicroMessenger/8.0.0';
      headers['Referer'] = 'http://cycwc.cqmu.edu.cn/wxmp/';
      headers['Origin'] = 'http://cycwc.cqmu.edu.cn';
    }

    final Uri base = Uri.parse('$baseUrl$path');
    http.Response response;
    try {
      if (method.toUpperCase() == 'GET') {
        response = await _client
            .get(base.replace(queryParameters: params), headers: headers)
            .timeout(timeout);
      } else {
        response = await _client
            .post(base, headers: headers, body: params)
            .timeout(timeout);
      }
    } on TimeoutException {
      throw CwcException('网络超时，请稍后重试');
    } on http.ClientException catch (e) {
      throw CwcException('网络连接失败：${e.message}');
    } on FormatException {
      throw CwcException('请求地址不合法：$base');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CwcException('服务暂时不可用（HTTP ${response.statusCode}）',
          statusCode: response.statusCode);
    }

    final String body = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw CwcException('服务返回的不是 JSON：${body.length > 120 ? '${body.substring(0, 120)}…' : body}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw CwcException('服务返回格式异常');
    }
    if (_looksExpired(decoded)) onTokenExpired?.call();
    return decoded;
  }

  bool _looksExpired(Map<String, dynamic> response) {
    if (isSuccess(response)) return false;
    final String msg = messageOf(response);
    return msg.contains('token') &&
        (msg.contains('失效') || msg.contains('过期') || msg.contains('无效'));
  }

  void close() => _client.close();
}

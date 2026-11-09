import 'dart:convert';

/// 登录会话（对应 /login/doLogin 返回的 data）。
class CwcSession {
  const CwcSession({
    required this.accessToken,
    required this.userId,
    required this.userNo,
    this.userName = '',
    this.departmentName = '',
    this.openId = '',
    this.emplId = '',
  });

  final String accessToken;

  /// 后端 userId，业务接口里的 empId / employeeId 用它
  final String userId;

  /// 人员档案里的 emplId（登录返回 fullEmployee.extend.emplId）；
  /// 付款码等少数接口用的是它，为空时回退 [userId]。
  final String emplId;

  /// 学号 / 工号
  final String userNo;
  final String userName;
  final String departmentName;
  final String openId;

  static const CwcSession empty = CwcSession(
    accessToken: '',
    userId: '',
    userNo: '',
  );

  bool get isLoggedIn => accessToken.isNotEmpty;

  /// `data` 既可能是登录信息本身，也可能包一层 loginUser。
  factory CwcSession.fromLogin(
    Map<String, dynamic> payload, {
    String openId = '',
    String fallbackUserNo = '',
  }) {
    Map<String, dynamic> data = payload;
    final Object? nested = payload['loginUser'];
    if (nested is Map) data = nested.cast<String, dynamic>();
    String text(Object? v) => v == null ? '' : '$v';
    final String token =
        text(data['accessToken']).isNotEmpty ? text(data['accessToken']) : text(data['token']);
    String emplId = text(data['emplId']);
    final Object? full = data['fullEmployee'];
    if (full is Map) {
      final Object? extend = full['extend'];
      if (extend is Map && text(extend['emplId']).isNotEmpty) {
        emplId = text(extend['emplId']);
      }
    }
    return CwcSession(
      accessToken: token,
      userId: text(data['userId']).isNotEmpty ? text(data['userId']) : text(data['userNo']),
      emplId: emplId,
      userNo: text(data['userNo']).isNotEmpty ? text(data['userNo']) : fallbackUserNo,
      userName: text(data['userName']),
      departmentName: text(data['departmentName']),
      openId: text(data['openId']).isNotEmpty ? text(data['openId']) : openId,
    );
  }

  CwcSession copyWith({
    String? accessToken,
    String? userId,
    String? emplId,
    String? userNo,
    String? userName,
    String? departmentName,
    String? openId,
  }) {
    return CwcSession(
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      emplId: emplId ?? this.emplId,
      userNo: userNo ?? this.userNo,
      userName: userName ?? this.userName,
      departmentName: departmentName ?? this.departmentName,
      openId: openId ?? this.openId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'userId': userId,
        'emplId': emplId,
        'userNo': userNo,
        'userName': userName,
        'departmentName': departmentName,
        'openId': openId,
      };

  static CwcSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? d = jsonDecode(raw);
      if (d is! Map<String, dynamic>) return null;
      final CwcSession s = CwcSession.fromLogin(d);
      return s.isLoggedIn ? s : null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

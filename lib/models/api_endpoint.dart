/// 一卡通接口目录条目。
class ApiEndpoint {
  const ApiEndpoint({
    required this.method,
    required this.path,
    required this.module,
    required this.description,
    required this.params,
    this.defaults = const <String, String>{},
    this.requireToken = false,
    this.encryptPassword = false,
    this.isUpload = false,
  });

  /// GET / POST
  final String method;

  /// 相对路径，如 /card/info/get
  final String path;

  /// 中文模块名
  final String module;

  /// 用途说明
  final String description;

  /// 顶层参数名（按后端字段原样保留大小写）
  final List<String> params;

  /// 文档中出现的字面量默认值（page=1、pageSize=10 等）
  final Map<String, String> defaults;

  /// 是否需要请求头 accessToken
  final bool requireToken;

  /// 密码参数是否在发送前做 AES 加密（仅 /login/doLogin）
  final bool encryptPassword;

  /// 是否为 multipart 文件上传
  final bool isUpload;

  bool get isGet => method == 'GET';

  bool get isWrite => !isGet;
}

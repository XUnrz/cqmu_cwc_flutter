import '../models/api_endpoint.dart';
import 'api_catalog.dart';

/// 按路径查目录条目（同路径多方法时优先 POST）。
ApiEndpoint? endpointByPath(String path) {
  ApiEndpoint? fallback;
  for (final ApiEndpoint e in apiCatalog) {
    if (e.path != path) continue;
    if (e.method == 'POST') return e;
    fallback ??= e;
  }
  return fallback;
}

/// 模块顺序按文档出现顺序排列。
final List<String> catalogModules = <String>[
  for (final ApiEndpoint e in apiCatalog)
    if (!_seen.contains(e.module) && _seen.add(e.module)) e.module,
];

final Set<String> _seen = <String>{};

final Map<String, int> moduleCounts = <String, int>{
  for (final String module in catalogModules)
    module: apiCatalog.where((ApiEndpoint e) => e.module == module).length,
};

List<ApiEndpoint> endpointsOfModule(String module) =>
    apiCatalog.where((ApiEndpoint e) => e.module == module).toList();

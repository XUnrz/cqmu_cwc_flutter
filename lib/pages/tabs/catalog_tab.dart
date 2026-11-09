import 'package:flutter/material.dart';

import '../../data/api_catalog.dart';
import '../../data/catalog_index.dart';
import '../../models/api_endpoint.dart';
import '../../services/app_state.dart';
import '../../widgets/filter_pill.dart';
import '../endpoint_page.dart';

/// 接口目录：搜索 + 模块筛选 + 进入调用页。
class CatalogTab extends StatefulWidget {
  const CatalogTab({
    super.key,
    required this.app,
    this.initialModule,
    this.onModuleConsumed,
  });

  final AppState app;
  final String? initialModule;
  final VoidCallback? onModuleConsumed;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final TextEditingController _keyword = TextEditingController();
  String? _module;
  List<ApiEndpoint> _hits = apiCatalog;

  @override
  void initState() {
    super.initState();
    _module = widget.initialModule;
    _search();
  }

  @override
  void didUpdateWidget(covariant CatalogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? incoming = widget.initialModule;
    if (incoming != null) {
      setState(() {
        _module = incoming;
        _keyword.clear();
        _search();
      });
      widget.onModuleConsumed?.call();
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  void _search() {
    final String kw = _keyword.text.trim().toLowerCase();
    _hits = apiCatalog.where((ApiEndpoint e) {
      if (_module != null && e.module != _module) return false;
      if (kw.isEmpty) return true;
      return e.path.toLowerCase().contains(kw) ||
          e.description.toLowerCase().contains(kw) ||
          e.module.toLowerCase().contains(kw) ||
          e.params.any((String p) => p.toLowerCase().contains(kw));
    }).toList()
      ..sort((ApiEndpoint a, ApiEndpoint b) {
        final int c = a.path.compareTo(b.path);
        return c != 0 ? c : a.method.compareTo(b.method);
      });
    if (mounted) setState(() {});
  }

  void _selectModule(String? module) {
    setState(() {
      _module = module;
      _search();
    });
  }

  void _open(ApiEndpoint endpoint) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EndpointPage(app: widget.app, endpoint: endpoint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            key: const Key('catalog-keyword'),
            controller: _keyword,
            decoration: InputDecoration(
              hintText: '搜索路径 / 用途 / 参数名',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _keyword.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _keyword.clear();
                        _search();
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _search(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              FilterPill(
                label: '全部 ${apiCatalog.length}',
                selected: _module == null,
                onTap: () => _selectModule(null),
              ),
              const SizedBox(width: 8),
              for (final String module in catalogModules) ...<Widget>[
                FilterPill(
                  label: '$module ${moduleCounts[module]}',
                  selected: _module == module,
                  onTap: () => _selectModule(module),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Text(
            _module == null
                ? '共 ${apiCatalog.length} 个接口 · 匹配 ${_hits.length} 个'
                : '$_module · 匹配 ${_hits.length} 个',
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
          ),
        ),
        Expanded(
          child: _hits.isEmpty
              ? Center(
                  child: Text(
                    '没有匹配的接口',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _hits.length,
                  itemBuilder: (BuildContext context, int i) {
                    final ApiEndpoint endpoint = _hits[i];
                    return ListTile(
                      onTap: () => _open(endpoint),
                      leading: _MethodBadge(method: endpoint.method),
                      title: Text(
                        endpoint.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${endpoint.module} · ${endpoint.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (endpoint.requireToken)
                            Icon(Icons.lock_outline, size: 16, color: scheme.outline),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: scheme.outline),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool get = method == 'GET';
    final Color color = get ? scheme.primary : scheme.tertiary;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

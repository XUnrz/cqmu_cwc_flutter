import 'package:flutter/material.dart';

import '../data/catalog_index.dart';
import '../models/api_endpoint.dart';
import '../services/app_state.dart';
import '../services/cwc_client.dart';
import '../utils/format.dart';
import '../widgets/output_log.dart';

/// 一次预设调用：路径 + 对模板参数的覆盖值。
class ApiCall {
  const ApiCall(this.path, {this.overrides = const <String, String>{}});

  final String path;
  final Map<String, String> overrides;
}

/// 通用数据页：按顺序执行一组接口，把完整响应写入输出区。
class DataCallsPage extends StatefulWidget {
  const DataCallsPage({
    super.key,
    required this.app,
    required this.title,
    required this.calls,
  });

  final AppState app;
  final String title;
  final List<ApiCall> calls;

  @override
  State<DataCallsPage> createState() => _DataCallsPageState();
}

class _DataCallsPageState extends State<DataCallsPage> {
  final OutputLogController _log = OutputLogController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    for (final ApiCall call in widget.calls) {
      final ApiEndpoint? endpoint = endpointByPath(call.path);
      final Map<String, String> params = <String, String>{
        if (endpoint != null) ...endpointParams(endpoint, widget.app.session),
        ...dateRangeDefaults(call.path),
        ...call.overrides,
      };
      try {
        final Map<String, dynamic> r = await widget.app.client.request(
          endpoint?.method ?? 'POST',
          call.path,
          params,
          token: widget.app.current.accessToken,
        );
        _log.append(OutputEntry(
          header: '${endpoint?.method ?? 'POST'} ${call.path}  '
              '${r['status']}  ${messageOf(r)}',
          body: prettyJson(r),
          isError: !isSuccess(r),
        ));
      } on CwcException catch (e) {
        _log.append(OutputEntry(
          header: '${endpoint?.method ?? 'POST'} ${call.path} 请求失败',
          body: e.message,
          isError: true,
        ));
      }
      if (!mounted) return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: '重新调用',
            onPressed: _loading
                ? null
                : () {
                    _log.clear();
                    _run();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: OutputLog(controller: _log),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/session.dart';
import '../../services/app_state.dart';
import '../../services/cwc_client.dart';
import '../../utils/format.dart';

/// 水控：开阀用水（当前寝室 / 最近设备 / 扫码）与用水订单。
class WaterTab extends StatefulWidget {
  const WaterTab({super.key, required this.app, required this.isActive});

  final AppState app;
  final bool isActive;

  @override
  State<WaterTab> createState() => _WaterTabState();
}

class _WaterTabState extends State<WaterTab> {
  bool _loading = false;
  bool _loaded = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _roomData;
  String _latestDevice = '';
  String _dormDevice = '';

  String _activeDevice = '';
  String _orderId = '';
  String _heldAmount = '';
  DateTime? _openedAt;
  DateTime? _closedAt;
  int _waitSeconds = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _loadOverview();
  }

  @override
  void didUpdateWidget(covariant WaterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      if (!_loaded) {
        _loadOverview();
      } else if (!_inUse && _waitSeconds == 0 && !_busy) {
        _restoreUnsettled();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _empId {
    final CwcSession s = widget.app.current;
    return s.userId.isNotEmpty ? s.userId : s.emplId;
  }

  String get _token => widget.app.current.accessToken;

  String get _defaultDevice =>
      _dormDevice.isNotEmpty ? _dormDevice : _latestDevice;

  String get _heldText {
    if (_heldAmount.isEmpty) return '';
    final double? value = double.tryParse(_heldAmount);
    return value == null ? _heldAmount : moneyText(value);
  }

  bool get _inUse => _openedAt != null;

  bool get _waiting => _closedAt != null;

  Map<String, dynamic>? get _room {
    final Object? data = _roomData == null ? null : dataOf(_roomData!);
    if (data is Map) return data.cast<String, dynamic>();
    if (data is List && data.isNotEmpty && data.first is Map) {
      return (data.first as Map).cast<String, dynamic>();
    }
    return null;
  }

  Future<void> _loadOverview() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _loaded = true;
    });
    final String userId = widget.app.current.userId;
    String? error;
    Map<String, dynamic>? room;
    String device = '';
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/getEmployeeRoom',
        <String, String>{'employeeId': userId},
        token: _token,
      );
      if (isSuccess(r)) {
        room = r;
      } else {
        error = messageOf(r).isEmpty ? '房间信息获取失败' : messageOf(r);
      }
    } on CwcException catch (e) {
      error = e.message;
    }
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/getLatestDeviceNo',
        <String, String>{'empId': userId},
        token: _token,
      );
      if (isSuccess(r)) device = _deviceCode(dataOf(r));
    } on CwcException catch (_) {
      // 最近设备只是辅助信息，失败时忽略。
    }

    Map<String, dynamic>? roomInfo;
    final Object? roomRaw = room == null ? null : dataOf(room);
    if (roomRaw is Map) {
      roomInfo = roomRaw.cast<String, dynamic>();
    } else if (roomRaw is List) {
      for (final Object? item in roomRaw) {
        if (item is Map) {
          roomInfo = item.cast<String, dynamic>();
          break;
        }
      }
    }
    String dormDevice = _deviceCode(roomInfo);
    if (dormDevice.isEmpty && roomInfo != null) {
      String keyword = '';
      for (final String key in const <String>[
        'roomNo',
        'roomno',
        'roomName',
        'roomname',
        'dormName',
        'dormname',
        'name',
      ]) {
        final String v = _scalarText(roomInfo[key]);
        if (v.isNotEmpty) {
          keyword = v;
          break;
        }
      }
      if (keyword.isNotEmpty) {
        try {
          final Map<String, dynamic> r = await widget.app.client.request(
            'POST',
            '/water/water4G/queryRelationByDorm',
            <String, String>{'dorminfo': keyword},
            token: _token,
          );
          if (isSuccess(r)) dormDevice = _deviceCode(dataOf(r));
        } on CwcException catch (_) {
          // 旧账号可能没有绑定寝室设备。
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _roomData = room;
      _latestDevice = device;
      _dormDevice = dormDevice;
      _error = error;
      _loading = false;
    });
    await _restoreUnsettled();
  }

  /// 进入水控时先看有没有未结算订单；有就直接切回“使用中”，避免阀门开着却无处关。
  Future<void> _restoreUnsettled() async {
    if (!mounted || _busy || _inUse || _waitSeconds > 0) return;
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/orderingTips',
        <String, String>{
          'empid': _empId,
          if (widget.app.current.openId.isNotEmpty)
            'openid': widget.app.current.openId,
        },
        token: _token,
      );
      if (!mounted || !isSuccess(r)) return;
      for (final dynamic item in listRows(dataOf(r))) {
        if (item is! Map) continue;
        final String id = _unsettledIdOf(item);
        if (id.isEmpty) continue;
        final String device = _valveCodeOf(item);
        final DateTime? createdAt = _parseServerTime(
          _pickExact(item, const <String>[
            'CREATETIME',
            'createtime',
            'createTime',
            'create_time',
          ]),
        );
        setState(() {
          _orderId = id;
          _activeDevice = device;
          _heldAmount = _freezeAmountOf(item);
          _openedAt = createdAt ?? DateTime.now();
          _closedAt = null;
          _waitSeconds = 0;
          if (device.isNotEmpty) _latestDevice = device;
        });
        _startTicker();
        _toast('检测到未结算的用水订单，请及时关阀结算');
        return;
      }
    } on CwcException catch (_) {
      // 查询失败时按正常流程展示。
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _scanWater() async {
    if (_waitSeconds > 0) {
      _toast('结账后请 $_waitSeconds 秒后再开阀');
      return;
    }
    final String? device = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DevicePickerSheet(
        roomName: _room == null ? '' : _roomTitle(_room!),
        dormDevice: _dormDevice,
        latestDevice: _latestDevice,
      ),
    );
    if (device == null || device.isEmpty) return;
    await _openValve(device);
  }

  Future<void> _openValve(String device) async {
    if (_busy) return;
    if (_empId.isEmpty) {
      _toast('登录信息缺少用户 ID');
      return;
    }
    setState(() => _busy = true);
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/scanning',
        <String, String>{'deviceno': device, 'empid': _empId},
        token: _token,
      );
      if (!mounted) return;
      if (!isSuccess(r)) {
        _toast(_failText('开阀', r));
        return;
      }
      final String id = _scanOrderIdOf(r);
      if (id.isEmpty) {
        _toast('开阀失败：设备未返回订单信息');
        return;
      }
      setState(() {
        _activeDevice = device;
        _orderId = id;
        _heldAmount = _freezeAmountOf(r);
        _openedAt = DateTime.now();
        _closedAt = null;
        _waitSeconds = 0;
        _latestDevice = device;
      });
      final bool opened = await _confirmOpened(id);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _activeDevice = '';
          _orderId = '';
          _openedAt = null;
        });
        return;
      }
      _startTicker();
      _toast('阀门已开启，用完后请及时关阀');
    } on CwcException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeValve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String id = _orderId.isNotEmpty
          ? _orderId
          : await _findUnsettledId();
      if (id.isEmpty) {
        _toast('未找到未结算订单，请稍后重试');
        return;
      }
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/activesetttleaccounts',
        <String, String>{'ordersn': id},
        token: _token,
      );
      if (!mounted) return;
      if (!isSuccess(r)) {
        _toast(_failText('关阀', r));
        return;
      }
      setState(() {
        _closedAt = DateTime.now();
        _waitSeconds = 60;
        _openedAt = null;
        _orderId = '';
        _heldAmount = '';
      });
      _startTicker();
      _toast('已关阀，订单约 1 分钟后可查询');
    } on CwcException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WaterOrdersPage(
          app: widget.app,
          refreshAt: _waiting && _waitSeconds > 0
              ? DateTime.now().add(Duration(seconds: _waitSeconds))
              : null,
        ),
      ),
    );
  }

  /// 开阀后网页端会每秒轮询一次，最多 10 次确认阀门真正打开。
  Future<bool> _confirmOpened(String id) async {
    for (int i = 0; i < 10; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return false;
      final Map<String, dynamic> r;
      try {
        r = await widget.app.client.request(
          'POST',
          '/water/water4G/createorderissuccess',
          <String, String>{'ordersn': id},
          token: _token,
        );
      } on CwcException catch (e) {
        if (mounted) _toast(e.message);
        return false;
      }
      if (!mounted) return false;
      if (!isSuccess(r)) {
        _toast(_failText('开阀确认', r));
        return false;
      }
      final String state = _scalarText(dataOf(r));
      if (state == '1') return true;
      if (state == '-1' || state == '-2') {
        _toast('开阀失败，请 5 分钟后再操作');
        return false;
      }
    }
    return false;
  }

  /// 页面重进或开阀响应丢失时，从“未结算订单”里找回订单 id。
  Future<String> _findUnsettledId() async {
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/orderingTips',
        <String, String>{
          'empid': _empId,
          if (widget.app.current.openId.isNotEmpty)
            'openid': widget.app.current.openId,
        },
        token: _token,
      );
      if (!isSuccess(r)) return '';
      final List<dynamic> rows = listRows(dataOf(r));
      String fallback = '';
      for (final dynamic row in rows) {
        final String id = _unsettledIdOf(row);
        if (id.isEmpty) continue;
        if (_activeDevice.isNotEmpty && _valveCodeOf(row) == _activeDevice) {
          return id;
        }
        if (fallback.isEmpty) fallback = id;
      }
      return fallback;
    } on CwcException catch (_) {
      // 关阀时再提示。
    }
    return '';
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_closedAt != null) {
        final int left = 60 - DateTime.now().difference(_closedAt!).inSeconds;
        if (left <= 0) {
          setState(() => _waitSeconds = 0);
          _ticker?.cancel();
          _ticker = null;
        } else {
          setState(() => _waitSeconds = left);
        }
      } else if (_openedAt != null) {
        setState(() {});
      } else {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  Widget _usingCard(ColorScheme scheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.water_drop, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                '使用中',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _elapsedText(_openedAt!),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '设备 ${_activeDevice.isEmpty ? '—' : _activeDevice}',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            _heldAmount.isEmpty
                ? '开阀时已暂扣押金，用完后点击“关阀结算”按实际用量返还。'
                : '已暂扣 ¥$_heldText，用完后点击“关阀结算”按实际用量返还。',
            style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: _busy ? null : _closeValve,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('关阀结算'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waitingCard(ColorScheme scheme, ThemeData theme) {
    final int remaining = _waitSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已关阀，等待订单生成',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '已结算并返还暂扣押金，订单约 1 分钟后生成 · 剩余 $remaining 秒'
                : '订单已可查询；为防重复扣费，1 分钟内请勿再次开阀。',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: remaining > 0 ? (60 - remaining) / 60 : 1,
            backgroundColor: scheme.onSecondaryContainer.withValues(
              alpha: 0.15,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: _openOrders,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('查看用水订单'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Map<String, dynamic>? room = _room;
    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.water_drop_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        room == null ? '水控' : _roomTitle(room),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: '刷新',
                        icon: Icon(
                          Icons.refresh,
                          color: scheme.onPrimaryContainer,
                        ),
                        onPressed: _loadOverview,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (room != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final MapEntry<String, dynamic> e in _roomFields(
                        room,
                      ))
                        _ValueChip(
                          label: _fieldLabel(e.key),
                          value: '${e.value}',
                        ),
                    ],
                  )
                else
                  Text(
                    _error ?? (_loading ? '正在获取房间信息…' : '下拉刷新水控信息'),
                    style: TextStyle(
                      color: _error == null
                          ? scheme.onPrimaryContainer
                          : scheme.error,
                    ),
                  ),
                if (_error != null && room != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.sensors, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _defaultDevice.isEmpty
                            ? '默认设备：未获取到寝室设备码'
                            : '默认设备：${_shortDevice(_defaultDevice)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _latestDevice.isEmpty
                            ? '最近使用：暂无记录'
                            : '最近使用：${_shortDevice(_latestDevice)}',
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_inUse) ...<Widget>[
            const SizedBox(height: 12),
            _usingCard(scheme, theme),
          ],
          if (_waiting) ...<Widget>[
            const SizedBox(height: 12),
            _waitingCard(scheme, theme),
          ],
          const SizedBox(height: 20),
          Text('水控功能', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: <Widget>[
              _ActionTile(
                icon: Icons.qr_code_scanner,
                title: '扫码用水',
                subtitle: _waitSeconds > 0
                    ? '结账后 $_waitSeconds 秒可再开阀'
                    : _defaultDevice.isEmpty
                    ? '选择设备或扫描二维码'
                    : '默认 ${_shortDevice(_defaultDevice)}',
                onTap: _busy ? null : _scanWater,
              ),
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                title: '用水订单',
                subtitle: '最近 30 天流水',
                onTap: _openOrders,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _roomTitle(Map<String, dynamic> room) {
  for (final String key in const <String>[
    'roomName',
    'roomname',
    'dormName',
    'dormname',
    'roomNo',
    'roomno',
    'name',
    'address',
  ]) {
    final Object? v = room[key];
    if (v is String && v.isNotEmpty) return v;
    if (v is num) return '$v';
  }
  return '水控房间';
}

Iterable<MapEntry<String, dynamic>> _roomFields(
  Map<String, dynamic> room,
) sync* {
  int count = 0;
  for (final MapEntry<String, dynamic> e in room.entries) {
    final Object? v = e.value;
    if (v is! String && v is! num && v is! bool) continue;
    if ('$v'.isEmpty) continue;
    yield e;
    count++;
    if (count >= 8) return;
  }
}

String _fieldLabel(String key) {
  const Map<String, String> labels = <String, String>{
    'roomName': '房间',
    'roomname': '房间',
    'roomNo': '房间号',
    'roomno': '房间号',
    'dormName': '宿舍',
    'dormname': '宿舍',
    'balance': '余额',
    'waterValue': '水费',
    'waterBalance': '水费余额',
    'surplus': '余额',
    'amount': '金额',
    'money': '金额',
    'empName': '姓名',
    'empNo': '工号',
    'tel': '电话',
    'deviceNo': '设备号',
    'state': '状态',
    'status': '状态',
    'createTime': '时间',
    'payTime': '时间',
    'transTime': '时间',
  };
  return labels[key] ?? key;
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet({
    required this.roomName,
    required this.dormDevice,
    required this.latestDevice,
  });

  final String roomName;
  final String dormDevice;
  final String latestDevice;

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  late String _selected = widget.dormDevice.isNotEmpty
      ? widget.dormDevice
      : widget.latestDevice;

  Future<void> _scanQr() async {
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const _QrScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  Future<void> _manualInput() async {
    final String? code = await showDialog<String>(
      context: context,
      builder: (_) => const _DeviceInputDialog(),
    );
    if (!mounted || code == null || code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasDorm = widget.dormDevice.isNotEmpty;
    final bool hasLatest =
        widget.latestDevice.isNotEmpty &&
        widget.latestDevice != widget.dormDevice;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('选择水控设备', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '默认使用当前寝室的设备码，也可以切换最近设备或扫描二维码。',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            if (hasDorm)
              _DeviceOptionTile(
                icon: Icons.home_outlined,
                title: '当前寝室设备',
                subtitle: widget.dormDevice,
                selected: _selected == widget.dormDevice,
                onTap: () => setState(() => _selected = widget.dormDevice),
              ),
            if (hasLatest)
              _DeviceOptionTile(
                icon: Icons.history,
                title: '最近使用设备',
                subtitle: widget.latestDevice,
                selected: _selected == widget.latestDevice,
                onTap: () => setState(() => _selected = widget.latestDevice),
              ),
            _DeviceOptionTile(
              icon: Icons.qr_code_scanner,
              title: '扫描设备二维码',
              subtitle: '打开相机识别设备码',
              selected: false,
              onTap: _scanQr,
            ),
            _DeviceOptionTile(
              icon: Icons.keyboard_alt_outlined,
              title: '手动输入设备码',
              subtitle: '无法扫码时使用',
              selected: false,
              onTap: _manualInput,
            ),
            if (!hasDorm && !hasLatest) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '当前没有可用的寝室或最近设备，请扫码或手动输入。',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('开阀用水'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceOptionTile extends StatelessWidget {
  const _DeviceOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.outline,
      ),
      onTap: onTap,
    );
  }
}

class _DeviceInputDialog extends StatefulWidget {
  const _DeviceInputDialog();

  @override
  State<_DeviceInputDialog> createState() => _DeviceInputDialogState();
}

class _DeviceInputDialogState extends State<_DeviceInputDialog> {
  final TextEditingController _device = TextEditingController();

  @override
  void dispose() {
    _device.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.keyboard_alt_outlined),
      title: const Text('输入设备码'),
      content: TextField(
        controller: _device,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '设备编号',
          helperText: '填写水控设备二维码中的编号',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_device.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String code = _deviceFromQr(barcode.rawValue ?? '');
      if (code.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描设备二维码')),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? '没有相机权限，请在系统设置中允许后重试。'
                            : '相机启动失败，请稍后重试。',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '将水控设备二维码放入取景框',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterOrdersPage extends StatefulWidget {
  const _WaterOrdersPage({required this.app, this.refreshAt});

  final AppState app;

  /// 关阀后订单尚未生成时，到达该时间自动刷新一次。
  final DateTime? refreshAt;

  @override
  State<_WaterOrdersPage> createState() => _WaterOrdersPageState();
}

class _WaterOrdersPageState extends State<_WaterOrdersPage> {
  bool _loading = false;
  String? _error;
  List<dynamic> _rows = <dynamic>[];
  int _remaining = 0;
  bool _autoLoaded = false;
  Timer? _countdown;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  String get _empId {
    final CwcSession s = widget.app.current;
    return s.userId.isNotEmpty ? s.userId : s.emplId;
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _load();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final DateTime? at = widget.refreshAt;
    if (at == null) return;
    _remaining = at.difference(DateTime.now()).inSeconds;
    if (_remaining <= 0) {
      _remaining = 0;
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final int left = at.difference(DateTime.now()).inSeconds;
      setState(() => _remaining = left <= 0 ? 0 : left);
      if (left <= 0) {
        timer.cancel();
        if (!_autoLoaded) {
          _autoLoaded = true;
          _load();
        }
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/water/water4G/query4GWaterPage',
        <String, String>{
          'page': '1',
          'pageSize': '20',
          'empId': _empId,
          if (widget.app.current.openId.isNotEmpty)
            'openid': widget.app.current.openId,
          'startTime': dateText(_range.start),
          'endTime': dateText(_range.end),
          'transCode': '1015',
          'accountType': '2',
        },
        token: widget.app.current.accessToken,
      );
      if (!mounted) return;
      if (!isSuccess(r)) {
        setState(() => _error = messageOf(r).isEmpty ? '查询失败' : messageOf(r));
      } else {
        setState(() => _rows = listRows(dataOf(r)).whereType<Map>().toList());
      }
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: '选择订单日期',
      saveText: '确定',
    );
    if (range == null) return;
    setState(() => _range = range);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用水订单'),
        actions: <Widget>[
          IconButton(
            tooltip: '选择日期',
            icon: const Icon(Icons.date_range),
            onPressed: _loading ? null : _pickRange,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  '${dateText(_range.start)} ~ ${dateText(_range.end)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${_rows.length} 条',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (widget.refreshAt != null) _waitBanner(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _ordersBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitBanner(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.hourglass_bottom,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _remaining > 0
                  ? '刚结束的用水订单约 1 分钟后生成，剩余 $_remaining 秒。'
                  : '订单已可查询，正在自动刷新。',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersBody(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(48),
            child: Text(
              _loading ? '正在查询…' : '暂无用水订单',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _rows.length,
      itemBuilder: (BuildContext context, int i) =>
          _WaterOrderCard(row: _rows[i]),
    );
  }
}

class _WaterOrderCard extends StatelessWidget {
  const _WaterOrderCard({required this.row});

  final dynamic row;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, dynamic> m = row is Map
        ? (row as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.water_drop_outlined, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _OrderTitle(data: m),
                  _OrderMeta(data: m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _orderText(
  Map<String, dynamic> m,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final Object? value = m[key] ?? m[key.toLowerCase()];
    final String v = _scalarText(value);
    if (v.isNotEmpty) return v;
  }
  return fallback;
}

class _OrderTitle extends StatelessWidget {
  const _OrderTitle({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String title = _orderText(data, const <String>[
      'transCodeName',
      'transcodename',
      'marketName',
      'marketname',
    ], fallback: '水控消费');
    final String amount = _amountText(data['amount']);
    final num? value = data['amount'] is num
        ? data['amount'] as num
        : num.tryParse('${data['amount'] ?? ''}');
    final Color color = value != null && value < 0
        ? scheme.error
        : scheme.primary;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        if (amount.isNotEmpty)
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }
}

String _amountText(Object? amount) {
  if (amount == null) return '';
  final num? value = amount is num ? amount : num.tryParse('$amount');
  if (value == null) return '¥ $amount';
  if (value < 0) return '-¥ ${value.abs().toStringAsFixed(2)}';
  return '+¥ ${value.toStringAsFixed(2)}';
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String market = _orderText(data, const <String>[
      'marketName',
      'marketname',
    ]);
    final String occur = _orderText(data, const <String>[
      'occurTime',
      'occurtime',
      'transTime',
      'createTime',
    ]);
    final String device = _orderText(data, const <String>[
      'deviceNo',
      'deviceno',
    ]);
    final String status = _orderText(data, const <String>['status']);
    final String waterStatus = _orderText(data, const <String>[
      'waterstatus',
      'waterStatus',
    ]);
    final String useTime = _orderText(data, const <String>[
      'usetime',
      'useTime',
    ]);
    final Object? cardValue = data['cardValue'] ?? data['cardvalue'];
    final String subtitle = <String>[
      if (market.isNotEmpty) market,
      if (occur.isNotEmpty) occur,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (cardValue != null)
                _MetaTag(text: '余额 ¥${moneyText(cardValue)}'),
              if (status.isNotEmpty) _MetaTag(text: '状态 $status'),
              if (waterStatus.isNotEmpty) _MetaTag(text: '水控状态 $waterStatus'),
              if (useTime.isNotEmpty) _MetaTag(text: '用时 $useTime'),
              if (device.isNotEmpty)
                _MetaTag(text: '设备 ${_shortDevice(device)}'),
            ],
          ),
        ],
      ),
    );
  }
}

String _elapsedText(DateTime start) {
  Duration d = DateTime.now().difference(start);
  if (d.isNegative) d = Duration.zero;
  final String m = d.inMinutes.toString().padLeft(2, '0');
  final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _shortDevice(String device) {
  if (device.length <= 14) return device;
  return '${device.substring(0, 6)}…${device.substring(device.length - 4)}';
}

String _failText(String action, Map<String, dynamic> response) {
  final String message = messageOf(response);
  return message.isEmpty ? '$action失败，请稍后重试' : '$action失败：$message';
}

String _scalarText(Object? value) {
  if (value is String) return value.trim();
  if (value is num || value is bool) return '$value';
  return '';
}

/// 后端时间是 `2026-11-09T12:19:58.492+0000` 这类带无冒号时区偏移的格式。
DateTime? _parseServerTime(String text) {
  if (text.isEmpty) return null;
  final DateTime? direct = DateTime.tryParse(text);
  if (direct != null) return direct.toLocal();
  final String normalized = text.replaceFirstMapped(
    RegExp(r'([+-]\d{2})(\d{2})$'),
    (Match m) => '${m[1]}:${m[2]}',
  );
  return DateTime.tryParse(normalized)?.toLocal();
}

const Set<String> _deviceKeys = <String>{
  'deviceno',
  'device_no',
  'devno',
  'dev_no',
  'devicecode',
  'device_code',
  'waterdeviceno',
  'water_device_no',
  'waterdevicecode',
  'water_device_code',
  'meterno',
  'meter_no',
  'metercode',
  'meter_code',
};

String _deviceCode(Object? data, {int depth = 0}) {
  if (data is String) return depth == 0 ? data.trim() : '';
  if (data is num) return depth == 0 ? '$data' : '';
  if (data is Map) {
    for (final MapEntry<dynamic, dynamic> e in data.entries) {
      if (_deviceKeys.contains(e.key.toString().toLowerCase())) {
        final String v = _scalarText(e.value);
        if (v.isNotEmpty) return v;
      }
    }
    for (final Object? value in data.values) {
      final String found = _deviceCode(value, depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
  } else if (data is List) {
    for (final Object? value in data) {
      final String found = _deviceCode(value, depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

/// 按原样大小写匹配字段名，避免把 `orderSn`（20 位流水号）当成 `ordersn`。
String _pickExact(Map<dynamic, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    if (!map.containsKey(key)) continue;
    final String value = _scalarText(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// 结账接口的 `ordersn` 实际是开阀返回的 `data.id`（网页端 `obj.id`）。
String _scanOrderIdOf(Object? data) {
  if (data is Map) {
    final String direct = _pickExact(data, const <String>['id', 'ID']);
    if (direct.isNotEmpty) return direct;
    final String other = _pickExact(data, const <String>[
      'ordersn',
      'ORDERSN',
      'order_id',
      'orderid',
    ]);
    if (other.isNotEmpty) return other;
    for (final Object? value in data.values) {
      final String found = _scanOrderIdOf(value);
      if (found.isNotEmpty) return found;
    }
  } else if (data is List) {
    for (final Object? value in data) {
      final String found = _scanOrderIdOf(value);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

/// `orderingTips` 返回的大写字段中，`ORDERSN` 即待结算订单 id。
String _unsettledIdOf(Object? data) {
  if (data is Map) {
    final String direct = _pickExact(data, const <String>[
      'ORDERSN',
      'ordersn',
      'order_id',
      'orderid',
      'id',
      'ID',
    ]);
    if (direct.isNotEmpty) return direct;
    for (final Object? value in data.values) {
      final String found = _unsettledIdOf(value);
      if (found.isNotEmpty) return found;
    }
  } else if (data is List) {
    for (final Object? value in data) {
      final String found = _unsettledIdOf(value);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

/// 开阀时冻结的押金（`freeznamount`，当前为 10 元）。
String _freezeAmountOf(Object? data) {
  if (data is Map) {
    final String direct = _pickExact(data, const <String>[
      'freeznamount',
      'FREEZNAMOUNT',
      'freezeAmount',
      'freezeamount',
      'freeze_amount',
    ]);
    if (direct.isNotEmpty) return direct;
    for (final Object? value in data.values) {
      final String found = _freezeAmountOf(value);
      if (found.isNotEmpty) return found;
    }
  } else if (data is List) {
    for (final Object? value in data) {
      final String found = _freezeAmountOf(value);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

String _valveCodeOf(Object? data) {
  if (data is Map) {
    final String direct = _pickExact(data, const <String>[
      'VALVECODE',
      'valvecode',
      'valveCode',
      'valve_code',
    ]);
    if (direct.isNotEmpty) return direct;
    for (final Object? value in data.values) {
      final String found = _valveCodeOf(value);
      if (found.isNotEmpty) return found;
    }
  } else if (data is List) {
    for (final Object? value in data) {
      final String found = _valveCodeOf(value);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

/// 二维码内容可能是纯设备号、URL 参数或 JSON。
String _deviceFromQr(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return '';
  if (text.startsWith('{') || text.startsWith('[')) {
    try {
      final String code = _deviceCode(jsonDecode(text));
      if (code.isNotEmpty) return code;
    } catch (_) {
      // 不是 JSON，继续按文本处理。
    }
  }
  final Uri? uri = Uri.tryParse(text);
  if (uri != null && uri.hasQuery) {
    for (final MapEntry<String, String> e in uri.queryParameters.entries) {
      if (_deviceKeys.contains(e.key.toLowerCase()) &&
          e.value.trim().isNotEmpty) {
        return e.value.trim();
      }
    }
  }
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.pathSegments.isNotEmpty) {
    final String last = uri.pathSegments.last;
    if (RegExp(r'^[A-Za-z0-9_-]{4,}$').hasMatch(last)) return last;
  }
  return text;
}

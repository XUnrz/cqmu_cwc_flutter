import 'package:flutter/material.dart';

import '../services/app_state.dart';
import 'payment_code_page.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/my_tab.dart';

/// 主界面：底部导航（窄屏）/ 侧栏（宽屏）。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.app});

  final AppState app;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  String? _catalogModule;
  bool _expiredDialogShown = false;

  @override
  void initState() {
    super.initState();
    widget.app.client.onTokenExpired = _handleTokenExpired;
  }

  void _openCatalog([String? module]) {
    setState(() {
      _index = 1;
      _catalogModule = module;
    });
  }

  void _openPaymentCode() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentCodePage(app: widget.app),
      ),
    );
  }

  void _handleTokenExpired() {
    if (_expiredDialogShown || !mounted) return;
    _expiredDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.key_off_outlined),
        title: const Text('登录状态已失效'),
        content: const Text('请重新登录后继续使用。'),
        actions: <Widget>[
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _expiredDialogShown = false;
              Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
              widget.app.signOut();
            },
            child: const Text('重新登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      HomeTab(app: widget.app, onOpenCatalog: _openCatalog),
      CatalogTab(
        app: widget.app,
        initialModule: _catalogModule,
        onModuleConsumed: () => _catalogModule = null,
      ),
      MyTab(app: widget.app),
    ];
    const List<(IconData, IconData, String)> destinations =
        <(IconData, IconData, String)>[
      (Icons.dashboard_outlined, Icons.dashboard, '首页'),
      (Icons.api_outlined, Icons.api, '接口'),
      (Icons.person_outline, Icons.person, '我的'),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 840;
        final Widget body = IndexedStack(index: _index, children: tabs);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.credit_card, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('重医一卡通'),
              ],
            ),
            actions: <Widget>[
              IconButton(
                key: const Key('home-payment-code'),
                tooltip: '付款码',
                icon: const Icon(Icons.qr_code_2),
                onPressed: _openPaymentCode,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (int i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (final (IconData icon, IconData selected, String label)
                            in destinations)
                          NavigationRailDestination(
                            icon: Icon(icon),
                            selectedIcon: Icon(selected),
                            label: Text(label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: body,
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (int i) => setState(() => _index = i),
                  destinations: <NavigationDestination>[
                    for (final (IconData icon, IconData selected, String label)
                        in destinations)
                      NavigationDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: label,
                      ),
                  ],
                ),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
                  key: const Key('home-payment-code-fab'),
                  onPressed: _openPaymentCode,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('付款码'),
                ),
          floatingActionButtonLocation:
              wide ? null : FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/app_state.dart';

/// 应用根组件：恢复本地会话后决定进入登录页还是主界面。
class CwcApp extends StatefulWidget {
  const CwcApp({super.key, this.app});

  final AppState? app;

  @override
  State<CwcApp> createState() => _CwcAppState();
}

class _CwcAppState extends State<CwcApp> {
  late final AppState _app = widget.app ?? AppState();

  @override
  void initState() {
    super.initState();
    _app.restore();
  }

  @override
  void dispose() {
    if (widget.app == null) _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: '重医一卡通',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: _app.themeMode,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _app.restoring
              ? const _SplashPage()
              : _app.isLoggedIn
                  ? HomePage(app: _app)
                  : LoginPage(app: _app),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _app.accent.seed,
        brightness: brightness,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.credit_card, size: 56),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/navigation/app_navigation.dart';
import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkingTrust',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigation.navigatorKey,
      scaffoldMessengerKey: AppNavigation.messengerKey,
      theme: AppTheme.lightTheme,
      initialRoute: RouteNames.splash,
      routes: AppRoutes.routes,
    );
  }
}

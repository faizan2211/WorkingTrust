import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'core/network/session_store.dart';
import 'features/notifications/services/fcm_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.enableLogging) {
    debugPrint('[API] Backend ${AppConfig.backendUrl}');
  }
  // Any cookies from the last run have to be back in memory before the splash
  // asks the backend whether this device is still signed in.
  await SessionStore.instance.load();
  await FcmPushService.instance.initialize();
  runApp(const App());
}

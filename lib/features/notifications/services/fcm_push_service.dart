import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../app/routes/route_names.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../firebase_options.dart';
import '../controller/notification_controller.dart';
import 'notification_service.dart';

class PushDestination {
  const PushDestination(this.route, {this.arguments});

  final String route;
  final Object? arguments;
}

class FcmPushService {
  FcmPushService._();

  static final FcmPushService instance = FcmPushService._();
  static const String _tokenStorageKey = 'fcm.registration-token.v1';
  static const String _notificationChannelId = 'workingtrust_notifications_v2';
  static const String _notificationChannelName = 'WorkingTrust notifications';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const Duration _logoutRequestTimeout = Duration(seconds: 4);
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final ApiClient _apiClient = ApiClient();
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Map<String, String>? _pendingOpen;
  bool _initialized = false;
  bool _authenticated = false;
  bool _authResolved = false;
  bool _navigationReady = false;
  bool _registeringToken = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await _initializeLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
        onError: (Object error) =>
            _log('Foreground message listener failed', error),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpen,
        onError: (Object error) =>
            _log('Notification tap listener failed', error),
      );
      _tokenSubscription = messaging.onRegistered.listen(
        (token) => unawaited(_registerRefreshedToken(token)),
        onError: (Object error) => _log('FCM registration failed', error),
      );

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleOpen(initialMessage);
      final localLaunch = await _localNotifications
          .getNotificationAppLaunchDetails();
      final localPayload = localLaunch?.notificationResponse?.payload;
      if (localLaunch?.didNotificationLaunchApp == true) {
        _handleLocalOpen(localPayload);
      }
    } on FirebaseException catch (error) {
      _log('Firebase initialization failed (${error.code})', error);
    } on UnsupportedError catch (error) {
      _log('Firebase is not configured for this platform', error);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleLocalOpen(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _notificationChannelId,
            _notificationChannelName,
            description: 'Messages and updates from WorkingTrust',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
  }

  /// Called after login or session restoration; push setup must never block auth.
  Future<void> setAuthenticated(bool authenticated) async {
    _authResolved = true;
    _authenticated = authenticated;
    if (!authenticated) {
      _pendingOpen = null;
      return;
    }

    _flushPendingOpen();
    if (_navigationReady) await _registerCurrentTokenSafely();
  }

  void markNavigationReady() {
    _navigationReady = true;
    _flushPendingOpen();
    if (_authenticated) unawaited(_registerCurrentTokenSafely());
  }

  Future<void> signOut() async {
    _authResolved = true;
    _authenticated = false;
    _pendingOpen = null;
    _navigationReady = false;

    final tokens = <String>{};
    try {
      final storedToken = await _storage.read(key: _tokenStorageKey);
      if (storedToken != null && storedToken.isNotEmpty) {
        tokens.add(storedToken);
      }

      for (final token in tokens) {
        await _apiClient
            .delete(ApiEndpoints.fcmToken, body: {'token': token})
            .timeout(_logoutRequestTimeout);
      }
    } catch (error) {
      _log('Unable to deactivate this device token during sign-out', error);
    } finally {
      try {
        await _storage.delete(key: _tokenStorageKey);
      } catch (error) {
        _log('Unable to clear the saved FCM token', error);
      }
    }
  }

  static PushDestination destinationFor(Map<String, String> data) {
    final type = data['type'] ?? '';
    final href = Uri.tryParse(data['href'] ?? '');

    if (href?.path == '/messages' || href?.path == '/admin/messages') {
      final taskId = href?.queryParameters['task'];
      if (taskId != null && taskId.isNotEmpty) {
        return PushDestination(RouteNames.projectChat, arguments: taskId);
      }
    }

    if ((href?.path == '/settings' &&
            href?.queryParameters['tab'] == 'withdrawals') ||
        type == 'WITHDRAWAL_REQUESTED' ||
        type == 'WITHDRAWAL_PAID' ||
        type == 'WITHDRAWAL_REJECTED' ||
        type == 'DEPOSIT_APPROVED' ||
        type == 'DEPOSIT_REJECTED' ||
        type == 'SUBMISSION_APPROVED') {
      return const PushDestination(RouteNames.transactions);
    }

    return switch (type) {
      'BID_AWARDED' ||
      'BID_REJECTED' ||
      'SUBMISSION_REJECTED' => const PushDestination(RouteNames.proposals),
      'MEMBERSHIP_RENEWED' => const PushDestination(RouteNames.membershipPlan),
      'SECURITY' => const PushDestination(RouteNames.settings, arguments: 1),
      'REPORT_UPDATE' ||
      'ACCOUNT_SUSPENDED' => const PushDestination(RouteNames.yourReports),
      _ => switch (href?.path) {
        '/buy-bids' => const PushDestination(RouteNames.transactions),
        '/wallet' || '/deposit' => const PushDestination(RouteNames.wallet),
        '/my-work' => const PushDestination(RouteNames.proposals),
        '/report' => const PushDestination(RouteNames.yourReports),
        '/membership' => const PushDestination(RouteNames.membershipPlan),
        '/dashboard' || '/find-work' => const PushDestination(RouteNames.home),
        _ => const PushDestination(RouteNames.notifications),
      },
    };
  }

  Future<void> _registerCurrentToken() async {
    if (_registeringToken) return;
    final messaging = _messaging;
    if (messaging == null) return;

    _registeringToken = true;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await _deactivateSavedToken();
        return;
      }

      await messaging.register();
    } finally {
      _registeringToken = false;
    }
  }

  Future<void> _registerCurrentTokenSafely() async {
    try {
      await _registerCurrentToken();
    } catch (error) {
      _log('Unable to register this device for push notifications', error);
    }
  }

  Future<void> _registerToken(String token) async {
    if (!_authenticated) return;
    final platform = _platformName;
    if (platform == null) return;

    final previousToken = await _storage.read(key: _tokenStorageKey);
    await _apiClient.post(
      ApiEndpoints.fcmToken,
      body: {
        'token': token,
        'platform': platform,
        if (previousToken != null && previousToken != token)
          'previousToken': previousToken,
      },
    );
    await _storage.write(key: _tokenStorageKey, value: token);
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      await _registerToken(token);
    } catch (error) {
      _log('FCM token registration failed', error);
    }
  }

  String? get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  Future<void> _deactivateSavedToken() async {
    try {
      final token = await _storage.read(key: _tokenStorageKey);
      if (token == null || token.isEmpty) return;
      await _apiClient.delete(ApiEndpoints.fcmToken, body: {'token': token});
      await _storage.delete(key: _tokenStorageKey);
    } catch (error) {
      _log('Unable to deactivate a token after permission was denied', error);
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    unawaited(_syncNotification(null));

    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? '';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final data = _messageData(message);
    try {
      await _localNotifications.show(
        (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) &
            0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            channelDescription: 'Messages and updates from WorkingTrust',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (error) {
      _log('Unable to show foreground notification', error);
    }
  }

  void _handleOpen(RemoteMessage message) {
    _handleOpenData(_messageData(message));
  }

  Map<String, String> _messageData(RemoteMessage message) => <String, String>{
    for (final entry in message.data.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };

  void _handleLocalOpen(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _handleOpenData({
          for (final entry in decoded.entries)
            if (entry.value != null) entry.key: entry.value.toString(),
        });
      }
    } on FormatException catch (error) {
      _log('Invalid local notification payload', error);
    }
  }

  void _handleOpenData(Map<String, String> data) {
    if (_authResolved && !_authenticated) return;
    _pendingOpen = data;
    _flushPendingOpen();
  }

  void _flushPendingOpen() {
    final data = _pendingOpen;
    if (data == null ||
        !_authResolved ||
        !_authenticated ||
        !_navigationReady) {
      return;
    }

    final navigator = AppNavigation.navigatorKey.currentState;
    if (navigator == null) return;

    _pendingOpen = null;
    final destination = destinationFor(data);
    navigator.pushNamed(destination.route, arguments: destination.arguments);
    unawaited(_syncNotification(data['id']));
  }

  Future<void> _syncNotification(String? id) async {
    if (id != null && id.isNotEmpty) {
      try {
        await NotificationService.instance.markRead(id);
      } catch (error) {
        _log('Unable to mark the opened notification as read', error);
      }
    }
    try {
      await NotificationController.instance.refresh(silent: true);
    } catch (error) {
      _log('Unable to sync the notification feed', error);
    }
  }

  void _log(String message, Object error) {
    final details = switch (error) {
      FirebaseException() =>
        ' [${error.plugin}/${error.code}] ${error.message ?? ''}',
      _ => ' $error',
    };
    debugPrint('[FCM] $message (${error.runtimeType})$details');
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}

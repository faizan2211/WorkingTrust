import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/notifications/services/fcm_push_service.dart';

void main() {
  group('FCM notification destinations', () {
    test('opens the project chat from its task href', () {
      final destination = FcmPushService.destinationFor({
        'type': 'CHAT_MESSAGE',
        'href': '/messages?task=task-42',
      });

      expect(destination.route, RouteNames.projectChat);
      expect(destination.arguments, 'task-42');
    });

    test('opens the withdrawal settings tab', () {
      final destination = FcmPushService.destinationFor({
        'type': 'WITHDRAWAL_PAID',
        'href': '/settings?tab=withdrawals',
      });

      expect(destination.route, RouteNames.settings);
      expect(destination.arguments, 4);
    });

    test('opens withdrawal notices in the withdrawal settings tab', () {
      for (final type in const [
        'WITHDRAWAL_REQUESTED',
        'WITHDRAWAL_PAID',
        'WITHDRAWAL_REJECTED',
      ]) {
        final destination = FcmPushService.destinationFor({'type': type});
        expect(destination.route, RouteNames.settings, reason: type);
        expect(destination.arguments, 4, reason: type);
      }
    });

    test('opens security notices in security settings', () {
      final destination = FcmPushService.destinationFor({
        'type': 'SECURITY',
        'href': '/settings',
      });

      expect(destination.route, RouteNames.settings);
      expect(destination.arguments, 1);
    });

    test('maps financial, membership, report, and proposal notices', () {
      expect(
        FcmPushService.destinationFor({
          'type': 'DEPOSIT_APPROVED',
          'href': '/deposit',
        }).route,
        RouteNames.wallet,
      );
      expect(
        FcmPushService.destinationFor({'type': 'MEMBERSHIP_RENEWED'}).route,
        RouteNames.membershipPlan,
      );
      expect(
        FcmPushService.destinationFor({'type': 'REPORT_UPDATE'}).route,
        RouteNames.yourReports,
      );
      expect(
        FcmPushService.destinationFor({'type': 'BID_REJECTED'}).route,
        RouteNames.proposals,
      );
    });

    test('unknown notifications open the in-app notification list', () {
      final destination = FcmPushService.destinationFor({
        'type': 'UNRECOGNIZED',
        'href': '/admin/reports',
      });

      expect(destination.route, RouteNames.notifications);
    });
  });
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/module_app_bar.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/find_work/models/project_model.dart';
import '../../features/find_work/screens/project_detail_screen.dart';
import '../../features/find_work/screens/submit_proposal_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/membership/screens/membership_plan_screen.dart';
import '../../features/messages/screens/project_chat_screen.dart';
import '../../features/profile/screens/add_portfolio_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/overview_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/proposals_screen.dart';
import '../../features/profile/screens/stats_screen.dart';
import '../../features/profile/screens/transactions_screen.dart';
import '../../features/profile/screens/your_reports_screen.dart';
import '../../features/profile/screens/wallet_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import 'route_names.dart';

class AppRoutes {
  AppRoutes._();

  static final Map<String, WidgetBuilder> routes = {
    RouteNames.splash: (context) => const SplashScreen(),
    RouteNames.onboarding: (context) => const OnboardingScreen(),
    RouteNames.login: (context) => const LoginScreen(),
    RouteNames.signup: (context) => const SignupScreen(),
    RouteNames.forgotPassword: (context) => const ForgotPasswordScreen(),
    RouteNames.emailVerification: (context) => EmailVerificationScreen(
      email: ModalRoute.of(context)?.settings.arguments as String?,
    ),
    RouteNames.resetPassword: (context) => ResetPasswordScreen(
      resetToken: ModalRoute.of(context)?.settings.arguments as String? ?? '',
    ),
    RouteNames.home: (context) => const HomeScreen(),
    RouteNames.projectDetail: (context) => ProjectDetailScreen(
      project: ModalRoute.of(context)!.settings.arguments as ProjectModel,
    ),
    RouteNames.submitProposal: (context) => SubmitProposalScreen(
      project: ModalRoute.of(context)!.settings.arguments as ProjectModel,
    ),
    RouteNames.projectChat: (context) => ProjectChatScreen(
      taskId: ModalRoute.of(context)?.settings.arguments as String? ?? '',
    ),
    RouteNames.profile: (context) => const ProfileScreen(),
    RouteNames.editProfile: (context) => const EditProfileScreen(),
    RouteNames.addPortfolio: (context) => const AddPortfolioScreen(),
    RouteNames.overview: (context) => const OverviewScreen(),
    RouteNames.stats: (context) => const StatsScreen(),
    RouteNames.transactions: (context) => const TransactionsScreen(),
    // The wallet is a bare body, so it is pushed under the tinted bar the
    // other modules wear.
    RouteNames.wallet: (context) => const Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModuleAppBar(
        title: 'Wallet',
        subtitle: 'Balance, connects & activity',
      ),
      body: WalletScreen(),
    ),
    RouteNames.proposals: (context) => const ProposalsScreen(),
    RouteNames.yourReports: (context) => const YourReportsScreen(),
    // A tab index opens the section another screen pointed the account at.
    RouteNames.settings: (context) => SettingsScreen(
      initialTab: ModalRoute.of(context)?.settings.arguments as int? ?? 0,
    ),
    // The pricing screen is a bare body, so pushed on its own it gets the
    // Scaffold and title the shell used to give it.
    RouteNames.membershipPlan: (context) => Scaffold(
      appBar: const ModuleAppBar(
        title: 'Membership Plan',
        subtitle: 'Pricing tiers and their benefits',
      ),
      body: const MembershipPlanScreen(),
    ),
    RouteNames.notifications: (context) => const NotificationsScreen(),
  };
}

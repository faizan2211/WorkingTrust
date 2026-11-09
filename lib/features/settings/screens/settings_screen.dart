import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/overview_controller.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/controller/withdrawals_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../tabs/billing_payments_tab.dart';
import '../tabs/contact_info_tab.dart';
import '../tabs/notification_tab.dart';
import '../tabs/password_security_tab.dart';
import '../tabs/profile_setting_tab.dart';
import '../tabs/withdrawals_tab.dart';

/// Sectioned settings with a scrollable tab bar.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.initialTab = 0});

  /// Defaults to the first section; another screen can ask for the one it
  /// pointed the account at.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: SettingsData.tabs.length,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: ModuleAppBar(
          title: 'Settings',
          subtitle: 'App preferences',
          bottom: TabBar(
            isScrollable: true,
            // The scrollable default indents the first label away from the
            // cards below it.
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.symmetric(horizontal: AppDimensions.md),
            labelColor: ModuleAppBar.tabBarLabel,
            unselectedLabelColor: ModuleAppBar.tabBarUnselected,
            indicatorColor: ModuleAppBar.tabBarIndicator,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              for (final tab in SettingsData.tabs) Tab(text: tab, height: 48),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bodyWidth = constraints.maxWidth > 760
                  ? 760.0
                  : constraints.maxWidth;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bodyWidth),
                  child: TabBarView(
                    children: [
                      for (final page in const [
                        ProfileSettingTab(),
                        PasswordSecurityTab(),
                        ContactInfoTab(),
                        NotificationTab(),
                        WithdrawalsTab(),
                        BillingPaymentsTab(),
                      ])
                        RefreshIndicator(
                          onRefresh: () async {
                            await AccountController.instance.load(force: true);
                            await AccountController.instance.loadMethods(
                              force: true,
                            );
                            await ProfileController.instance.load(force: true);
                            // The money figures only live on the Withdrawals
                            // page, so pulling any other tab asks for none of
                            // them.
                            if (page is! WithdrawalsTab) return;
                            await OverviewController.instance.refresh();
                            await WithdrawalsController.instance.refresh();
                            await WalletController.instance.refresh();
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppDimensions.md),
                            child: page,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

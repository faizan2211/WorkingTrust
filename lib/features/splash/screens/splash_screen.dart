import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/asset_constants.dart';
import '../../auth/controller/auth_controller.dart';
import '../../auth/models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _showTitle = false;
  bool _showSubtitle = false;
  bool _navigated = false;
  bool _animationsDone = false;
  bool _sessionKnown = false;
  UserModel? _session;
  final AuthController _authController = AuthController();
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );
    _scaleController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showTitle = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSubtitle = true);
    });
    // Asked in parallel with the intro: whoever is slower decides the route.
    _resolveSession();
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || _navigated) return;
      _animationsDone = true;
      _goNext();
    });
  }

  Future<void> _resolveSession() async {
    final user = await _authController.restoreSession();
    if (!mounted) return;
    _sessionKnown = true;
    _session = user;
    if (_animationsDone) _goNext();
  }

  void _goNext() {
    if (_navigated || !_animationsDone || !_sessionKnown) return;
    _navigated = true;
    Navigator.pushReplacementNamed(
      context,
      _session == null ? RouteNames.onboarding : RouteNames.home,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                AssetConstants.logo,
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _showTitle ? 1.0 : 0.0,
              child: const Text(
                'WorkingTrust',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _showSubtitle ? 1.0 : 0.0,
              child: Text(
                'Build trust, grow together',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
            const Spacer(flex: 3),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _marqueeKey = GlobalKey<_MarqueeBannerState>();
  int _currentPage = 0;
  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _marqueeKey.currentState?.stop();
      Navigator.pushReplacementNamed(context, RouteNames.login);
    }
  }

  void _skipToLogin() {
    _marqueeKey.currentState?.stop();
    Navigator.pushReplacementNamed(context, RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _skipToLogin,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _HeroPage(marqueeKey: _marqueeKey),
                  const _ServicesPage(),
                  const _SafetyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
                vertical: AppDimensions.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isActive ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textHint.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? 'Get Started'
                              : 'Next',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        if (_currentPage < _totalPages - 1) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Page 1: Hero
// ---------------------------------------------------------------------------

class _HeroPage extends StatefulWidget {
  final GlobalKey<_MarqueeBannerState> marqueeKey;
  const _HeroPage({required this.marqueeKey});

  @override
  State<_HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<_HeroPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5500),
  );
  bool _typed = false;

  @override
  void initState() {
    super.initState();
    _typing.addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _typed = true);
    });
    _typing.forward();
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.sm),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.15,
                letterSpacing: -0.5,
              ),
              children: [
                const TextSpan(text: 'Over '),
                TextSpan(
                  text: '4500+',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' Jobs\nWaiting For You'),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Connect with trusted experts to get high-quality work done with confidence.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CategoryChip(label: 'UI/UX Design'),
              _CategoryChip(label: 'Mobile App Development'),
              _CategoryChip(label: 'Web Development'),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: _typed
                  ? const _HeroPhoto(key: ValueKey('photo'))
                  : _TypingIntro(
                      key: const ValueKey('typing'),
                      controller: _typing,
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final fullWidth = constraints.maxWidth + AppDimensions.lg * 2;
              return OverflowBox(
                minWidth: fullWidth,
                maxWidth: fullWidth,
                fit: OverflowBoxFit.deferToChild,
                alignment: Alignment.center,
                child: MarqueeBanner(key: widget.marqueeKey),
              );
            },
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}

/// The photo shown once the typing intro finishes.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Image.network(
        'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=600&h=300&fit=crop',
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 160,
            color: AppColors.surfaceVariant,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stack) {
          return Container(
            height: 160,
            color: AppColors.surfaceVariant,
            child: const Icon(
              Icons.broken_image,
              color: AppColors.textHint,
              size: 40,
            ),
          );
        },
      ),
    );
  }
}

/// Plays before [_HeroPhoto]: a short "client is typing a job brief" clip.
class _TypingIntro extends StatelessWidget {
  final AnimationController controller;
  const _TypingIntro({super.key, required this.controller});

  static const String _script =
      'Hiring: Flutter Developer\n'
      'Budget: \$800 | 3 weeks\n'
      'Need a clean, responsive UI\n'
      'for a job app. Start ASAP.';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // typing runs over the first 85%, the rest is a hold before the swap
        final progress = (controller.value / 0.85).clamp(0.0, 1.0);
        final typed = _script.substring(0, (_script.length * progress).floor());
        final caretVisible = ((controller.value * 12).floor() % 2) == 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppDimensions.radiusLg),
            ),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLIENT IS TYPING...',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.primary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(text: typed),
                    TextSpan(
                      text: '|',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: caretVisible
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marquee Banner — infinite right-to-left scrolling logo strip
// ---------------------------------------------------------------------------

class MarqueeBanner extends StatefulWidget {
  final double height;
  final Duration duration;
  final double logoHeight;
  final double spacing;
  final Color backgroundColor;

  const MarqueeBanner({
    super.key,
    this.height = 56,
    this.duration = const Duration(seconds: 18),
    this.logoHeight = 28,
    this.spacing = 32,
    this.backgroundColor = AppColors.accent,
  });

  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeLogo {
  final String? label;
  final String? imagePath;
  const _MarqueeLogo({this.label, this.imagePath});
}

class _MarqueeBannerState extends State<MarqueeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _contentKey = GlobalKey();
  double _halfWidth = 0;

  static const List<_MarqueeLogo> _baseLogos = [
    _MarqueeLogo(label: 'Google'),
    _MarqueeLogo(label: 'Webflow'),
    _MarqueeLogo(label: 'YouTube', imagePath: 'assets/logos/youtube.png'),
    _MarqueeLogo(label: 'Pinterest', imagePath: 'assets/logos/pinterest.png'),
    _MarqueeLogo(label: 'Facebook'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHalfWidth();
      _controller.repeat();
    });
  }

  void _measureHalfWidth() {
    if (!mounted) return;
    final renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final fullWidth = renderBox.size.width;
      if (fullWidth > 0 && fullWidth / 2 != _halfWidth) {
        setState(() => _halfWidth = fullWidth / 2);
      }
    }
  }

  void stop() {
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildLogoRow() {
    final items = <Widget>[];
    for (final logo in _baseLogos) {
      items.add(_LogoItem(logo: logo, logoHeight: widget.logoHeight));
      items.add(SizedBox(width: widget.spacing));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final logos = _buildLogoRow();

    return ClipRect(
      child: Container(
        height: widget.height,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-_controller.value * _halfWidth, 0),
                child: child,
              );
            },
            child: Row(
              key: _contentKey,
              mainAxisSize: MainAxisSize.min,
              children: [...logos, ...logos],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoItem extends StatelessWidget {
  final _MarqueeLogo logo;
  final double logoHeight;
  const _LogoItem({required this.logo, required this.logoHeight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: logoHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo.imagePath != null) ...[
            Image.asset(
              logo.imagePath!,
              height: logoHeight * 0.7,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            logo.label ?? '',
            style: TextStyle(
              fontSize: logoHeight * 0.52,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Pick your craft
// ---------------------------------------------------------------------------

class _ServicesPage extends StatefulWidget {
  const _ServicesPage();

  static const List<_ServiceItem> _services = [
    _ServiceItem(Icons.palette_outlined, 'UI/UX Design'),
    _ServiceItem(Icons.auto_awesome_outlined, 'AI Development'),
    _ServiceItem(Icons.code_outlined, 'Web Development'),
    _ServiceItem(Icons.analytics_outlined, 'Data Analysis'),
    _ServiceItem(Icons.data_object, 'Backend Development'),
    _ServiceItem(Icons.phone_android_outlined, 'App Development'),
    _ServiceItem(Icons.memory, 'Machine Learning'),
    _ServiceItem(Icons.wordpress, 'WordPress'),
    _ServiceItem(Icons.smart_display_outlined, 'Video Editor'),
    _ServiceItem(Icons.travel_explore, 'SEO'),
    _ServiceItem(Icons.design_services_outlined, 'Graphics Design'),
    _ServiceItem(Icons.shopping_bag_outlined, 'Shopify'),
    _ServiceItem(Icons.view_in_ar_outlined, '3D Modeling'),
    _ServiceItem(Icons.campaign_outlined, 'Affiliate Marketing'),
    _ServiceItem(Icons.calculate_outlined, 'Accounting'),
    _ServiceItem(Icons.shopping_cart_outlined, 'Amazon / Daraz'),
    _ServiceItem(Icons.play_circle_outline, 'YouTube'),
    _ServiceItem(Icons.change_history, 'Framer'),
    _ServiceItem(Icons.api, 'API Integration'),
    _ServiceItem(Icons.verified_user_outlined, 'Cybersecurity'),
    _ServiceItem(Icons.bug_report_outlined, 'App Testing'),
    _ServiceItem(Icons.smart_toy_outlined, 'Chatbots & Automation'),
    _ServiceItem(Icons.edit_note, 'Content Writing'),
    _ServiceItem(Icons.ads_click, 'Google Ads'),
    _ServiceItem(Icons.animation, 'Motion Graphics'),
    _ServiceItem(Icons.code_off, 'No-Code Development'),
    _ServiceItem(Icons.smart_toy, 'AI Agents'),
  ];

  @override
  State<_ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<_ServicesPage> {
  static const int _featuredCount = 12;

  /// Hue families so neighbouring tiles separate by colour as well as glyph.
  static const List<Color> _families = [
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.info,
    AppColors.secondary,
    AppColors.warning,
    AppColors.primaryDark,
  ];

  final Set<String> _selected = <String>{};
  final TextEditingController _filter = TextEditingController();
  bool _showAll = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<_ServiceItem> _matching(List<_ServiceItem> items) {
    final query = _filter.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((s) => s.label.toLowerCase().contains(query)).toList();
  }

  void _toggle(String label) => setState(() {
    if (!_selected.remove(label)) _selected.add(label);
  });

  @override
  Widget build(BuildContext context) {
    final all = _ServicesPage._services;
    final featured = _matching(all.take(_featuredCount).toList());
    final rest = _matching(all.skip(_featuredCount).toList());
    final visible = _showAll ? [...featured, ...rest] : featured;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.md),
          const Text(
            'Pick your craft.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap what you do. Your picks pre-fill the Find Work filters after '
            'signup — skipping this step loses nothing.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          _FilterField(
            controller: _filter,
            shown: visible.length,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 560
                  ? 4
                  : width >= 400
                  ? 3
                  : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisExtent: 92,
                mainAxisSpacing: AppDimensions.sm,
                crossAxisSpacing: AppDimensions.sm,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    _InterestTile(
                      item: visible[i],
                      selected: _selected.contains(visible[i].label),
                      tint:
                          _families[(i + visible[i].label.length) %
                              _families.length],
                      onTap: () => _toggle(visible[i].label),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimensions.sm),
          _SelectionBar(
            count: _selected.length,
            onClear: () => setState(_selected.clear),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showAll = !_showAll),
            icon: Icon(
              _showAll ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _showAll
                  ? 'Hide the full catalogue'
                  : 'All services · ${all.length - _featuredCount} more',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radius),
              ),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String label;
  const _ServiceItem(this.icon, this.label);
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final int shown;
  final VoidCallback onChanged;
  const _FilterField({
    required this.controller,
    required this.shown,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.textFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search services',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$shown shown',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  final _ServiceItem item;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;
  const _InterestTile({
    required this.item,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radius),
            border: Border.all(
              color: selected ? tint : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    child: Icon(item.icon, color: tint, size: 17),
                  ),
                  const Spacer(),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    scale: selected ? 1 : 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: selected ? tint : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  const _SelectionBar({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasPicks = count > 0;
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        height: hasPicks ? 56 : 0,
        margin: EdgeInsets.only(bottom: hasPicks ? AppDimensions.md : 0),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: hasPicks
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count selected · carried into Find Work',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: How the money is held
// ---------------------------------------------------------------------------

class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  static const List<_SafetyItem> _features = [
    _SafetyItem(
      Icons.add_circle_outline,
      'Clear Projects',
      'Every job shows the price, requirements, and expected deliverables before you apply.',
    ),
    _SafetyItem(
      Icons.account_balance_wallet_outlined,
      'Local Payments',
      'Deposit and withdraw securely through EasyPaisa or bank payments, with transactions verified by our team.',
    ),
    _SafetyItem(
      Icons.headset_mic_outlined,
      'Guided Support',
      'After selection, communicate with your client directly through the platform until the project is completed.',
    ),
    _SafetyItem(
      Icons.verified_outlined,
      'Fair Selection',
      'Submit your proposal and let our team select the right expert for each project based on the project requirements.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.md),
          const Text(
            'Money waits until\nthe work is done.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every project on WorkingTrust moves through the same five '
            'checks. Nothing is released early, and nothing disappears.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          const _EscrowTimeline(),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'What that means for you',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          for (var i = 0; i < _features.length; i++)
            _SafetyFeature(index: i + 1, item: _features[i]),
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}

class _SafetyItem {
  final IconData icon;
  final String title;
  final String description;
  const _SafetyItem(this.icon, this.title, this.description);
}

class _EscrowStage {
  final String label;
  final IconData icon;
  const _EscrowStage(this.label, this.icon);
}

/// Draws the funded-in-escrow route once, left to right, on first build.
class _EscrowTimeline extends StatefulWidget {
  const _EscrowTimeline();

  static const List<_EscrowStage> _stages = [
    _EscrowStage('Brief', Icons.description_outlined),
    _EscrowStage('Match', Icons.groups_outlined),
    _EscrowStage('Escrow', Icons.lock_outline),
    _EscrowStage('Deliver', Icons.upload_file_outlined),
    _EscrowStage('Paid', Icons.paid_outlined),
  ];

  @override
  State<_EscrowTimeline> createState() => _EscrowTimelineState();
}

class _EscrowTimelineState extends State<_EscrowTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run.forward();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const nodeSize = 40.0;
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final stages = _EscrowTimeline._stages;
            final step = constraints.maxWidth / stages.length;
            final firstCenter = step / 2;
            final span = constraints.maxWidth - step;
            final fill = (span * _run.value).clamp(0.0, span);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: nodeSize,
                  child: Stack(
                    children: [
                      Positioned(
                        left: firstCenter,
                        top: nodeSize / 2 - 1.5,
                        width: span,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: firstCenter,
                        top: nodeSize / 2 - 1.5,
                        width: fill,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < stages.length; i++)
                            Expanded(
                              child: _TimelineNode(
                                stage: stages[i],
                                index: i,
                                reached:
                                    firstCenter + step * i <=
                                    firstCenter + fill,
                                nodeSize: nodeSize,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final stage in stages)
                      Expanded(
                        child: Text(
                          stage.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final _EscrowStage stage;
  final int index;
  final bool reached;
  final double nodeSize;
  const _TimelineNode({
    required this.stage,
    required this.index,
    required this.reached,
    required this.nodeSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: reached ? AppColors.primary : AppColors.border,
            width: 2,
          ),
          boxShadow: reached
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          reached ? Icons.check : stage.icon,
          size: nodeSize * 0.42,
          color: reached ? AppColors.textOnPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SafetyFeature extends StatelessWidget {
  final int index;
  final _SafetyItem item;
  const _SafetyFeature({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary.withValues(alpha: 0.35),
              height: 1.1,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.heading4.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Two-panel shell shared by sign-in and sign-up.
///
/// Wide screens get a gradient brand panel beside the form; narrow screens
/// collapse to a compact header above it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  /// Row shown under the card, e.g. "New here? Create an account".
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;

          final form = _FormPanel(
            title: title,
            subtitle: subtitle,
            compactHeader: !wide,
            footer: footer,
            child: child,
          );

          if (!wide) return SafeArea(child: form);

          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: SafeArea(child: form)),
            ],
          );
        },
      ),
    );
  }
}

/// Gradient marketing panel, wide screens only.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    (
      Icons.menu_book_rounded,
      'Free industry-based IT courses',
      'Web, mobile, AI, design, and more.',
    ),
    (
      Icons.fact_check_rounded,
      'Attendance and assignments',
      'Track attendance, assignments, and your progress in one place.',
    ),
    (
      Icons.workspace_premium_rounded,
      'Your path to success',
      'Build a portfolio and move toward your career.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryBright, AppColors.success],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft decorative blooms.
          Positioned(
            top: -70,
            right: -50,
            child: _Bloom(size: 230, opacity: 0.10),
          ),
          Positioned(
            bottom: -90,
            left: -60,
            child: _Bloom(size: 280, opacity: 0.08),
          ),
          SafeArea(
            // Scrolls rather than overflowing on short windows, but still
            // centres vertically whenever there is room: the ConstrainedBox
            // floor makes the Column at least as tall as the viewport.
            child: LayoutBuilder(
              builder: (context, panel) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 52,
                  vertical: 44,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: panel.maxHeight - 88, // minus vertical padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Bano Qabil',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Start your journey.\nBecome Qabil.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Free, industry-based IT education that helps you '
                        'learn, grow, and become Qabil.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 44),
                      ..._features.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  f.$1,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.$2,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.$3,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bloom({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// The scrolling form side, with a fade-and-rise entrance.
class _FormPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool compactHeader;
  final Widget child;
  final Widget? footer;

  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.compactHeader,
    required this.child,
    this.footer,
  });

  @override
  State<_FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<_FormPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.compactHeader) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryBright],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Bano Qabil',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                  Text(
                    widget.title,
                    textAlign: widget.compactHeader
                        ? TextAlign.center
                        : TextAlign.start,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    textAlign: widget.compactHeader
                        ? TextAlign.center
                        : TextAlign.start,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  widget.child,
                  if (widget.footer != null) ...[
                    const SizedBox(height: 22),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

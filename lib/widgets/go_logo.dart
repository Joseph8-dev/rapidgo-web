import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LogoConfig {
  const LogoConfig({
    this.asset = 'assets/brand/logo.png',
    this.aspect = 1.62,
    this.cropScale = 1.08,
    this.appBarHeight = 40,
    this.heroHeight = 132,
  });

  final String asset;
  final double aspect;
  final double cropScale;
  final double appBarHeight;
  final double heroHeight;

  static const LogoConfig standard = LogoConfig();
}

class GoLogo extends StatelessWidget {
  const GoLogo({
    super.key,
    this.height,
    this.config = LogoConfig.standard,
    this.variant = GoLogoVariant.hero,
  });

  const GoLogo.appBar({super.key, this.config = LogoConfig.standard})
      : height = null,
        variant = GoLogoVariant.appBar;

  final double? height;
  final LogoConfig config;
  final GoLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final h = height ??
        (variant == GoLogoVariant.appBar
            ? (compact ? config.appBarHeight : config.appBarHeight * 1.45)
            : config.heroHeight);
    final w = h * config.aspect;

    return SizedBox(
      height: h,
      width: w,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: h * config.cropScale,
          maxWidth: w * config.cropScale,
          child: Image.asset(
            config.asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _TextFallback(height: h),
          ),
        ),
      ),
    );
  }
}

enum GoLogoVariant { appBar, hero }

class _TextFallback extends StatelessWidget {
  const _TextFallback({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CONEXIÓN', style: AppText.display(height * 0.34, letterSpacing: 3)),
          Text('MONUMENTAL', style: AppText.display(height * 0.44, letterSpacing: 1)),
        ],
      ),
    );
  }
}

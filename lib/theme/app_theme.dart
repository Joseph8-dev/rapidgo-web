import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color midnight = Color(0xFF041941);

  static const Color skyDeep = Color(0xFF00A4FF);

  static const Color skyLight = Color(0xFF99E0FF);

  static const Color grayLight = Color(0xFFD8D8D8);

  static const Color white = Color(0xFFFFFFFF);

  static const Color midnightDeep = Color(0xFF020F2B);
  static const Color surface = Color(0xFF0A2559);
  static const Color surfaceAlt = Color(0xFF0E2F6B);
  static const Color border = Color(0xFF15407F);

  static const Color success = Color(0xFF3DD68C);
  static const Color warning = Color(0xFFFFC24B);
  static const Color danger = Color(0xFFFF6B6B);

  static Color forStatus(String status) {
    switch (status) {
      case 'pending':
        return warning;
      case 'accepted':
      case 'preparing':
        return skyDeep;
      case 'ready':
      case 'in_transit':
        return skyLight;
      case 'delivered':
      case 'completed':
        return success;
      case 'rejected':
      case 'cancelled':
      case 'payment_failed':
        return danger;
      default:
        return grayLight;
    }
  }

  static const Color primary = skyLight;
  static const Color primaryDark = midnight;
  static const Color accent = skyDeep;
  static const Color background = midnightDeep;
  static const Color card = surface;
  static const Color textPrimary = white;
  static const Color textSecondary = grayLight;
  static const Color divider = border;
}

const bool kDisplayFontBundled = false;

class AppText {
  AppText._();

  static TextStyle display(double size, {Color? color, double? letterSpacing}) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.white,
      letterSpacing: letterSpacing ?? 0.5,
      height: 1.1,
    );
    return kDisplayFontBundled
        ? base.copyWith(fontFamily: 'OldSport')
        : GoogleFonts.montserrat(textStyle: base, fontWeight: FontWeight.w800);
  }

  static TextStyle body(double size, {Color? color, FontWeight? weight, double? height}) =>
      GoogleFonts.montserrat(
        textStyle: TextStyle(
          fontSize: size,
          color: color ?? AppColors.white,
          fontWeight: weight ?? FontWeight.w500,
          height: height ?? 1.35,
        ),
      );

  static TextStyle figure(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.montserrat(
        textStyle: TextStyle(
          fontSize: size,
          color: color ?? AppColors.skyLight,
          fontWeight: weight ?? FontWeight.w700,
        ),
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class AppTheme {
  AppTheme._();

  static const double radius = 14;
  static const double gap = 16;

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: AppColors.skyLight,
      onPrimary: AppColors.midnight,
      secondary: AppColors.skyDeep,
      onSecondary: AppColors.midnight,
      surface: AppColors.surface,
      onSurface: AppColors.white,
      error: AppColors.danger,
      onError: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.midnightDeep,
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme)
          .apply(bodyColor: AppColors.white, displayColor: AppColors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.midnight,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        titleTextStyle: AppText.display(18),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.skyLight,
          foregroundColor: AppColors.midnight,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.grayLight,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppText.body(16, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.skyLight,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.skyLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppText.body(15, color: AppColors.grayLight),
        labelStyle: AppText.body(15, color: AppColors.grayLight),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.skyDeep, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.skyDeep),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.border.withValues(alpha: 0.9)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(8),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: AppText.body(12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: AppText.body(14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.skyLight),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        labelStyle: AppText.body(13),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

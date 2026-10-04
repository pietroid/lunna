import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Focus theme.
///
/// The app is dark-only by design, so [dark] is the single entry point. Every
/// component theme below pulls from [AppColors], [AppSpacing], and
/// [AppTypography], so a screen never has to restate a token.
abstract final class AppTheme {
  /// The dark theme, and the only theme the app ships.
  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.onAccent,
          secondary: AppColors.fill,
          onSecondary: AppColors.ink,
          surface: AppColors.bg,
          onSurface: AppColors.ink,
          surfaceContainer: AppColors.surface,
          surfaceContainerHighest: AppColors.fill,
          onSurfaceVariant: AppColors.ink2,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          error: AppColors.negative,
          onError: AppColors.onAccent,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: AppTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
        toolbarHeight: AppSpacing.s16,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.ink2,
        size: AppSpacing.iconSize,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.fill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.cardRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.label,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.cardRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.fill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTypography.labelStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      // The app's button: accent fill, 44pt tall, rounded but not a pill, so it
      // reads as a sibling of the prompt field rather than a floating chip.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, AppSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          textStyle: AppTypography.bodyStrong,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSpacing.buttonRadius),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, AppSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          textStyle: AppTypography.bodyStrong,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSpacing.buttonRadius),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink2,
          minimumSize: const Size.square(AppSpacing.tapTarget),
          shape: const CircleBorder(),
        ),
      ),
      // The field: a borderless pill on the fill, with no outline in any state.
      // Focus is already carried by the caret; an accent border on top of that
      // reads as a validation state the field is not in.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s3,
        ),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.negative),
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(),
        disabledBorder: _fieldBorder(),
        errorBorder: _fieldBorder(color: AppColors.negative),
        focusedErrorBorder: _fieldBorder(color: AppColors.negative, width: 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fill,
        labelStyle: AppTypography.labelStrong,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.fill,
        contentTextStyle: AppTypography.labelStrong,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.fillStrong,
        circularTrackColor: AppColors.fillStrong,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.accentSoft,
        selectionHandleColor: AppColors.accent,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder({
    Color color = Colors.transparent,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

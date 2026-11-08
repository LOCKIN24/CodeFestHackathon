import 'package:flutter/material.dart';
import 'package:town_pass/gen/fonts.gen.dart';
import 'package:town_pass/util/tp_colors.dart';

/// Campaign surfaces deliberately retain the TownPass light design kit even
/// when the device requests dark appearance. Every selection state is explicit.
class MilkFeatureTheme extends StatelessWidget {
  const MilkFeatureTheme({super.key, required this.child});
  final Widget child;
  static ThemeData data(ThemeData base) {
    const teal = TPColors.primary700;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: teal,
          brightness: Brightness.light,
        ).copyWith(
          primary: teal,
          onPrimary: TPColors.white,
          surface: TPColors.white,
          onSurface: TPColors.grayscale900,
          surfaceContainerHighest: TPColors.primary50,
          outline: TPColors.grayscale600,
          secondary: teal,
          onSecondary: TPColors.white,
        );
    final selectedColor = WidgetStateProperty.resolveWith<Color>(
      (states) =>
          states.contains(WidgetState.selected) ? teal : TPColors.grayscale600,
    );
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: TPColors.grayscale50,
      iconTheme: const IconThemeData(color: TPColors.grayscale700),
      primaryIconTheme: const IconThemeData(color: TPColors.primary700),
      dividerColor: TPColors.grayscale200,
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: FontFamily.pingFangTC,
        bodyColor: TPColors.grayscale900,
        displayColor: TPColors.grayscale900,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: TPColors.white,
        foregroundColor: TPColors.grayscale800,
        surfaceTintColor: Colors.transparent,
        actionsIconTheme: const IconThemeData(
          color: TPColors.grayscale700,
          size: 24,
        ),
        iconTheme: const IconThemeData(color: TPColors.grayscale700, size: 24),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: TPColors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: TPColors.grayscale900,
          fontFamily: FontFamily.pingFangTC,
          fontSize: 21,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: TPColors.grayscale800,
          fontFamily: FontFamily.pingFangTC,
          fontSize: 16,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TPColors.white,
        modalBackgroundColor: TPColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: TPColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      radioTheme: RadioThemeData(
        fillColor: selectedColor,
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? teal : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(TPColors.white),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: TPColors.white,
        selectedColor: TPColors.primary100,
        disabledColor: TPColors.grayscale100,
        checkmarkColor: teal,
        labelStyle: const TextStyle(
          color: TPColors.grayscale900,
          fontFamily: FontFamily.pingFangTC,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: TPColors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: TPColors.primary50,
        headerForegroundColor: TPColors.primary900,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: TPColors.white,
        dialBackgroundColor: TPColors.primary50,
        dialHandColor: teal,
        dialTextColor: TPColors.grayscale900,
        hourMinuteColor: TPColors.primary100,
        hourMinuteTextColor: TPColors.primary900,
        dayPeriodColor: TPColors.primary50,
        dayPeriodTextColor: TPColors.primary900,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: TPColors.white,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontFamily: FontFamily.pingFangTC,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: teal,
          backgroundColor: TPColors.white,
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: data(Theme.of(context)), child: child);
}

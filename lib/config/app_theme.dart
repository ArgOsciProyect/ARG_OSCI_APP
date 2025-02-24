import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
    colorScheme: const ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.amber,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      titleTextStyle: TextStyle(color: Colors.black),
      iconTheme: IconThemeData(color: Colors.black),
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
      bodySmall: TextStyle(color: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.grey[300],
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.amber,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      titleTextStyle: TextStyle(color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.grey[800],
      ),
    ),
  );

  static Paint getDataPaint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Paint()
      ..color = isDark ? Colors.yellow : Colors.blue
      ..strokeWidth = 2;
  }

    static Color getAppBarTextColor(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return isDark ? Colors.white : Colors.black;
    }


  static Paint getZeroPaint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Paint()
      ..color = isDark ? Colors.greenAccent : Colors.red
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
  }

  static Paint getBorderPaint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
  }

  static Paint getChartBackgroundPaint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Paint()
      ..color = isDark ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;
  }

    static Color getChartAreaColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }

  static Color getIconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }

  static Color getControlPanelColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }
  static Paint getFFTDataPaint(BuildContext context) {
    return getDataPaint(context);
  }

  static Paint getFFTGridPaint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Paint()
      ..color = isDark ? Colors.grey.shade700 : Colors.grey
      ..strokeWidth = 0.5;
  }

  static Paint getFFTBorderPaint(BuildContext context) {
    return getBorderPaint(context);
  }

  static Color getLoadingIndicatorColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.blue;
  }

  static Color getFFTBackgroundColor(BuildContext context) {
    return getChartBackgroundPaint(context).color;
  }
}
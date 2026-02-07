import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  primaryColor: const Color.fromRGBO(88, 86, 214, 1), // Updated to indigo
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color.fromRGBO(88, 86, 214, 1), // Updated to indigo
    elevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'Product Sans',
      fontWeight: FontWeight.w400,
      fontSize: 24,
      color: Colors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF000000), // Button color (black)
      textStyle: const TextStyle(
        fontFamily: 'Product Sans',
        fontWeight: FontWeight.w400,
      ),
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontFamily: 'Product Sans',
      fontWeight: FontWeight.w400,
      fontSize: 24,
      color: Colors.black,
      height: 1.4, // 16.8/12 = 1.4
      letterSpacing: -0.24,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Product Sans',
      fontWeight: FontWeight.w400,
      fontSize: 14,
      color: Colors.black,
      height: 1.4, // 16.8/12 = 1.4
      letterSpacing: -0.24,
    ),
    // Medium description style: 14px size, 19.6px line height (1.4x), letter spacing -2% of 14 (≈ -0.28)
    bodyLarge: TextStyle(
      fontFamily: 'Product Sans',
      fontWeight: FontWeight.w800,
      fontSize: 14,
      // height: 1.4, // 19.6/14 = 1.4
      letterSpacing: -0.28,
      color: Colors.black,
    ),
    // Small description style: 10px size, 14px line height (1.4x), letter spacing -2% of 10 (≈ -0.20)
    bodyMedium: TextStyle(
      fontFamily: 'Product Sans',
      fontWeight: FontWeight.w400,
      fontSize: 12,
      // height: 1.4, // 14/10 = 1.4
      letterSpacing: -0.20,
    ),
  ),
  visualDensity: VisualDensity.adaptivePlatformDensity,
);
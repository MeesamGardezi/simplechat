import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF075E54);
  static const primaryLight = Color(0xFF128C7E);
  static const accent = Color(0xFF25D366);
  static const sentBubble = Color(0xFFDCF8C6);
  static const receivedBubble = Colors.white;
  static const chatBackground = Color(0xFFECE5DD);
  static const appBarBg = Color(0xFF075E54);
  static const inputBg = Colors.white;
  static const replyBg = Color(0xFFD9FDD3);
  static const timestamp = Color(0xFF667781);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBarBg,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        scaffoldBackgroundColor: AppColors.chatBackground,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 15),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.timestamp),
        ),
      );
}

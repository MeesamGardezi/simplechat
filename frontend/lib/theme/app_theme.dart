import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class C {
  static const teal = Color(0xFF075E54);
  static const tealLight = Color(0xFF128C7E);
  static const green = Color(0xFF25D366);
  static const sentBubble = Color(0xFFE7FFDB);
  static const recvBubble = Colors.white;
  static const chatBg = Color(0xFFEFE7DE);
  static const timestamp = Color(0xFF8696A0);
  static const divider = Color(0xFFE9EDEF);
  static const inputBg = Color(0xFFF0F2F5);
  static const replyStripe = Color(0xFF00A884);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: false,
        primaryColor: C.teal,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: C.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF054C44),
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.teal,
          primary: C.teal,
          secondary: C.green,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: C.green,
          foregroundColor: Colors.white,
        ),
      );
}

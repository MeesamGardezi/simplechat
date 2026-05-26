import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// WhatsApp-accurate colours
class C {
  static const appBar        = Color(0xFF128C7E);
  static const appBarStatus  = Color(0xFF075E54);
  static const teal          = Color(0xFF075E54);
  static const green         = Color(0xFF25D366);
  static const sentBubble    = Color(0xFFE7FFDB);
  static const recvBubble    = Colors.white;
  static const chatBg        = Color(0xFFE5DDD5);
  static const timestamp     = Color(0xFF8696A0);
  static const divider       = Color(0xFFE9EDEF);
  static const inputBar      = Color(0xFFF0F2F5);
  static const replyAccent   = Color(0xFF00A884);
  static const unreadBadge   = Color(0xFF25D366);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: false,
        primaryColor: C.teal,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: C.appBar,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: C.appBarStatus,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
          elevation: 4,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 15, color: Color(0xFF111B21)),
        ),
      );
}

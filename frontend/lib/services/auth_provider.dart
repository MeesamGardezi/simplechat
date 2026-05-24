import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final SocketService socket;

  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider({required this.api, required this.socket});

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userRaw = prefs.getString('user');
    if (token != null && userRaw != null) {
      api.setToken(token);
      _user = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
      socket.connect(token);
      notifyListeners();
    }
  }

  Future<bool> join(String name) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await api.join(name.trim());
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      api.setToken(token);
      _user = user;
      socket.connect(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user.toJson()));
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    socket.disconnect();
    api.clearToken();
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}

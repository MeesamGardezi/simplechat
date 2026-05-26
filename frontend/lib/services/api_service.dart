import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/room.dart';
import '../models/message.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({required this.baseUrl});

  void setToken(String t) => _token = t;
  void clearToken() => _token = null;

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<T> _parse<T>(http.Response r, T Function(dynamic) fn) async {
    final body = jsonDecode(r.body);
    if (r.statusCode >= 400) throw ApiException(body['error'] as String? ?? 'Error ${r.statusCode}');
    return fn(body);
  }

  Future<Map<String, dynamic>> join(String name) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/auth/join'),
      headers: _h,
      body: jsonEncode({'name': name}),
    );
    return _parse(r, (b) => b as Map<String, dynamic>);
  }

  Future<List<Room>> getRooms() async {
    final r = await http.get(Uri.parse('$baseUrl/api/rooms'), headers: _h);
    return _parse(r, (b) => (b as List).map((x) => Room.fromJson(x as Map<String, dynamic>)).toList());
  }

  Future<List<Message>> getMessages(String roomId, {String? before}) async {
    final uri = Uri.parse('$baseUrl/api/messages/$roomId').replace(
      queryParameters: {'limit': '50', if (before != null) 'before': before},
    );
    final r = await http.get(uri, headers: _h);
    return _parse(r, (b) => (b as List).map((x) => Message.fromJson(x as Map<String, dynamic>)).toList());
  }

  Future<List<User>> getAllUsers() async {
    final r = await http.get(Uri.parse('$baseUrl/api/rooms/users/all'), headers: _h);
    return _parse(r, (b) => (b as List).map((x) => User.fromJson(x as Map<String, dynamic>)).toList());
  }

  Future<Map<String, dynamic>> createDm(String targetUserId) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/rooms/dm'),
      headers: _h,
      body: jsonEncode({'target_user_id': targetUserId}),
    );
    return _parse(r, (b) => b as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/rooms'),
      headers: _h,
      body: jsonEncode({'name': name, 'member_ids': memberIds}),
    );
    return _parse(r, (b) => b as Map<String, dynamic>);
  }
}

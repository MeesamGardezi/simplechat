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

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) parser,
  ) async {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? 'Request failed');
    }
    return parser(body);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    return _handleResponse(res, (b) => b as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(res, (b) => b as Map<String, dynamic>);
  }

  Future<List<Room>> getRooms() async {
    final res = await http.get(Uri.parse('$baseUrl/api/rooms'), headers: _headers);
    return _handleResponse(
      res,
      (b) => (b as List).map((r) => Room.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Message>> getMessages(String roomId, {String? before}) async {
    final uri = Uri.parse('$baseUrl/api/messages/$roomId').replace(
      queryParameters: {
        'limit': '50',
        if (before != null) 'before': before,
      },
    );
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(
      res,
      (b) => (b as List).map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<User>> getAllUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/api/rooms/users/all'), headers: _headers);
    return _handleResponse(
      res,
      (b) => (b as List).map((u) => User.fromJson(u as Map<String, dynamic>)).toList(),
    );
  }

  Future<Room> createDm(String targetUserId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/rooms/dm'),
      headers: _headers,
      body: jsonEncode({'target_user_id': targetUserId}),
    );
    return _handleResponse(res, (b) => Room.fromJson(b as Map<String, dynamic>));
  }

  Future<Room> createGroup({required String name, required List<String> memberIds}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/rooms'),
      headers: _headers,
      body: jsonEncode({'name': name, 'member_ids': memberIds}),
    );
    return _handleResponse(res, (b) => Room.fromJson(b as Map<String, dynamic>));
  }
}

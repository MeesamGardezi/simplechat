import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/auth_provider.dart';
import 'services/chat_provider.dart';
import 'screens/login_screen.dart';
import 'screens/rooms_screen.dart';
import 'theme/app_theme.dart';

const String kBaseUrl = 'http://localhost:3000';

void main() {
  runApp(const SimpleChatApp());
}

class SimpleChatApp extends StatelessWidget {
  const SimpleChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService(baseUrl: kBaseUrl);
    final socket = SocketService(serverUrl: kBaseUrl);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api: api, socket: socket)),
        ChangeNotifierProvider(create: (_) => ChatProvider(api: api, socket: socket)),
      ],
      child: MaterialApp(
        title: 'SimpleChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<AuthProvider>().tryAutoLogin();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_rounded, size: 64, color: Color(0xFF075E54)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF075E54)),
            ],
          ),
        ),
      );
    }

    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    return isAuth ? const RoomsScreen() : const LoginScreen();
  }
}

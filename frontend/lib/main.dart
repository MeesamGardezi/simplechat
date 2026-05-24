import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/auth_provider.dart';
import 'services/chat_provider.dart';
import 'screens/name_screen.dart';
import 'screens/rooms_screen.dart';
import 'theme/app_theme.dart';

// ── Change this to your machine's IP when running on a physical device ──
const String kServerUrl = 'http://localhost:3000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF054C44),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SimpleChatApp());
}

class SimpleChatApp extends StatelessWidget {
  const SimpleChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService(baseUrl: kServerUrl);
    final socket = SocketService(serverUrl: kServerUrl);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api: api, socket: socket)),
        ChangeNotifierProvider(create: (_) => ChatProvider(api: api, socket: socket)),
      ],
      child: MaterialApp(
        title: 'SimpleChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().tryAutoLogin().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: C.teal,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_rounded, size: 72, color: Colors.white),
              SizedBox(height: 20),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return context.watch<AuthProvider>().isAuthenticated
        ? const RoomsScreen()
        : const NameScreen();
  }
}

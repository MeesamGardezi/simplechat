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

// ── Change to your machine's local IP when running on a physical device ──
// Example: const kServer = 'http://192.168.1.42:3000';
const kServer = 'http://localhost:3000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SimpleChatApp());
}

class SimpleChatApp extends StatelessWidget {
  const SimpleChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService(baseUrl: kServer);
    final socket = SocketService(serverUrl: kServer);

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
        backgroundColor: C.appBar,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_rounded, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'SimpleChat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated ? const RoomsScreen() : const NameScreen();
  }
}

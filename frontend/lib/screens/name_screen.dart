import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Enter your name');
      return;
    }
    setState(() => _err = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.join(name);
    if (!ok && mounted) setState(() => _err = auth.error);
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Green header band
            Container(
              width: double.infinity,
              color: C.teal,
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SimpleChat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fast, simple messaging',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      'What\'s your name?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a unique name. This is how others will see you.',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 17, color: Colors.black87),
                      onSubmitted: (_) => _join(),
                      onChanged: (_) => setState(() => _err = null),
                      decoration: InputDecoration(
                        hintText: 'e.g. Alex or Alex_123',
                        hintStyle: const TextStyle(color: Colors.black26),
                        filled: false,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: C.teal, width: 1.5),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: C.teal, width: 2),
                        ),
                        errorText: _err,
                        errorStyle: const TextStyle(color: Color(0xFFE53935)),
                        contentPadding: const EdgeInsets.only(bottom: 8),
                        suffixIcon: _ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.black38),
                                onPressed: () {
                                  _ctrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_ctrl.text.trim().length}/24 characters',
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                    const Spacer(),
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading ? null : _join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Start Chatting',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _ctrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Must be at least 2 characters');
      return;
    }
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.join(name);
    if (!ok && mounted) {
      setState(() => _error = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final charCount = _ctrl.text.trim().length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Green header ──────────────────────────────────────
          Container(
            color: C.appBar,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 40,
              24,
              36,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SimpleChat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Fast · Simple · No signup',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What\'s your name?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111B21),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose a unique display name. Others will see this.',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF8696A0),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Name field
                  TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: true,
                    maxLength: 24,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_ ]')),
                    ],
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF111B21),
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _join(),
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex or Cool_Cat',
                      hintStyle: const TextStyle(
                        color: Color(0xFFB0BAC3),
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                      ),
                      counterText: '',
                      filled: false,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDDE1E7), width: 1.5),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: C.teal, width: 2),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      errorText: _error,
                      errorStyle: const TextStyle(color: Colors.red, fontSize: 13),
                      contentPadding: const EdgeInsets.only(bottom: 10),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Character counter + hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Letters, numbers, spaces, underscores',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        '$charCount/24',
                        style: TextStyle(
                          fontSize: 12,
                          color: charCount > 20
                              ? Colors.orange
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 56),

                  // Continue button
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: loading ? null : _join,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

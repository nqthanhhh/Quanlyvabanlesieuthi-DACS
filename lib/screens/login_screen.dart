import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'password_login_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String role) onLogin;
  final bool closeOnLogin;

  const LoginScreen({
    super.key,
    required this.onLogin,
    this.closeOnLogin = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: Center(
                          child: Image.asset(
                            'assets/images/anh1.png',
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: 300,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 20,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Text('Hình ảnh không tải được'),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 0),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PasswordLoginScreen(
                              onLogin: (role) {
                                widget.onLogin(role);
                                if (widget.closeOnLogin) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            0,
                            73,
                            125,
                          ),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: Size.fromHeight(40),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text('Đăng nhập bằng tài khoản'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Bạn chưa có tài khoản? '),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            child: const Text('Đăng kí'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_screen.dart';
import 'password_login_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String role) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();

  // PIN flow removed in favor of password login screen. Keep controller if needed later.

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // Social buttons are inlined where used so each can use its SVG asset.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/images/material-icon-theme_google.svg',
                            width: 24,
                            height: 24,
                          ),
                          label: const Text(
                            'Đăng nhập bằng Google',
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/images/Vector.svg',
                            width: 24,
                            height: 24,
                          ),
                          label: const Text(
                            'Đăng nhập bằng Facebook',
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: Size.fromHeight(56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/images/ic_baseline-apple.svg',
                            width: 24,
                            height: 24,
                          ),
                          label: const Text(
                            'Đăng nhập bằng Apple',
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: Size.fromHeight(56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Hoặc'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 45),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PasswordLoginScreen(onLogin: widget.onLogin),
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

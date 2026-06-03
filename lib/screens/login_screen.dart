import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  void _showDemoSocialLogin(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đăng nhập $provider đang để demo giao diện')),
    );
  }

  Widget _socialIconButton({
    required String provider,
    required String assetName,
  }) {
    return Tooltip(
      message: provider,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: () => _showDemoSocialLogin(provider),
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SvgPicture.asset(assetName),
        ),
      ),
    );
  }

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
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('Hoặc đăng nhập bằng'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialIconButton(
                            provider: 'Google',
                            assetName:
                                'assets/images/material-icon-theme_google.svg',
                          ),
                          const SizedBox(width: 18),
                          _socialIconButton(
                            provider: 'Facebook',
                            assetName: 'assets/images/Vector.svg',
                          ),
                          const SizedBox(width: 18),
                          _socialIconButton(
                            provider: 'Apple',
                            assetName: 'assets/images/ic_baseline-apple.svg',
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
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

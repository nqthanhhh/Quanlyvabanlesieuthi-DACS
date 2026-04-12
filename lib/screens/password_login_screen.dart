import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_screen.dart';
import '../services/db_service.dart';

class PasswordLoginScreen extends StatefulWidget {
  final void Function(String role) onLogin;
  const PasswordLoginScreen({super.key, required this.onLogin});

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _remember = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    final settings = DBService.settings();
    final savedEmail = settings.get('remember_email');
    final savedPass = settings.get('remember_pass');
    if (savedEmail != null && savedPass != null) {
      _emailCtrl.text = savedEmail as String;
      _passCtrl.text = savedPass as String;
      _remember = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email và mật khẩu')),
      );
      return;
    }
    // Check users box for matching credentials
    final box = DBService.users();
    final matches = box.values.where(
      (u) => u.email == email && u.password == pass,
    );
    if (matches.isNotEmpty) {
      final user = matches.first;
      // persist credentials when remember is checked
      final settings = DBService.settings();
      if (_remember) {
        settings.put('remember_email', email);
        settings.put('remember_pass', pass);
      } else {
        if (settings.containsKey('remember_email')) {
          settings.delete('remember_email');
        }
        if (settings.containsKey('remember_pass')) {
          settings.delete('remember_pass');
        }
      }
      // set current user email so other screens can load per-user data (e.g., cart)
      final settings2 = DBService.settings();
      settings2.put('current_user_email', user.email);
      widget.onLogin(user.role);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email hoặc mật khẩu không đúng')),
      );
    }
  }

  Widget _socialButton(String assetName) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
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
        leading: BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Đăng nhập',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email),
                  hintText: 'Email',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  hintText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                  const Text('Nhớ tài khoản'),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 73, 125),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
                child: const Text('Đăng nhập'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () {}, child: const Text('Quên mật khẩu')),
              const SizedBox(height: 40),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Hoặc tiếp tục với'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _socialButton('assets/images/material-icon-theme_google.svg'),
                  _socialButton('assets/images/Vector.svg'),
                  _socialButton('assets/images/ic_baseline-apple.svg'),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bạn chưa có tài khoản? '),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Đăng kí'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

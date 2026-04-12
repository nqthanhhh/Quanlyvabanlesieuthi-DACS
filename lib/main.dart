import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/db_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DBService.init();
  runApp(const MyApp());
}


class AuthState extends ChangeNotifier {
  String? _role;
  String? get role => _role;

  bool get isLoggedIn => _role != null;

  void login(String role) {
    _role = role;
    notifyListeners();
  }


  void logout() {
    _role = null;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: MaterialApp(
        title: 'Siêu thị mini',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _initialized = false;
  bool _welcomeSeen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // read flag from Hive settings box
    final box = DBService.settings();
    final seen = box.get('welcomeSeen', defaultValue: false) as bool;
    setState(() {
      _welcomeSeen = seen;
      _initialized = true;
    });
  }

  void _onStartPressed() async {
    final box = DBService.settings();
    await box.put('welcomeSeen', true);
    setState(() {
      _welcomeSeen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_welcomeSeen) {
      return WelcomeScreen(onStart: _onStartPressed);
    }

    final auth = Provider.of<AuthState>(context);
    if (!auth.isLoggedIn) {
      return LoginScreen(onLogin: (role) => auth.login(role));
    }
    return HomeScreen(role: auth.role!, onLogout: () => auth.logout());
  }
}

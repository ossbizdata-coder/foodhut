import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../services/pin_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';
import 'setup_pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  bool loading = false;

  void login() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      return _msg("Enter all fields");
    }

    setState(() => loading = true);

    final result = await AuthService.login(
      emailCtrl.text.trim(),
      passCtrl.text.trim(),
    );

    setState(() => loading = false);

    if (result) {
      // Clear any existing PIN on fresh login
      await PinService.clearPin();

      if (!mounted) return;
      // Navigate to PIN setup screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupPinScreen()),
      );
    } else {
      _msg("Incorrect email or password");
    }
  }

  void _msg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              /// 🔥 Logo
              const AppLogo(height: 200),
              const SizedBox(height: 40),

              /// 🔥 Login Card (premium UI untouched)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Login",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),

                    const SizedBox(height: 30),

                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        hintText: "Email",
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        hintText: "Password",
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 22),

                    loading
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(
                      text: "Login",
                      onPressed: login,
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import 'menu_screen.dart';
import 'login.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String pin = '';
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _checkTokenValidity();
  }

  Future<void> _checkTokenValidity() async {
    final isValid = await PinService.isTokenValid();
    if (!isValid) {
      if (!mounted) return;
      // Token expired, clear PIN and go back to login
      await PinService.clearPin();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _onNumberPressed(String number) {
    if (pin.length < 4) {
      setState(() {
        pin += number;
        isError = false;
      });

      if (pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
        isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await PinService.verifyPin(pin);

    if (isValid) {
      // Check token validity one more time before navigating
      final tokenValid = await PinService.isTokenValid();
      if (!tokenValid) {
        if (!mounted) return;
        await PinService.clearPin();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
    } else {
      setState(() {
        isError = true;
        pin = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _forgotPin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text('You need to login again to reset your PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await PinService.clearPin();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF21C36F);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: green,
        title: const Text('Enter PIN'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                isError ? Icons.lock_open : Icons.lock_outline,
                size: 60,
                color: isError ? Colors.red : green,
              ),
              const SizedBox(height: 16),
              Text(
                isError ? 'Incorrect PIN' : 'Enter your PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isError ? Colors.red : Colors.black,
                ),
              ),
              const SizedBox(height: 24),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < pin.length
                            ? (isError ? Colors.red : green)
                            : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // Number pad
                _buildNumberPad(),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _forgotPin,
                  child: const Text('Forgot PIN?'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildNumberRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildNumberRow(['', '0', 'delete']),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const SizedBox(width: 70, height: 70);
        }

        if (number == 'delete') {
          return InkWell(
            onTap: _onDeletePressed,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: const Icon(Icons.backspace_outlined, size: 24),
            ),
          );
        }

        return InkWell(
          onTap: () => _onNumberPressed(number),
          borderRadius: BorderRadius.circular(35),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


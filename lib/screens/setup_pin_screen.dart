import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import 'menu_screen.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  String pin = '';
  String confirmPin = '';
  bool isConfirming = false;

  void _onNumberPressed(String number) {
    setState(() {
      if (isConfirming) {
        if (confirmPin.length < 4) {
          confirmPin += number;
          if (confirmPin.length == 4) {
            _verifyAndSavePin();
          }
        }
      } else {
        if (pin.length < 4) {
          pin += number;
          if (pin.length == 4) {
            isConfirming = true;
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (isConfirming) {
        if (confirmPin.isNotEmpty) {
          confirmPin = confirmPin.substring(0, confirmPin.length - 1);
        }
      } else {
        if (pin.isNotEmpty) {
          pin = pin.substring(0, pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSavePin() async {
    if (pin == confirmPin) {
      await PinService.setPin(pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        pin = '';
        confirmPin = '';
        isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF21C36F);
    final currentPin = isConfirming ? confirmPin : pin;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: green,
        title: const Text('Setup PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.lock_outline, size: 80, color: green),
              const SizedBox(height: 24),
              Text(
                isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < currentPin.length ? green : Colors.grey.shade300,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

              // Number pad
              _buildNumberPad(),
              const SizedBox(height: 20),
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
        const SizedBox(height: 16),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 16),
        _buildNumberRow(['', '0', 'delete']),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const SizedBox(width: 80, height: 80);
        }

        if (number == 'delete') {
          return InkWell(
            onTap: _onDeletePressed,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: const Icon(Icons.backspace_outlined),
            ),
          );
        }

        return InkWell(
          onTap: () => _onNumberPressed(number),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


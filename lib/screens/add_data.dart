import 'package:flutter/material.dart';

import '../services/api_services.dart';

const appBarGreen = Color(0xFF1DBF73);

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final _expenseTypeController = TextEditingController();
  bool _loading = false;

  void _addExpenseType() async {
    if (_expenseTypeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter expense type name')),
      );
      return;
    }

    setState(() => _loading = true);
    final success = await ApiService.addExpenseType(
      _expenseTypeController.text.trim(),
      'FOODHUT',
    );
    setState(() => _loading = false);

    if (success) {
      _expenseTypeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense Type added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add expense type'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense Type'),
        backgroundColor: appBarGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: appBarGreen,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Expense Type',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add new expense category for Food Hut',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _expenseTypeController,
                      decoration: InputDecoration(
                        labelText: 'Expense Type Name',
                        hintText: 'e.g., Groceries, Utilities, Staff Meal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appBarGreen, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _addExpenseType,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appBarGreen,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add Expense Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _expenseTypeController.dispose();
    super.dispose();
  }
}

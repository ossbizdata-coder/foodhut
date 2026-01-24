import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_services.dart';
import '../models/expense_model.dart';

const appBarGreen = Color(0xFF1DBF73);

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();

  bool _loading = false;
  bool _loadingTypes = true;

  List<ExpenseType> _expenseTypes = [];
  ExpenseType? _selectedExpenseType;

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
  }

  Future<void> _loadExpenseTypes() async {
    setState(() => _loadingTypes = true);
    final types = await ApiService.getExpenseTypes(shopType: 'FOODHUT');
    setState(() {
      _expenseTypes = types;
      _loadingTypes = false;
      if (types.isNotEmpty) {
        _selectedExpenseType = types.first;
      }
    });
  }

  Future<void> _addExpense() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    if (_selectedExpenseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expense type')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid amount')),
      );
      return;
    }

    setState(() => _loading = true);

    final success = await ApiService.addExpense(
      amount: amount,
      expenseTypeId: _selectedExpenseType!.id,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    setState(() => _loading = false);

    if (success) {
      _amountController.clear();
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add expense'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: appBarGreen,
        foregroundColor: Colors.white,
      ),
      body: _loadingTypes
          ? const Center(child: CircularProgressIndicator())
          : _expenseTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expense types available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please add expense types first',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: appBarGreen,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Record Expense',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track your daily expenses',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expense Type Dropdown
                          DropdownButtonFormField<ExpenseType>(
                            value: _selectedExpenseType,
                            decoration: InputDecoration(
                              labelText: 'Expense Type',
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
                            items: _expenseTypes.map((type) {
                              return DropdownMenuItem<ExpenseType>(
                                value: type,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedExpenseType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount Field
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Amount (Rs.)',
                              hintText: 'Enter amount',
                              prefixText: 'Rs. ',
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
                          const SizedBox(height: 16),

                          // Comment Field
                          TextField(
                            controller: _commentController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Comment (Optional)',
                              hintText: 'Add notes about this expense',
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

                          // Submit Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _addExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appBarGreen,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Add Expense',
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
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import '../models/expense_model.dart';

const appBarGreen = Color(0xFF1DBF73);
const expenseRed = Color(0xFFE53935);
const expensePink = Color(0xFFFF5252);

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  List<Expense> expenses = [];
  Map<int, String> expenseTypeNames = {};
  double totalExpenses = 0.0;
  double totalUpToDate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
  }

  Future<void> _loadExpenseTypes() async {
    final types = await ApiService.getExpenseTypes(shopType: 'FOODHUT');
    setState(() {
      expenseTypeNames = {for (var type in types) type.id: type.name};
    });
    print('Loaded expense types: $expenseTypeNames'); // Debug
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => loading = true);

    final date = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Load both daily expenses and total up to date
    final results = await Future.wait([
      ApiService.getExpensesForDay(date),
      ApiService.getTotalExpensesUpToDate(date),
    ]);

    final expenseList = results[0] as List<Expense>;
    final upToDateTotal = results[1] as double;

    double total = 0.0;
    for (var expense in expenseList) {
      total += expense.amount;
      print('Expense: typeId=${expense.expenseTypeId}, typeName=${expense.expenseTypeName}, itemName=${expense.itemName}'); // Debug
    }

    setState(() {
      expenses = expenseList;
      totalExpenses = total;
      totalUpToDate = upToDateTotal;
      loading = false;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: expenseRed,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadExpenses();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Report'),
        backgroundColor: appBarGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector with arrows
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: expensePink.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: expenseRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      selectedDate = selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadExpenses();
                  },
                  color: expenseRed,
                  tooltip: 'Previous day',
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month, color: expenseRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                      ? () {
                          setState(() {
                            selectedDate = selectedDate.add(const Duration(days: 1));
                          });
                          _loadExpenses();
                        }
                      : null,
                  color: expenseRed,
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),

          // Total expenses up to date card - RED/PINK (lighter shades)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFEF5350), const Color(0xFFFF7675)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE57373),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF5350).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Total Up to ${DateFormat('MMM d').format(selectedDate)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${totalUpToDate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),

          // Daily Total card - ORANGE (lighter shades)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isToday(selectedDate)
                            ? "Today's Total"
                            : "${DateFormat('MMM d').format(selectedDate)} Total",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Expenses list - compact version
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses recorded',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'for ${DateFormat('MMM d, yyyy').format(selectedDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          // Priority: 1) expenseTypeNames map, 2) expenseTypeName field, 3) itemName, 4) "Expense"
                          String expenseName = 'Expense';

                          if (expense.expenseTypeId != null && expenseTypeNames.containsKey(expense.expenseTypeId)) {
                            expenseName = expenseTypeNames[expense.expenseTypeId]!;
                            print('Using type map: $expenseName for typeId ${expense.expenseTypeId}'); // Debug
                          } else if (expense.expenseTypeName != null && expense.expenseTypeName!.isNotEmpty) {
                            expenseName = expense.expenseTypeName!;
                            print('Using expenseTypeName: $expenseName'); // Debug
                          } else if (expense.itemName != null && expense.itemName!.isNotEmpty) {
                            expenseName = expense.itemName!;
                            print('Using itemName: $expenseName'); // Debug
                          } else {
                            print('No name found, using default: $expenseName'); // Debug
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.receipt,
                                  color: Colors.red[700],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                expenseName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: Text(
                                'Rs. ${expense.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


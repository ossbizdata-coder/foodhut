import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_item_model.dart';
import '../models/today_summary_model.dart';
import '../models/expense_model.dart';

class ApiService {
  static const String baseUrl = "http://74.208.132.78";

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  // ================= MENU =================

  static Future<List<MenuItemModel>> getMenuItems() async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/items'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load menu items');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => MenuItemModel.fromJson(e)).toList();
  }

  static Future<void> addMenuItem(
      String name, List<ItemVariationModel> variations) async {
    final token = await _getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/api/items'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'variations': variations.map((v) {
          return {
            'variation': v.variation,
            'price': v.price,
            'cost': v.cost,
          };
        }).toList(),
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to add menu item');
    }
  }

  // ================= SALES / PREPARED =================

  static Future<void> addSale({
    required int variationId,
    required int preparedQty,
    required int remainingQty,
    required String actionType,
  }) async {
    final token = await _getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/api/sales'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'variationId': variationId,
        'preparedQty': preparedQty,
        'remainingQty': remainingQty,
        'actionType': actionType,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to add sale');
    }
  }

  /// Update the quantity of a sale record
  static Future<bool> updateSaleQuantity({
    required int saleId,
    required int newQuantity,
    required String actionType,
  }) async {
    try {
      if (saleId <= 0) {
        print('[updateSaleQuantity] ERROR: Invalid saleId=$saleId');
        return false;
      }

      final token = await _getToken();

      final body = {
        'preparedQty': actionType == 'PREPARED' ? newQuantity : 0,
        'remainingQty': actionType == 'REMAINING' ? newQuantity : 0,
        'actionType': actionType,
      };

      print('[updateSaleQuantity] PUT /api/sales/$saleId body=$body');

      final res = await http.put(
        Uri.parse('$baseUrl/api/sales/$saleId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('[updateSaleQuantity] Response: ${res.statusCode} - ${res.body}');

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      print('[updateSaleQuantity] Exception: $e');
      return false;
    }
  }

  /// Delete a sale record
  static Future<bool> deleteSale(int saleId) async {
    try {
      final token = await _getToken();

      final res = await http.delete(
        Uri.parse('$baseUrl/api/sales/$saleId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<SalesResponseModel>> getSalesForDay(String date) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/sales/day?date=$date'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load sales: ${res.statusCode} - ${res.body}');
    }

    try {
      final List data = jsonDecode(res.body);
      return data.map((e) {
        try {
          return SalesResponseModel.fromJson(e);
        } catch (parseError) {
          rethrow;
        }
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // ================= SUMMARY =================

  static Future<TodaySummaryModel> getTodaySalesSummary(String date) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/sales/day/summary?date=$date'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load today summary');
    }

    return TodaySummaryModel.fromJson(jsonDecode(res.body));
  }

  // ================= REMAINING =================

  static Future<List<RemainingModel>> getRemainingForDay(String date) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/remaining/list?date=$date'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load remaining items');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => RemainingModel.fromJson(e)).toList();
  }

  static Future<bool> addExpenseType(String type, String shopType) async {
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse("$baseUrl/api/expenses/types"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": type,
          "shopType": shopType,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // ================= EXPENSE TYPES =================

  static Future<List<ExpenseType>> getExpenseTypes({String? shopType}) async {
    try {
      final token = await _getToken();

      String url = '$baseUrl/api/expenses/types';
      if (shopType != null && shopType.isNotEmpty) {
        url += '?shopType=$shopType';
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load expense types');
      }

      final List data = jsonDecode(res.body);
      return data.map((e) => ExpenseType.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ================= EXPENSES =================

  static Future<bool> addExpense({
    required double amount,
    required int expenseTypeId,
    String? comment,
  }) async {
    try {
      final token = await _getToken();

      final res = await http.post(
        Uri.parse('$baseUrl/api/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'category': 'EXPENSE',
          'shopType': 'FOODHUT',
          'department': 'FOODHUT',
          'expenseTypeId': expenseTypeId,
          'comment': comment,
        }),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Expense>> getExpensesForDay(String date) async {
    try {
      final token = await _getToken();

      final res = await http.get(
        Uri.parse('$baseUrl/api/transactions/daily?department=FOODHUT&category=EXPENSE&date=$date'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load expenses');
      }

      final List data = jsonDecode(res.body);
      final allExpenses = data.map((e) => Expense.fromJson(e)).toList();

      // Client-side filtering by date since backend might not filter correctly
      final targetDate = DateTime.parse(date);
      final filteredExpenses = allExpenses.where((expense) {
        try {
          if (expense.businessDate.isEmpty) return false;

          final expenseDate = DateTime.parse(expense.businessDate);
          return expenseDate.year == targetDate.year &&
                 expenseDate.month == targetDate.month &&
                 expenseDate.day == targetDate.day;
        } catch (e) {
          // If date parsing fails, also check transaction_time
          try {
            final expenseDateTime = DateTime.parse(expense.transactionTime);
            return expenseDateTime.year == targetDate.year &&
                   expenseDateTime.month == targetDate.month &&
                   expenseDateTime.day == targetDate.day;
          } catch (e2) {
            return false;
          }
        }
      }).toList();

      print('Fetched ${allExpenses.length} expenses, filtered to ${filteredExpenses.length} for date $date');

      return filteredExpenses;
    } catch (e) {
      print('Error loading expenses: $e');
      return [];
    }
  }

  static Future<double> getTotalExpensesUpToDate(String upToDate) async {
    try {
      final token = await _getToken();

      final res = await http.get(
        Uri.parse('$baseUrl/api/transactions/daily?department=FOODHUT&category=EXPENSE'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        return 0.0;
      }

      final List data = jsonDecode(res.body);
      final expenses = data.map((e) => Expense.fromJson(e)).toList();

      // Filter expenses up to the specified date
      final upToDateTime = DateTime.parse(upToDate);
      double total = 0.0;

      for (var expense in expenses) {
        try {
          DateTime expenseDate;

          // Try to parse business_date first
          if (expense.businessDate.isNotEmpty) {
            expenseDate = DateTime.parse(expense.businessDate);
          } else {
            // Fallback to transaction_time
            expenseDate = DateTime.parse(expense.transactionTime);
          }

          // Include expenses on or before the selected date
          if (expenseDate.isBefore(upToDateTime.add(const Duration(days: 1)))) {
            total += expense.amount;
          }
        } catch (e) {
          // Skip if date parsing fails
          print('Error parsing date for expense: $e');
        }
      }

      print('Total expenses up to $upToDate: Rs. $total');
      return total;
    } catch (e) {
      print('Error loading total expenses: $e');
      return 0.0;
    }
  }

  static Future<Map<String, dynamic>> getDailySummaryWithExpenses() async {
    try {
      final token = await _getToken();

      final res = await http.get(
        Uri.parse('$baseUrl/api/transactions/daily-summary?department=FOODHUT'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load daily summary');
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {};
    }
  }

}

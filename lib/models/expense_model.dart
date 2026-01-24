class ExpenseType {
  final int id;
  final String name;
  final String shopType;

  ExpenseType({
    required this.id,
    required this.name,
    required this.shopType,
  });

  factory ExpenseType.fromJson(Map<String, dynamic> json) {
    return ExpenseType(
      id: json['id'] as int,
      name: json['name'] as String,
      shopType: json['shopType'] as String? ?? json['shop_type'] as String? ?? 'FOODHUT',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shopType': shopType,
    };
  }
}

class Expense {
  final int? id;
  final double amount;
  final String category;
  final String? itemName;
  final String shopType;
  final int? expenseTypeId;
  final String? expenseTypeName;
  final int recordedBy;
  final String businessDate;
  final String transactionTime;
  final String? comment;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    this.itemName,
    required this.shopType,
    this.expenseTypeId,
    this.expenseTypeName,
    required this.recordedBy,
    required this.businessDate,
    required this.transactionTime,
    this.comment,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    // Debug: print all fields
    print('Expense JSON: $json');

    // Try multiple field name variations
    int? getExpenseTypeId() {
      if (json['expenseTypeId'] != null) return json['expenseTypeId'] as int?;
      if (json['expense_type_id'] != null) return json['expense_type_id'] as int?;
      if (json['expenseType'] != null && json['expenseType'] is Map) {
        return json['expenseType']['id'] as int?;
      }
      return null;
    }

    String? getExpenseTypeName() {
      if (json['expenseTypeName'] != null) return json['expenseTypeName'] as String?;
      if (json['expense_type_name'] != null) return json['expense_type_name'] as String?;
      if (json['expenseType'] != null && json['expenseType'] is Map) {
        return json['expenseType']['name'] as String?;
      }
      return null;
    }

    return Expense(
      id: json['id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      itemName: json['itemName'] as String? ?? json['item_name'] as String?,
      shopType: json['shopType'] as String? ?? json['shop_type'] as String? ?? 'FOODHUT',
      expenseTypeId: getExpenseTypeId(),
      expenseTypeName: getExpenseTypeName(),
      recordedBy: json['recordedBy'] as int? ?? json['recorded_by'] as int? ?? 0,
      businessDate: json['businessDate'] as String? ?? json['business_date'] as String? ?? '',
      transactionTime: json['transactionTime'] as String? ?? json['transaction_time'] as String? ?? '',
      comment: json['comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'itemName': itemName,
      'shopType': shopType,
      'expenseTypeId': expenseTypeId,
      'expenseTypeName': expenseTypeName,
      'recordedBy': recordedBy,
      'businessDate': businessDate,
      'transactionTime': transactionTime,
      'comment': comment,
    };
  }
}


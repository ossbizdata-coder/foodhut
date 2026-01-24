class MenuItemModel {
  final int id;
  final String name;
  final List<ItemVariationModel> variations;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.variations,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    final raw = json['variations'] ?? json['itemVariation'] ?? [];
    final List<ItemVariationModel> vars =
    raw is List ? raw.map((e) => ItemVariationModel.fromJson(e)).toList() : [];

    return MenuItemModel(
      id: json['id'],
      name: json['name'] ?? '',
      variations: vars,
    );
  }
}

class ItemVariationModel {
  final int id;
  final String variation;
  final int price;
  final int cost;

  ItemVariationModel({
    required this.id,
    required this.variation,
    required this.price,
    required this.cost,
  });

  factory ItemVariationModel.fromJson(Map<String, dynamic> json) {
    return ItemVariationModel(
      id: json['id'],
      variation: json['variation'] ?? '',
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price'].toString()) ?? 0,
      cost: json['cost'] is int
          ? json['cost']
          : int.tryParse(json['cost'].toString()) ?? 0,
    );
  }
}

enum SaleActionType {
  PREPARED,
  REMAINING,
  SOLD,
}

class SalesResponseModel {
  final int saleId;
  final String itemName;
  final String variation;
  final int price;
  final int cost;
  final int quantity;
  final SaleActionType actionType;
  final DateTime transactionTime;
  final String recordedBy;

  SalesResponseModel({
    required this.saleId,
    required this.itemName,
    required this.variation,
    required this.price,
    required this.cost,
    required this.quantity,
    required this.actionType,
    required this.transactionTime,
    required this.recordedBy,
  });

  factory SalesResponseModel.fromJson(Map<String, dynamic> json) {
    // Backend sends: preparedQty, remainingQty, soldQty
    SaleActionType actionType;
    if (json['actionType'] == 'PREPARED') {
      actionType = SaleActionType.PREPARED;
    } else if (json['actionType'] == 'REMAINING') {
      actionType = SaleActionType.REMAINING;
    } else if (json['actionType'] == 'SOLD') {
      actionType = SaleActionType.SOLD;
    } else {
      actionType = SaleActionType.PREPARED; // default
    }

    // Use the appropriate quantity based on action type
    int quantity;
    if (actionType == SaleActionType.PREPARED) {
      quantity = json['preparedQty'] ?? 0;
    } else if (actionType == SaleActionType.REMAINING) {
      quantity = json['remainingQty'] ?? 0;
    } else {
      // For SOLD type, use soldQty
      quantity = json['soldQty'] ?? 0;
    }


    return SalesResponseModel(
      saleId: json['saleId'] ?? 0,
      itemName: json['itemName'] ?? 'Unknown',
      variation: json['variation'] ?? 'Standard',
      price: json['price'] ?? 0,
      cost: json['cost'] ?? 0,
      quantity: quantity,
      actionType: actionType,
      transactionTime: json['transactionTime'] != null
          ? DateTime.parse(json['transactionTime'])
          : DateTime.now(),
      recordedBy: json['recordedBy'] ?? '',
    );
  }
}

class RemainingModel {
  final String itemName;
  final String variation;
  final int remaining;

  RemainingModel({
    required this.itemName,
    required this.variation,
    required this.remaining,
  });

  factory RemainingModel.fromJson(Map<String, dynamic> json) {
    return RemainingModel(
      itemName: json['itemName'],
      variation: json['variation'],
      remaining: json['remaining'],
    );
  }
}

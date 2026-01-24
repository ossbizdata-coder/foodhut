class TodaySummaryModel {
  final int totalPreparedQty;
  final int totalRemainingQty;
  final int totalSoldQty;
  final int totalAmount;
  final int totalProfit;

  TodaySummaryModel({
    required this.totalPreparedQty,
    required this.totalRemainingQty,
    required this.totalSoldQty,
    required this.totalAmount,
    required this.totalProfit,
  });

  factory TodaySummaryModel.fromJson(Map<String, dynamic> json) {
    return TodaySummaryModel(
      totalPreparedQty: json['totalPreparedQty'] ?? 0,
      totalRemainingQty: json['totalRemainingQty'] ?? 0,
      totalSoldQty: json['totalSoldQty'] ?? 0,
      totalAmount: json['totalAmount'] ?? 0,
      totalProfit: json['totalProfit'] ?? 0,
    );
  }
}

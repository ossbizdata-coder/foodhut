import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../models/today_summary_model.dart';
import '../models/menu_item_model.dart';

class TotalSalesScreen extends StatefulWidget {
  const TotalSalesScreen({super.key});

  @override
  State<TotalSalesScreen> createState() => _TotalSalesScreenState();
}

class _TotalSalesScreenState extends State<TotalSalesScreen> {
  int totalPreparedQty = 0;
  int totalRemainingQty = 0;
  int totalSoldQty = 0;
  int totalPreparedAmount = 0;
  int totalSoldAmount = 0;
  int totalRemainingAmount = 0;
  bool loading = true;

  DateTime selectedDate = DateTime.now();

  List<SalesResponseModel> salesList = [];
  Map<String, SoldItemGroup> groupedSales = {};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => loading = true);
    final dateStr = _formatDate(selectedDate);

    try {
      final TodaySummaryModel res =
      await ApiService.getTodaySalesSummary(dateStr);

      List<SalesResponseModel> sales =
      await ApiService.getSalesForDay(dateStr);

      // Group by item+variation and calculate SOLD quantities
      // Sold = Prepared - Remaining for each item
      final Map<String, SoldItemGroup> grouped = {};

      for (var sale in sales) {
        final key = '${sale.itemName}|${sale.variation}';

        if (!grouped.containsKey(key)) {
          grouped[key] = SoldItemGroup(
            itemName: sale.itemName,
            variation: sale.variation,
            price: sale.price,
            quantity: 0,
          );
        }

        // Add to prepared, subtract remaining
        if (sale.actionType == SaleActionType.PREPARED) {
          grouped[key]!.quantity += sale.quantity;
        } else if (sale.actionType == SaleActionType.REMAINING) {
          grouped[key]!.quantity -= sale.quantity;
        }
      }

      // Remove items with 0 or negative sold quantity
      grouped.removeWhere((key, value) => value.quantity <= 0);

      // Calculate total amounts
      int preparedAmount = 0;
      int remainingAmount = 0;

      for (var sale in sales) {
        if (sale.actionType == SaleActionType.PREPARED) {
          preparedAmount += sale.quantity * sale.price;
        } else if (sale.actionType == SaleActionType.REMAINING) {
          remainingAmount += sale.quantity * sale.price;
        }
      }

      // Sold = Prepared - Remaining
      int soldAmount = preparedAmount - remainingAmount;


      if (!mounted) return;
      setState(() {
        totalPreparedQty = res.totalPreparedQty;
        totalRemainingQty = res.totalRemainingQty;
        totalSoldQty = res.totalSoldQty;
        totalPreparedAmount = preparedAmount;
        totalSoldAmount = soldAmount;
        totalRemainingAmount = remainingAmount;
        salesList = sales;
        groupedSales = grouped;
        loading = false;
      });

      print('=== END DEBUG ===');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FB);
    const green = Color(0xFF21C36F);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: green,
        centerTitle: true,
        title: const Text(
          'Sales Summary',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // ===== DATE PICKER (COMPACT) =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        selectedDate = selectedDate
                            .subtract(const Duration(days: 1));
                      });
                      _loadSummary();
                    },
                  ),
                  Text(
                    _formatDate(selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: selectedDate.isBefore(DateTime.now())
                        ? () {
                      setState(() {
                        selectedDate = selectedDate
                            .add(const Duration(days: 1));
                      });
                      _loadSummary();
                    }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // ===== COMPACT SUMMARY STRIP =====
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: green.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _miniStat(
                    label: 'Prepared',
                    value: 'Rs: $totalPreparedAmount',
                    color: Colors.blue,
                    icon: Icons.restaurant_menu,
                  ),
                  _divider(),
                  _miniStat(
                    label: 'Sold',
                    value: 'Rs: $totalSoldAmount',
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                  _divider(),
                  _miniStat(
                    label: 'Remaining',
                    value: 'Rs: $totalRemainingAmount',
                    color: Colors.deepOrange,
                    icon: Icons.delete_outline,
                  ),
                ],
              ),
            ),
          ),

          // ===== ITEMS SOLD =====
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.shopping_cart,
                    size: 20, color: Color(0xFF21C36F)),
                SizedBox(width: 8),
                Text(
                  'Items Sold',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: groupedSales.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No detailed items found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (totalPreparedQty > 0 || totalSoldQty > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Summary shows ${totalPreparedQty} prepared, ${totalSoldQty} sold, but detailed list is empty.\n\nThis may mean the API is returning summary but not detailed items.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'No items sold yet for this date',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: groupedSales.length,
              itemBuilder: (context, index) {
                final item =
                groupedSales.values.elementAt(index);
                final totalAmount = item.quantity * item.price;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.itemName} (${item.quantity})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs: $totalAmount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: green,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===== MINI STAT =====
  Widget _miniStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 36,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }
}

// ===== GROUPED SOLD ITEM =====
class SoldItemGroup {
  final String itemName;
  final String variation;
  final int price;
  int quantity;

  SoldItemGroup({
    required this.itemName,
    required this.variation,
    required this.price,
    required this.quantity,
  });
}

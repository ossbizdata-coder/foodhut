import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../services/auth_services.dart';
import '../models/menu_item_model.dart';
import '../services/pin_service.dart';
import 'add_item_screen.dart';
import 'add_new_item_screen.dart';
import 'total_sales_screen.dart';
import 'superadmin_dashboard_screen.dart';
import 'item_detail_screen.dart';
import 'login.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int totalPreparedQty = 0;
  int totalRemainingQty = 0;
  int totalSoldQty = 0;
  int totalPreparedAmount = 0;
  int totalSoldAmount = 0;
  int totalRemainingAmount = 0;
  bool loading = true;
  String? userRole;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadTodaySummary();
  }

  Future<void> _loadUserRole() async {
    final role = await AuthService.getRole();
    setState(() {
      userRole = role;
    });
  }

  Future<void> _loadTodaySummary() async {
    final date =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final summaryRes = await ApiService.getTodaySalesSummary(date);
      final sales = await ApiService.getSalesForDay(date);

      // Get previous day's remaining to calculate actual sold items
      final previousDate = selectedDate.subtract(const Duration(days: 1));
      final prevDateStr = '${previousDate.year}-${previousDate.month.toString().padLeft(2, '0')}-${previousDate.day.toString().padLeft(2, '0')}';

      int previousDayRemainingAmount = 0;
      try {
        final prevRemaining = await ApiService.getRemainingForDay(prevDateStr);

        // Create a price map from today's sales
        final Map<String, int> priceMap = {};
        for (var sale in sales) {
          final key = '${sale.itemName}|${sale.variation}';
          priceMap[key] = sale.price;
        }

        // Calculate previous day remaining amount using today's prices
        for (var item in prevRemaining) {
          final key = '${item.itemName}|${item.variation}';
          final price = priceMap[key] ?? 0;
          previousDayRemainingAmount += item.remaining * price;
        }
      } catch (e) {
        // No previous day data or error - assume 0
        previousDayRemainingAmount = 0;
      }

      // Calculate actual amounts from sales data
      int preparedAmount = 0;
      int remainingAmount = 0;

      for (var sale in sales) {
        if (sale.actionType == SaleActionType.PREPARED) {
          preparedAmount += sale.quantity * sale.price;
        } else if (sale.actionType == SaleActionType.REMAINING) {
          remainingAmount += sale.quantity * sale.price;
        }
      }

      // Sold = (Previous Day Remaining + Today's Prepared) - Today's Remaining
      int soldAmount = previousDayRemainingAmount + preparedAmount - remainingAmount;

      if (!mounted) return;
      setState(() {
        totalPreparedQty = summaryRes.totalPreparedQty;
        totalRemainingQty = summaryRes.totalRemainingQty;
        totalSoldQty = summaryRes.totalSoldQty;
        totalPreparedAmount = preparedAmount;
        totalSoldAmount = soldAmount;
        totalRemainingAmount = remainingAmount;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _showItemDetails(String title, SaleActionType actionType, Color color) async {
    final date = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final sales = await ApiService.getSalesForDay(date);
      final filteredSales = sales.where((sale) => sale.actionType == actionType).toList();

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            title: title,
            items: filteredSales,
            color: color,
            selectedDate: selectedDate,
          ),
        ),
      );

      // Refresh if changes were made
      if (result == true) {
        _loadTodaySummary();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: $e')),
      );
    }
  }

  Future<void> _showSoldItemDetails() async {
    final date = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final sales = await ApiService.getSalesForDay(date);

      // Get previous day's remaining items
      final previousDate = selectedDate.subtract(const Duration(days: 1));
      final prevDateStr = '${previousDate.year}-${previousDate.month.toString().padLeft(2, '0')}-${previousDate.day.toString().padLeft(2, '0')}';

      final Map<String, int> previousRemainingMap = {};
      try {
        final prevRemaining = await ApiService.getRemainingForDay(prevDateStr);
        for (var item in prevRemaining) {
          final key = '${item.itemName}|${item.variation}';
          previousRemainingMap[key] = item.remaining;
        }
      } catch (e) {
        // No previous day data - continue with empty map
      }

      // Create sold items using PREPARED items but with calculated sold quantity
      // Group and accumulate quantities by item+variation
      final Map<String, Map<String, dynamic>> preparedMap = {};
      final Map<String, int> remainingMap = {};

      for (var sale in sales) {
        final key = '${sale.itemName}|${sale.variation}';

        if (sale.actionType == SaleActionType.PREPARED) {
          if (!preparedMap.containsKey(key)) {
            preparedMap[key] = {
              'itemName': sale.itemName,
              'variation': sale.variation,
              'price': sale.price,
              'cost': sale.cost,
              'quantity': 0,
              'saleId': sale.saleId,
              'transactionTime': sale.transactionTime,
              'recordedBy': sale.recordedBy,
            };
          }
          preparedMap[key]!['quantity'] = (preparedMap[key]!['quantity'] as int) + sale.quantity;
        } else if (sale.actionType == SaleActionType.REMAINING) {
          remainingMap[key] = (remainingMap[key] ?? 0) + sale.quantity;
        }
      }

      // Create sold items list using: (Previous Remaining + Prepared) - Today's Remaining
      final List<SalesResponseModel> soldItems = [];

      // Combine all unique items from prepared and previous remaining
      final allKeys = {...preparedMap.keys, ...previousRemainingMap.keys};

      for (var key in allKeys) {
        final preparedData = preparedMap[key];
        final preparedQty = preparedData != null ? preparedData['quantity'] as int : 0;
        final previousRemainingQty = previousRemainingMap[key] ?? 0;
        final todayRemainingQty = remainingMap[key] ?? 0;

        // Sold = (Previous Remaining + Prepared) - Today's Remaining
        final soldQty = previousRemainingQty + preparedQty - todayRemainingQty;

        if (soldQty > 0) {
          // If we have prepared data, use it; otherwise get data from today's remaining
          Map<String, dynamic>? itemData = preparedData;

          // If no prepared data but we have previous remaining, try to get price from today's remaining or sales
          if (itemData == null && previousRemainingQty > 0) {
            // Look for this item in today's remaining records to get price
            for (var sale in sales) {
              final saleKey = '${sale.itemName}|${sale.variation}';
              if (saleKey == key) {
                itemData = {
                  'itemName': sale.itemName,
                  'variation': sale.variation,
                  'price': sale.price,
                  'cost': sale.cost,
                  'saleId': sale.saleId,
                  'transactionTime': sale.transactionTime,
                  'recordedBy': sale.recordedBy,
                };
                break;
              }
            }
          }

          if (itemData != null) {
            // Create a sold item with the sold quantity
            soldItems.add(SalesResponseModel(
              saleId: itemData['saleId'] as int,
              itemName: itemData['itemName'] as String,
              variation: itemData['variation'] as String,
              price: itemData['price'] as int,
              cost: itemData['cost'] as int,
              quantity: soldQty,
              actionType: SaleActionType.SOLD,
              transactionTime: itemData['transactionTime'] as DateTime,
              recordedBy: itemData['recordedBy'] as String,
            ));
          }
        }
      }


      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            title: 'Sold Items',
            items: soldItems,
            color: const Color(0xFF2196F3), // Blue color
            allowEdit: false, // Sold items are calculated, not editable
            selectedDate: selectedDate,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sold items: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF21C36F);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: green,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'OneStopFoodHut',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => loading = true);
              _loadTodaySummary();
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TotalSalesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await PinService.clearPin();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodaySummary,
              color: green,
              child: Column(
                children: [
                // ===== DATE SWITCHER =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF21C36F).withAlpha(80),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF21C36F).withAlpha(20),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 24),
                          color: const Color(0xFF21C36F),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              selectedDate = selectedDate.subtract(const Duration(days: 1));
                              loading = true;
                            });
                            _loadTodaySummary();
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF21C36F),
                                      onPrimary: Colors.white,
                                      onSurface: Color(0xFF1E293B),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != selectedDate) {
                              setState(() {
                                selectedDate = picked;
                                loading = true;
                              });
                              _loadTodaySummary();
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF21C36F),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(selectedDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 24),
                          color: _isToday() ? const Color(0xFFCBD5E1) : const Color(0xFF21C36F),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _isToday()
                              ? null
                              : () {
                                  setState(() {
                                    selectedDate = selectedDate.add(const Duration(days: 1));
                                    loading = true;
                                  });
                                  _loadTodaySummary();
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== SUMMARY CARDS =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                label: 'Prepared',
                                value: totalPreparedAmount.toString(),
                                icon: Icons.restaurant_menu,
                                color: const Color(0xFF21C36F),
                                bgColor: Colors.white,
                                onTap: () => _showItemDetails('Prepared Items', SaleActionType.PREPARED, const Color(0xFF21C36F)),
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                label: 'Sold',
                                value: totalSoldAmount.toString(),
                                icon: Icons.trending_up,
                                color: const Color(0xFF2196F3),
                                bgColor: Colors.white,
                                onTap: () => _showSoldItemDetails(),
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                label: 'Remaining',
                                value: totalRemainingAmount.toString(),
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFFFF9F3A),
                                bgColor: Colors.white,
                                onTap: () => _showItemDetails('Remaining Items', SaleActionType.REMAINING, const Color(0xFFFF9F3A)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ===== ACTION BUTTONS =====
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            children: [
                              _actionTile(
                                title: 'Add Prepared Item',
                                icon: Icons.add_circle_outline,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF21C36F), Color(0xFF1FAD5E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                isDisabled: !_isToday(),
                                onTap: _isToday() ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => AddItemScreen(selectedDate: selectedDate)),
                                  );
                                  _loadTodaySummary();
                                } : null,
                              ),
                              const SizedBox(height: 14),
                              _actionTile(
                                title: 'Add Remaining Item',
                                icon: Icons.inventory_2_outlined,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF9F3A), Color(0xFFFF8C1A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                isDisabled: !_isToday(),
                                onTap: _isToday() ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        AddItemScreen(isRemaining: true, selectedDate: selectedDate)),
                                  );
                                  _loadTodaySummary();
                                } : null,
                              ),
                              const SizedBox(height: 14),
                              _actionTile(
                                title: 'Add New Menu Item',
                                icon: Icons.restaurant_menu,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7007B6), Color(0xFFF5576C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const AddNewItemScreen()),
                                  );
                                },
                              ),

                              if (userRole == 'SUPERADMIN') ...[
                                const SizedBox(height: 14),
                                _actionTile(
                                  title: 'Business Overview',
                                  icon: Icons.dashboard_outlined,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFA8BFF), Color(0xFF2BD2FF), Color(0xFF2BFF88)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                          const SuperAdminDashboardScreen()),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ===== SUMMARY CARD =====
  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withAlpha(200),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(100),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ===== ACTION TILE =====
  Widget _actionTile({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
    Color? color,
    Color? bgColor,
    Gradient? gradient,
    bool isDisabled = false,
  }) {
    final hasGradient = gradient != null;
    final effectiveColor = color ?? const Color(0xFF6C63FF);
    final effectiveBgColor = bgColor ?? Colors.white;
    final isGreenBg = effectiveBgColor == const Color(0xFF1FAD5E);

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: gradient ?? LinearGradient(
              colors: isGreenBg
                  ? [
                      const Color(0xFF1FAD5E),
                      const Color(0xFF16A34A),
                    ]
                  : [
                      effectiveBgColor,
                      effectiveBgColor.withAlpha(200),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasGradient
                  ? Colors.white.withAlpha(80)
                  : isGreenBg
                      ? Colors.white.withAlpha(100)
                      : effectiveColor.withAlpha(100),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasGradient
                    ? const Color(0xFF667EEA).withAlpha(80)
                    : isGreenBg
                        ? const Color(0xFF1FAD5E).withAlpha(80)
                        : effectiveColor.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withAlpha(150),
                blurRadius: 10,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasGradient || isGreenBg
                        ? [
                            Colors.white.withAlpha(100),
                            Colors.white.withAlpha(50),
                          ]
                        : [
                            effectiveColor.withAlpha(40),
                            effectiveColor.withAlpha(20),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasGradient || isGreenBg
                        ? Colors.white.withAlpha(120)
                        : effectiveColor.withAlpha(80),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (hasGradient || isGreenBg
                          ? Colors.white
                          : effectiveColor).withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: hasGradient || isGreenBg ? Colors.white : effectiveColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: hasGradient || isGreenBg ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: 0.3,
                        shadows: hasGradient || isGreenBg ? [
                          Shadow(
                            color: Colors.black.withAlpha(40),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ] : null,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasGradient || isGreenBg
                      ? Colors.white
                      : effectiveColor).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: hasGradient || isGreenBg
                      ? Colors.white
                      : effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to check if selected date is today
  bool _isToday() {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }


}

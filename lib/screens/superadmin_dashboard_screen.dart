import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../models/menu_item_model.dart';

const appBarGreen = Color(0xFF1DBF73);

// Sri Lankan Full Moon Poya Days (Add/Update as needed)
// Format: 'YYYY-MM-DD'
const List<String> poyaDays = [
  // 2026
  '2026-01-03', // Duruthu Poya
  '2026-02-01', // Navam Poya
  '2026-03-02', // Medin Poya
  '2026-04-01', // Bak Poya
  '2026-05-01', // Vesak Poya
  '2026-05-30', // Poson Poya
  '2026-06-29', // Esala Poya
  '2026-07-29', // Nikini Poya
  '2026-08-27', // Binara Poya
  '2026-09-26', // Vap Poya
  '2026-10-25', // Il Poya
  '2026-11-24', // Unduvap Poya
  '2026-12-23', // Duruthu Poya
];

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  bool loading = true;
  DateTime selectedDate = DateTime.now();
  int currentTabIndex = 0;

  // Today's Summary
  int totalPrepared = 0;
  int totalRemaining = 0;
  int totalSold = 0;
  int totalRevenue = 0;
  int totalProfit = 0;
  int totalCost = 0;

  // Previous day's remaining (carry-over)
  int carryOverFromYesterday = 0;

  // Item-wise breakdown
  List<ItemPerformance> itemPerformances = [];

  // Monthly item-wise breakdown (cumulative)
  List<ItemPerformance> monthlyItemPerformances = [];

  // Weekly trend (last 7 days)
  List<DailySummary> weeklyTrend = [];

  // Staff performance
  List<StaffPerformance> staffPerformances = [];

  // Monthly overview (independent of selected date)
  int monthlyTotalRevenue = 0;
  int monthlyTotalProfit = 0;
  int monthlyTotalSold = 0;
  int monthlyTotalPrepared = 0;
  int monthlyTotalRemaining = 0;
  int monthlyTarget = 0;
  int monthlyDaysWorked = 0;
  double monthlyAchievementPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }


  Future<void> _loadDashboard() async {
    setState(() => loading = true);

    try {
      await Future.wait([
        _loadTodaySummary(),
        _loadCarryOver(),
        _loadItemPerformance(),
        _loadWeeklyTrend(),
        _loadStaffPerformance(),
        _loadMonthlyOverview(),
        _loadMonthlyItemPerformance(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadTodaySummary() async {
    final dateStr = _formatDate(selectedDate);
    final summary = await ApiService.getTodaySalesSummary(dateStr);
    final sales = await ApiService.getSalesForDay(dateStr);

    // Calculate costs and revenue
    int preparedAmount = 0;
    int remainingAmount = 0;
    int totalCostPrepared = 0;
    int totalCostRemaining = 0;

    for (var sale in sales) {
      if (sale.actionType == SaleActionType.PREPARED) {
        preparedAmount += sale.quantity * sale.price;
        totalCostPrepared += sale.quantity * sale.cost;
      } else if (sale.actionType == SaleActionType.REMAINING) {
        remainingAmount += sale.quantity * sale.price;
        totalCostRemaining += sale.quantity * sale.cost;
      }
    }

    // Revenue = Sold Amount = Prepared - Remaining
    int revenue = preparedAmount - remainingAmount;

    // Cost of sold items = Cost of prepared - Cost of remaining
    int costOfSold = totalCostPrepared - totalCostRemaining;

    // Profit = Revenue - Cost of sold items
    int profit = revenue - costOfSold;

    setState(() {
      totalPrepared = summary.totalPreparedQty;
      totalRemaining = summary.totalRemainingQty;
      totalSold = summary.totalSoldQty;
      totalRevenue = revenue;
      totalProfit = profit;
      totalCost = costOfSold;
    });
  }

  Future<void> _loadCarryOver() async {
    // Get yesterday's remaining
    final yesterday = selectedDate.subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);

    try {
      final remaining = await ApiService.getRemainingForDay(dateStr);
      int carryOver = 0;
      for (var item in remaining) {
        carryOver += item.remaining;
      }
      setState(() {
        carryOverFromYesterday = carryOver;
      });
    } catch (e) {
      // No data for yesterday
      setState(() {
        carryOverFromYesterday = 0;
      });
    }
  }

  Future<void> _loadItemPerformance() async {
    final dateStr = _formatDate(selectedDate);
    final sales = await ApiService.getSalesForDay(dateStr);

    // Group by item and calculate performance
    final Map<String, ItemPerformance> grouped = {};

    for (var sale in sales) {
      final key = '${sale.itemName}|${sale.variation}';

      if (!grouped.containsKey(key)) {
        grouped[key] = ItemPerformance(
          itemName: sale.itemName,
          variation: sale.variation,
          price: sale.price,
          cost: sale.cost,
          prepared: 0,
          remaining: 0,
          sold: 0,
          revenue: 0,
          profit: 0,
        );
      }

      if (sale.actionType == SaleActionType.PREPARED) {
        grouped[key]!.prepared += sale.quantity;
      } else if (sale.actionType == SaleActionType.REMAINING) {
        grouped[key]!.remaining += sale.quantity;
      }
    }

    // Calculate sold, revenue, and profit for each item
    for (var perf in grouped.values) {
      perf.sold = perf.prepared - perf.remaining;
      perf.revenue = perf.sold * perf.price;
      perf.profit = perf.sold * (perf.price - perf.cost);
    }

    // Sort by revenue (highest first)
    final sortedList = grouped.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    setState(() {
      itemPerformances = sortedList;
    });
  }

  Future<void> _loadWeeklyTrend() async {
    final List<DailySummary> trend = [];

    for (int i = 6; i >= 0; i--) {
      final date = selectedDate.subtract(Duration(days: i));
      final dateStr = _formatDate(date);

      try {
        final summary = await ApiService.getTodaySalesSummary(dateStr);
        final sales = await ApiService.getSalesForDay(dateStr);

        // Calculate revenue and profit manually
        int preparedAmount = 0;
        int remainingAmount = 0;
        int totalCostPrepared = 0;
        int totalCostRemaining = 0;

        for (var sale in sales) {
          if (sale.actionType == SaleActionType.PREPARED) {
            preparedAmount += sale.quantity * sale.price;
            totalCostPrepared += sale.quantity * sale.cost;
          } else if (sale.actionType == SaleActionType.REMAINING) {
            remainingAmount += sale.quantity * sale.price;
            totalCostRemaining += sale.quantity * sale.cost;
          }
        }

        int revenue = preparedAmount - remainingAmount;
        int costOfSold = totalCostPrepared - totalCostRemaining;
        int profit = revenue - costOfSold;

        trend.add(DailySummary(
          date: date,
          sold: summary.totalSoldQty,
          revenue: revenue,
          profit: profit,
        ));
      } catch (e) {
        trend.add(DailySummary(
          date: date,
          sold: 0,
          revenue: 0,
          profit: 0,
        ));
      }
    }

    setState(() {
      weeklyTrend = trend;
    });
  }

  Future<void> _loadStaffPerformance() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Always use "Piyumi (Food Hut Manager)" as the staff name
    const staffName = 'Piyumi (FoodHut Manager)';

    int revenue = 0;
    int workingDays = 0;
    int monthlyTarget = 0;

    // Count Sundays to track 1st and 3rd
    int sundayCount = 0;

    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(year, month, d);
      if (date.month != month) break;

      final isSaturday = date.weekday == DateTime.saturday;
      final isSunday = date.weekday == DateTime.sunday;

      final dateStr = _formatDate(date);
      final isPoyaDay = poyaDays.contains(dateStr);

      // Track Sunday count
      if (isSunday) {
        sundayCount++;
      }

      // Check if this is 1st or 3rd Sunday (no target)
      final isFirstOrThirdSunday = isSunday && (sundayCount == 1 || sundayCount == 3);

      // All Saturdays and 1st/3rd Sundays are OFF (no target)
      final isOffDay = isSaturday || isFirstOrThirdSunday;

      // Calculate target for this day (skip Saturdays, 1st/3rd Sundays, and Poya days for target)
      if (!isOffDay && !isPoyaDay) {
        workingDays++;
        monthlyTarget += isSunday ? 5000 : 10000; // Other Sundays (2nd, 4th, 5th) = half target (Rs. 5,000)
      }

      // Always process sales for ALL days (including off days)
      try {
        final sales = await ApiService.getSalesForDay(dateStr);

        // Calculate revenue correctly: Prepared - Remaining
        int preparedAmount = 0;
        int remainingAmount = 0;

        for (var sale in sales) {
          if (sale.actionType == SaleActionType.PREPARED) {
            preparedAmount += sale.quantity * sale.price;
          } else if (sale.actionType == SaleActionType.REMAINING) {
            remainingAmount += sale.quantity * sale.price;
          }
        }

        // Revenue = Sold Amount = Prepared - Remaining
        revenue += (preparedAmount - remainingAmount);
      } catch (e) {
        // Skip if no data for this day
      }
    }

    // Calculate performance
    final achievementPercent = monthlyTarget > 0
        ? (revenue / monthlyTarget * 100)
        : 0.0;

    // Break-even calculations
    const int breakEvenGoal = 214500; // Primary goal for Food Hut
    final breakEvenPercent = (revenue / breakEvenGoal * 100);
    final breakEvenAchieved = revenue >= breakEvenGoal;
    final overPerformance = breakEvenAchieved ? (revenue - breakEvenGoal) : 0;

    // Bonus calculation: 5% of over-performance amount
    final estimatedBonus = (overPerformance * 0.05).round();

    final performances = [
      StaffPerformance(
        staffName: staffName,
        targetAmount: monthlyTarget,
        actualAmount: revenue,
        daysWorked: workingDays,
        achievementPercent: achievementPercent,
        shortfall: monthlyTarget - revenue,
        breakEvenGoal: breakEvenGoal,
        breakEvenPercent: breakEvenPercent,
        breakEvenAchieved: breakEvenAchieved,
        overPerformance: overPerformance,
        estimatedBonus: estimatedBonus,
      ),
    ];

    setState(() {
      staffPerformances = performances;
    });
  }

  Future<void> _loadMonthlyOverview() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    int totalRevenue = 0;
    int totalProfit = 0;
    int totalSold = 0;
    int totalPrepared = 0;
    int latestRemaining = 0; // Only track the most recent day's remaining
    int workingDays = 0;
    int targetAmount = 0;

    // Count Sundays to track 1st and 3rd
    int sundayCount = 0;

    // Loop through all days of current month up to today
    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(year, month, d);
      if (date.month != month) break;

      final isSaturday = date.weekday == DateTime.saturday;
      final isSunday = date.weekday == DateTime.sunday;

      final dateStr = _formatDate(date);
      final isPoyaDay = poyaDays.contains(dateStr);

      // Track Sunday count
      if (isSunday) {
        sundayCount++;
      }

      // Check if this is 1st or 3rd Sunday (no target)
      final isFirstOrThirdSunday = isSunday && (sundayCount == 1 || sundayCount == 3);

      // All Saturdays and 1st/3rd Sundays are OFF (no target)
      final isOffDay = isSaturday || isFirstOrThirdSunday;

      // Calculate target for this day (skip Saturdays, 1st/3rd Sundays, and Poya days for target)
      if (!isOffDay && !isPoyaDay) {
        workingDays++;
        targetAmount += isSunday ? 5000 : 10000; // Other Sundays (2nd, 4th, 5th) = half target (Rs. 5,000)
      }

      // Always process sales for all days (including off days)
      try {
        final sales = await ApiService.getSalesForDay(dateStr);
        final summary = await ApiService.getTodaySalesSummary(dateStr);

        // Calculate revenue and profit manually
        int preparedAmount = 0;
        int remainingAmount = 0;
        int totalCostPrepared = 0;
        int totalCostRemaining = 0;

        for (var sale in sales) {
          if (sale.actionType == SaleActionType.PREPARED) {
            preparedAmount += sale.quantity * sale.price;
            totalCostPrepared += sale.quantity * sale.cost;
          } else if (sale.actionType == SaleActionType.REMAINING) {
            remainingAmount += sale.quantity * sale.price;
            totalCostRemaining += sale.quantity * sale.cost;
          }
        }

        int revenue = preparedAmount - remainingAmount;
        int costOfSold = totalCostPrepared - totalCostRemaining;
        int profit = revenue - costOfSold;

        totalRevenue += revenue;
        totalProfit += profit;
        totalSold += summary.totalSoldQty;
        totalPrepared += summary.totalPreparedQty;

        // For remaining: only keep the latest day's value (most recent)
        // Since yesterday's remaining becomes today's inventory
        if (d == now.day) {
          latestRemaining = summary.totalRemainingQty;
        }
      } catch (e) {
        // Skip if no data for this day
      }
    }

    final achievementPercent = targetAmount > 0
        ? (totalRevenue / targetAmount * 100)
        : 0.0;

    setState(() {
      monthlyTotalRevenue = totalRevenue;
      monthlyTotalProfit = totalProfit;
      monthlyTotalSold = totalSold;
      monthlyTotalPrepared = totalPrepared;
      monthlyTotalRemaining = latestRemaining; // Only today's remaining
      monthlyTarget = targetAmount;
      monthlyDaysWorked = workingDays;
      monthlyAchievementPercent = achievementPercent;
    });
  }

  Future<void> _loadMonthlyItemPerformance() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Track cumulative item performance for the entire month
    final Map<String, ItemPerformance> grouped = {};

    // Loop through all days of the month up to today (including all days)
    for (int d = 1; d <= now.day; d++) {
      final date = DateTime(year, month, d);
      if (date.month != month) break;


      final dateStr = _formatDate(date);

      try {
        final sales = await ApiService.getSalesForDay(dateStr);

        for (var sale in sales) {
          final key = '${sale.itemName}|${sale.variation}';

          if (!grouped.containsKey(key)) {
            grouped[key] = ItemPerformance(
              itemName: sale.itemName,
              variation: sale.variation,
              price: sale.price,
              cost: sale.cost,
              prepared: 0,
              remaining: 0,
              sold: 0,
              revenue: 0,
              profit: 0,
            );
          }

          if (sale.actionType == SaleActionType.PREPARED) {
            grouped[key]!.prepared += sale.quantity;
          } else if (sale.actionType == SaleActionType.REMAINING) {
            grouped[key]!.remaining += sale.quantity;
          }
        }
      } catch (e) {
        // Skip if no data for this day
      }
    }

    // Calculate sold, revenue, and profit for each item
    for (var perf in grouped.values) {
      perf.sold = perf.prepared - perf.remaining;
      perf.revenue = perf.sold * perf.price;
      perf.profit = perf.sold * (perf.price - perf.cost);
    }

    // Sort by revenue (highest first)
    final sortedList = grouped.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    setState(() {
      monthlyItemPerformances = sortedList;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadDashboard();
    }
  }

  void _goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
    _loadDashboard();
  }

  void _goToNextDay() {
    final tomorrow = selectedDate.add(const Duration(days: 1));
    final now = DateTime.now();

    // Don't allow going beyond today
    if (tomorrow.isBefore(now) || _formatDate(tomorrow) == _formatDate(now)) {
      setState(() {
        selectedDate = tomorrow;
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: appBarGreen,
        title: const Text(
          'Business Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom Tab Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          index: 0,
                          icon: Icons.show_chart,
                          label: 'Performance',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTabButton(
                          index: 1,
                          icon: Icons.today,
                          label: 'Daily Overview',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTabButton(
                          index: 2,
                          icon: Icons.calendar_month,
                          label: 'Monthly Overview',
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: _buildCurrentTabContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          currentTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? appBarGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? appBarGreen : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: appBarGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (currentTabIndex) {
      case 0:
        return _buildStaffPerformanceTab();
      case 1:
        return _buildDailyOverviewTab();
      case 2:
        return _buildMonthlyOverviewTab();
      default:
        return _buildStaffPerformanceTab();
    }
  }

  // ========== TAB 1: PERFORMANCE ==========
  Widget _buildStaffPerformanceTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Staff Performance
            _buildStaffPerformanceCard(),
            const SizedBox(height: 24),

            // Top Performers (Monthly - cumulative)
            _buildMonthlyTopItemsCard(),
            const SizedBox(height: 16),

            // 7-Day Trend
            _buildWeeklyTrendCard(),
          ],
        ),
      ),
    );
  }

  // ========== TAB 2: DAILY OVERVIEW ==========
  Widget _buildDailyOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Navigation with Picker
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: appBarGreen, width: 1.5),
              ),
              child: Row(
                children: [
                  // Previous day
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: appBarGreen, size: 24),
                    onPressed: _goToPreviousDay,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  // Date display and picker
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: appBarGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, color: appBarGreen, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _formatDisplayDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: appBarGreen,
                              ),
                            ),
                            if (_formatDate(selectedDate) == _formatDate(DateTime.now())) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: appBarGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Next day
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: appBarGreen, size: 24),
                    onPressed: _goToNextDay,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Daily Inventory Flow Card
            _buildInventoryFlowCard(),
            const SizedBox(height: 16),

            // Daily Financial Overview Card
            _buildFinancialCard(),
            const SizedBox(height: 16),

            // Top Performers (Daily)
            _buildTopItemsCard(),
            const SizedBox(height: 16),

            // All Item Performance
            _buildDetailedItemsCard(),
          ],
        ),
      ),
    );
  }

  // ========== TAB 3: MONTHLY OVERVIEW ==========
  Widget _buildMonthlyOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Monthly Inventory Summary
            _buildMonthlyInventorySummary(),
            const SizedBox(height: 16),

            // Monthly Financial Summary
            _buildMonthlyFinancialSummary(),
            const SizedBox(height: 16),

            // Top Performers (Monthly)
            _buildMonthlyTopItemsCard(),
            const SizedBox(height: 16),

            // All Item Performance (Monthly)
            _buildMonthlyDetailedItemsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final isToday = _formatDate(selectedDate) == _formatDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBarGreen, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'Today' : 'Selected Date',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDisplayDate(selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appBarGreen,
                ),
              ),
            ],
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: appBarGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentMonthName() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildMonthlyOverviewCard() {
    final now = DateTime.now();
    final monthName = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][now.month - 1];

    final shortfall = monthlyTarget - monthlyTotalRevenue;
    final isOnTarget = monthlyAchievementPercent >= 100;
    final isGood = monthlyAchievementPercent >= 80;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appBarGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOnTarget ? Icons.star : Icons.calendar_month,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$monthName ${now.year} • Day ${now.day}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isOnTarget)
                const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 32,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Achievement',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${monthlyAchievementPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (monthlyAchievementPercent / 100).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOnTarget ? Colors.yellow : Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white38, height: 1),
          const SizedBox(height: 20),

          // Statistics Grid
          Row(
            children: [
              Expanded(
                child: _monthlyStatBox(
                  '💰 Revenue',
                  'Rs: $monthlyTotalRevenue',
                  'Target: Rs: $monthlyTarget',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _monthlyStatBox(
                  '📈 Profit',
                  'Rs: $monthlyTotalProfit',
                  '${monthlyTotalRevenue > 0 ? ((monthlyTotalProfit / monthlyTotalRevenue * 100).toStringAsFixed(1)) : "0"}% margin',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _monthlyStatBox(
                  '🛒 Items Sold',
                  '$monthlyTotalSold',
                  'Total this month',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _monthlyStatBox(
                  shortfall > 0 ? '⚠️ Shortfall' : '✨ Surplus',
                  'Rs: ${shortfall.abs()}',
                  '$monthlyDaysWorked days worked',
                ),
              ),
            ],
          ),

          if (shortfall > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Need Rs: ${(shortfall / (DateTime(now.year, now.month + 1, 0).day - now.day)).toInt()} per day to reach target',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthlyStatBox(String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyInventorySummary() {
    // Calculate monthly inventory totals
    // Sold = Prepared - Remaining (verification)
    final calculatedSold = monthlyTotalPrepared - monthlyTotalRemaining;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Monthly Inventory Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total items prepared, sold and remaining this month',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(color: Colors.white54, height: 24),
          Row(
            children: [
              Expanded(
                child: _monthlyInventoryStat(
                  icon: Icons.add_circle_outline,
                  label: 'Total Prepared',
                  value: monthlyTotalPrepared,
                  color: Colors.white,
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white38),
              Expanded(
                child: _monthlyInventoryStat(
                  icon: Icons.shopping_cart,
                  label: 'Total Sold',
                  value: calculatedSold,
                  color: Colors.yellow.shade300,
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white38),
              Expanded(
                child: _monthlyInventoryStat(
                  icon: Icons.delete_outline,
                  label: 'Remaining',
                  value: monthlyTotalRemaining,
                  color: Colors.orange.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prepared: $monthlyTotalPrepared | Sold: $calculatedSold | Remaining: $monthlyTotalRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyInventoryStat({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyFinancialSummary() {
    final profitMargin = monthlyTotalRevenue > 0
        ? (monthlyTotalProfit / monthlyTotalRevenue * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Colors.purple, size: 24),
              SizedBox(width: 8),
              Text(
                'Monthly Financial Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cumulative financial performance for the month',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 24),
          _financialRow('💰 Total Revenue', monthlyTotalRevenue, Colors.green.shade700),
          const SizedBox(height: 12),
          _financialRow('📈 Total Profit', monthlyTotalProfit, Colors.blue.shade700),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 Profit Margin',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '${profitMargin.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: profitMargin >= 30
                      ? Colors.green.shade700
                      : profitMargin >= 20
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.purple.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data from ${monthlyDaysWorked} working days this month',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15),
        ),
        Text(
          'Rs: ${value.toString()}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyTrendCard() {
    if (weeklyTrend.isEmpty) return const SizedBox.shrink();

    final maxRevenue =
        weeklyTrend.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                '7-Day Trend',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyTrend.map((day) {
                final height = maxRevenue > 0
                    ? (day.revenue / maxRevenue * 140).clamp(5.0, 140.0)
                    : 5.0;
                final isToday =
                    _formatDate(day.date) == _formatDate(selectedDate);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.revenue > 0)
                          Text(
                            'Rs: ${_formatCompact(day.revenue)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: height,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [Colors.amber, Colors.orange]
                                  : [appBarGreen, appBarGreen.withOpacity(0.7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getDayName(day.date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? appBarGreen : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard() {
    if (staffPerformances.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Performance Analysis - Piyumi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...staffPerformances.map((staff) {
            final isGood = staff.achievementPercent >= 80;
            final isAverage = staff.achievementPercent >= 50 && staff.achievementPercent < 80;

            return Column(
              children: [
                // Main Performance Card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isGood
                        ? Colors.green.shade50
                        : isAverage
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isGood
                          ? Colors.green
                          : isAverage
                              ? Colors.orange
                              : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  isGood
                                      ? Icons.emoji_events
                                      : isAverage
                                          ? Icons.trending_up
                                          : Icons.warning,
                                  color: isGood
                                      ? Colors.green
                                      : isAverage
                                          ? Colors.orange
                                          : Colors.red,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    staff.staffName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isGood
                                  ? Colors.green
                                  : isAverage
                                      ? Colors.orange
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${staff.achievementPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Rs: ${staff.targetAmount}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Achieved',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Rs: ${staff.actualAmount}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: appBarGreen,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                staff.shortfall > 0 ? 'Shortfall' : 'Surplus',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Rs: ${staff.shortfall.abs()}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: staff.shortfall > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (staff.achievementPercent / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isGood ? Colors.green : isAverage ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${staff.daysWorked} days worked this month',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Break-Even Goal Card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: staff.breakEvenAchieved
                          ? [Colors.purple.shade50, Colors.deepPurple.shade50]
                          : [Colors.blue.shade50, Colors.indigo.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: staff.breakEvenAchieved ? Colors.deepPurple : Colors.indigo,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            staff.breakEvenAchieved ? Icons.check_circle : Icons.track_changes,
                            color: staff.breakEvenAchieved ? Colors.deepPurple : Colors.indigo,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.breakEvenAchieved ? '🎉 BREAK-EVEN ACHIEVED!' : '🎯 PRIMARY GOAL: BREAK-EVEN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: staff.breakEvenAchieved ? Colors.deepPurple : Colors.indigo,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  softWrap: true,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Food Hut needs Rs. ${staff.breakEvenGoal} to break even',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: staff.breakEvenAchieved ? Colors.deepPurple : Colors.indigo,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${staff.breakEvenPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Break-Even Goal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs. ${staff.breakEvenGoal}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Current Sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs. ${staff.actualAmount}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: staff.breakEvenAchieved ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                staff.breakEvenAchieved ? 'Balance' : 'Remaining',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs. ${(staff.breakEvenGoal - staff.actualAmount).abs()}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: staff.breakEvenAchieved ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (staff.breakEvenPercent / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            staff.breakEvenAchieved ? Colors.green : Colors.indigo,
                          ),
                        ),
                      ),
                      if (!staff.breakEvenAchieved) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Keep going! Reaching break-even unlocks bonus opportunities.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Over-Performance & Bonus Card (only show if break-even achieved)
                if (staff.breakEvenAchieved) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade50, Colors.orange.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔥 OVER-PERFORMANCE!',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sales beyond break-even point',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Over-Performance',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Rs. ${staff.overPerformance}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.grey.shade300,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.card_giftcard,
                                            size: 16,
                                            color: Colors.amber.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Estimated Bonus (5%)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Rs. ${staff.estimatedBonus}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.celebration, size: 20, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Great work! You\'re earning 5% bonus on all sales above break-even.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopItemsCard() {
    final topItems = itemPerformances.take(3).toList();
    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                'Top Performers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final medals = ['🥇', '🥈', '🥉'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    medals[index],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.itemName} (${item.sold})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item.variation,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs: ${item.revenue}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: appBarGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyTopItemsCard() {
    final topItems = monthlyItemPerformances.take(3).toList();
    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                'Top Performers (Monthly)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final medals = ['🥇', '🥈', '🥉'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    medals[index],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.itemName} (${item.sold})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item.variation,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs: ${item.revenue}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: appBarGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyDetailedItemsCard() {
    if (monthlyItemPerformances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No sales data for this month',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list_alt, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                'All Items Performance (Monthly)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Prep',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Sold',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Rem',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Items
          ...monthlyItemPerformances.map((item) {
            final sellThrough = item.prepared > 0
                ? (item.sold / item.prepared * 100)
                : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.variation,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.prepared}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.sold}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: appBarGreen,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.remaining}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.remaining > 0
                                ? Colors.orange.shade700
                                : Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs: ${item.revenue}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'P: Rs: ${item.profit}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Sell-through bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sellThrough / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        sellThrough >= 80
                            ? Colors.green
                            : sellThrough >= 50
                                ? Colors.orange
                                : Colors.red.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sell-through: ${sellThrough.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedItemsCard() {
    if (itemPerformances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No sales data for this date',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list_alt, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                'All Items Performance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Prep',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Sold',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Rem',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Items
          ...itemPerformances.map((item) {
            final sellThrough = item.prepared > 0
                ? (item.sold / item.prepared * 100)
                : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.variation,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.prepared}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.sold}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: appBarGreen,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.remaining}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.remaining > 0
                                ? Colors.orange.shade700
                                : Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs: ${item.revenue}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'P: Rs: ${item.profit}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Sell-through bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sellThrough / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        sellThrough >= 80
                            ? Colors.green
                            : sellThrough >= 50
                                ? Colors.orange
                                : Colors.red.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sell-through: ${sellThrough.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatCompact(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }

  Widget _buildInventoryFlowCard() {
    final freshPrepared = totalPrepared - carryOverFromYesterday;
    final totalAvailable = totalPrepared;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Daily Inventory Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Inventory movement for selected date',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(color: Colors.white54, height: 24),
          _inventoryRow('🔄 Carry-over (Yesterday)', carryOverFromYesterday),
          const SizedBox(height: 8),
          _inventoryRow('➕ Fresh Prepared', freshPrepared),
          const Divider(color: Colors.white54, height: 20),
          _inventoryRow('📦 Total Available', totalAvailable, isBold: true),
          const SizedBox(height: 8),
          _inventoryRow('✅ Sold', totalSold, color: Colors.yellow.shade300),
          const SizedBox(height: 8),
          _inventoryRow('📋 Remaining', totalRemaining,
              color: Colors.orange.shade200),
          const SizedBox(height: 12),
          if (totalRemaining > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$totalRemaining items will carry over to tomorrow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inventoryRow(String label, int value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: isBold ? 16 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: isBold ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard() {
    final profitMargin =
        totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Colors.purple, size: 24),
              SizedBox(width: 8),
              Text(
                'Daily Financial Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Financial performance for selected date',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 24),
          _financialRow('💰 Revenue', totalRevenue, Colors.green.shade700),
          const SizedBox(height: 12),
          _financialRow('📈 Profit', totalProfit, Colors.blue.shade700),
          const SizedBox(height: 12),
          _financialRow('💸 Cost', totalCost, Colors.orange.shade700),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 Profit Margin',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '${profitMargin.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: profitMargin >= 30
                      ? Colors.green.shade700
                      : profitMargin >= 20
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============== MODELS ==============

class ItemPerformance {
  final String itemName;
  final String variation;
  final int price;
  final int cost;
  int prepared;
  int remaining;
  int sold;
  int revenue;
  int profit;

  ItemPerformance({
    required this.itemName,
    required this.variation,
    required this.price,
    required this.cost,
    required this.prepared,
    required this.remaining,
    required this.sold,
    required this.revenue,
    required this.profit,
  });
}

class DailySummary {
  final DateTime date;
  final int sold;
  final int revenue;
  final int profit;

  DailySummary({
    required this.date,
    required this.sold,
    required this.revenue,
    required this.profit,
  });
}

class StaffPerformance {
  final String staffName;
  final int targetAmount;
  final int actualAmount;
  final int daysWorked;
  final double achievementPercent;
  final int shortfall;

  // Break-even tracking
  final int breakEvenGoal;
  final double breakEvenPercent;
  final bool breakEvenAchieved;
  final int overPerformance;
  final int estimatedBonus;

  StaffPerformance({
    required this.staffName,
    required this.targetAmount,
    required this.actualAmount,
    required this.daysWorked,
    required this.achievementPercent,
    required this.shortfall,
    required this.breakEvenGoal,
    required this.breakEvenPercent,
    required this.breakEvenAchieved,
    required this.overPerformance,
    required this.estimatedBonus,
  });
}

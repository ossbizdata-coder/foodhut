import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../services/api_services.dart';

class ItemDetailScreen extends StatefulWidget {
  final String title;
  final List<SalesResponseModel> items;
  final Color color;
  final bool allowEdit;
  final DateTime? selectedDate;

  const ItemDetailScreen({
    super.key,
    required this.title,
    required this.items,
    required this.color,
    this.allowEdit = true,
    this.selectedDate,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late List<SalesResponseModel> _items;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  bool get _isToday {
    final today = DateTime.now();
    final selectedDate = widget.selectedDate ?? today;
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  bool get _canEdit => widget.allowEdit && _isToday;

  Future<void> _showEditDialog(ItemGroup item, List<SalesResponseModel> salesForItem) async {
    final controller = TextEditingController(text: item.quantity.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: widget.color),
            const SizedBox(width: 8),
            const Text('Edit Quantity'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.variation.isNotEmpty && item.variation != 'Standard')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.variation,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter new quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.color,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(Icons.numbers, color: widget.color),
              ),
              onSubmitted: (value) {
                final qty = int.tryParse(value);
                if (qty != null && qty >= 0) {
                  Navigator.pop(context, qty);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${item.quantity} @ Rs:${item.price} each',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          if (item.quantity > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final qty = int.tryParse(controller.text);
              if (qty != null && qty >= 0) {
                Navigator.pop(context, qty);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != item.quantity) {
      await _updateQuantity(item, salesForItem, result);
    }
  }

  Future<void> _updateQuantity(ItemGroup item, List<SalesResponseModel> salesForItem, int newQuantity) async {
    if (salesForItem.isEmpty) return;

    setState(() => _isLoading = true);

    try {

      if (newQuantity == 0) {
        // Delete all sales records for this item
        bool allDeleted = true;
        for (var sale in salesForItem) {
          final success = await ApiService.deleteSale(sale.saleId);
          if (!success) {
            allDeleted = false;
          }
        }

        if (allDeleted) {
          setState(() {
            _items.removeWhere((s) =>
              s.itemName == item.itemName && s.variation == item.variation);
            _hasChanges = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.itemName} deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete some records'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Update the first sale record with the new quantity
        // This assumes all records for the same item should be consolidated
        final mainSale = salesForItem.first;
        final actionType = mainSale.actionType == SaleActionType.PREPARED
            ? 'PREPARED'
            : mainSale.actionType == SaleActionType.REMAINING
                ? 'REMAINING'
                : 'PREPARED';

        final success = await ApiService.updateSaleQuantity(
          saleId: mainSale.saleId,
          newQuantity: newQuantity,
          actionType: actionType,
        );

        if (success) {
          // Update local state - replace all sales for this item with a single updated one
          setState(() {
            _items.removeWhere((s) =>
              s.itemName == item.itemName && s.variation == item.variation);

            _items.add(SalesResponseModel(
              saleId: mainSale.saleId,
              itemName: mainSale.itemName,
              variation: mainSale.variation,
              price: mainSale.price,
              cost: mainSale.cost,
              quantity: newQuantity,
              actionType: mainSale.actionType,
              transactionTime: mainSale.transactionTime,
              recordedBy: mainSale.recordedBy,
            ));
            _hasChanges = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.itemName} updated to $newQuantity'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update quantity'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group items by item name and variation
    final Map<String, ItemGroup> grouped = {};
    final Map<String, List<SalesResponseModel>> salesByKey = {};

    for (var item in _items) {
      final key = '${item.itemName}|${item.variation}';

      if (!grouped.containsKey(key)) {
        grouped[key] = ItemGroup(
          itemName: item.itemName,
          variation: item.variation,
          price: item.price,
          quantity: 0,
        );
        salesByKey[key] = [];
      }

      grouped[key]!.quantity += item.quantity;
      salesByKey[key]!.add(item);
    }

    final itemList = grouped.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    final totalQty = itemList.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalAmount = itemList.fold<int>(0, (sum, item) => sum + (item.quantity * item.price));

    const green = Color(0xFF21C36F);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Return true to indicate changes were made
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: AppBar(
          backgroundColor: green,
          title: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Summary Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryItem('Total Items', '$totalQty'),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _summaryItem('Total Amount', 'Rs: $totalAmount'),
                        ],
                      ),
                      if (_canEdit) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Tap item to edit quantity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Item List
                Expanded(
                  child: itemList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No items found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: itemList.length,
                          itemBuilder: (context, index) {
                            final item = itemList[index];
                            final key = '${item.itemName}|${item.variation}';
                            final salesForItem = salesByKey[key] ?? [];
                            final amount = item.quantity * item.price;

                            return GestureDetector(
                              onTap: _canEdit
                                  ? () => _showEditDialog(item, salesForItem)
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: _canEdit
                                      ? Border.all(
                                          color: widget.color.withOpacity(0.3),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    // Circle with item number
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: widget.color.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: widget.color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Item details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.itemName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: widget.color.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Qty: ${item.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: widget.color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '@Rs:${item.price}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Amount and edit icon
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Rs:$amount',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: widget.color,
                                          ),
                                        ),
                                        if (_canEdit)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ItemGroup {
  final String itemName;
  final String variation;
  final int price;
  int quantity;

  ItemGroup({
    required this.itemName,
    required this.variation,
    required this.price,
    required this.quantity,
  });
}

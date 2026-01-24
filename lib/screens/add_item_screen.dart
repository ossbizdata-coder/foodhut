import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../services/api_services.dart';

class AddItemScreen extends StatefulWidget {
  final bool isRemaining;
  final DateTime? selectedDate;
  const AddItemScreen({super.key, this.isRemaining = false, this.selectedDate});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  List<MenuItemModel> items = [];
  Map<int, Map<int, int>> itemCounts = {};
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  bool get _isToday {
    final today = DateTime.now();
    final selectedDate = widget.selectedDate ?? today;
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  bool get _canAddItems => _isToday;

  Future<void> _loadItems() async {
    final loaded = await ApiService.getMenuItems();
    // Sort items by name in ascending order
    loaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      items = loaded;
      itemCounts = {
        for (var i in items)
          i.id: {for (var v in i.variations) v.id: 0}
      };
      loading = false;
    });
  }

  bool _hasSelection(int itemId) =>
      itemCounts[itemId]!.values.any((q) => q > 0);

  Future<void> _showQuantityDialog(int itemId, int variationId, String variationName) async {
    final controller = TextEditingController(
      text: itemCounts[itemId]![variationId].toString(),
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variationName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF21C36F),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                final qty = int.tryParse(value) ?? 0;
                setState(() {
                  itemCounts[itemId]![variationId] = qty < 0 ? 0 : qty;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21C36F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              setState(() {
                itemCounts[itemId]![variationId] = qty < 0 ? 0 : qty;
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(int itemId) async {
    if (saving) return;
    setState(() => saving = true);

    try {
      for (final e in itemCounts[itemId]!.entries) {
        if (e.value > 0) {
          await ApiService.addSale(
            variationId: e.key,
            preparedQty: widget.isRemaining ? 0 : e.value,
            remainingQty: widget.isRemaining ? e.value : 0,
            actionType: widget.isRemaining ? 'REMAINING' : 'PREPARED',
          );
        }
      }

      setState(() {
        itemCounts[itemId]!.updateAll((k, v) => 0);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isRemaining
                ? 'Remaining item added'
                : 'Prepared item added',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String screenTitle =
    widget.isRemaining ? 'Add Remaining Item' : 'Add Prepared Item';

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    const green = Color(0xFF21C36F);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: green,
        title: Text(screenTitle),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: !_hasSelection(item.id) || saving || !_canAddItems
                    ? null
                    : () => _addItem(item.id),
                child: saving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Add'),
              ),
              children: item.variations.map((v) {
                final count = itemCounts[item.id]![v.id]!;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _CircleIcon(
                        icon: Icons.remove,
                        onTap: count > 0 && _canAddItems
                            ? () => setState(() {
                          itemCounts[item.id]![v.id] = count - 1;
                        })
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _canAddItems
                              ? () => _showQuantityDialog(item.id, v.id, '${v.variation} • Rs. ${v.price}')
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFFCF5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF9EE6C3)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${v.variation} • Rs. ${v.price}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Color(0xFF21C36F),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CircleIcon(
                        icon: Icons.add,
                        onTap: _canAddItems
                            ? () => setState(() {
                          itemCounts[item.id]![v.id] = count + 1;
                        })
                            : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

/// SMALL ROUND +/- BUTTON
class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

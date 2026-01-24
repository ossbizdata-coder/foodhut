import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../models/menu_item_model.dart';

class AddNewItemScreen extends StatefulWidget {
  const AddNewItemScreen({super.key});

  @override
  State<AddNewItemScreen> createState() => _AddNewItemScreenState();
}

class _AddNewItemScreenState extends State<AddNewItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  List<_VariationField> _variations = [
    _VariationField(),
  ];

  void _addVariation() {
    setState(() {
      _variations.add(_VariationField());
    });
  }

  void _removeVariation(int index) {
    setState(() {
      if (_variations.length > 1) {
        _variations.removeAt(index);
      }
    });
  }

  void _saveItem() async {
    if (_formKey.currentState!.validate()) {
      final itemName = _itemNameController.text.trim();
      final variations = _variations
          .map((v) => ItemVariationModel(
                id: 0, // id will be ignored by backend
                variation: v.variationController.text.trim(),
                price: int.tryParse(v.priceController.text.trim()) ?? 0,
                cost: int.tryParse(v.costController.text.trim()) ?? 0,
              ))
          .toList();
      try {
        await ApiService.addMenuItem(itemName, variations);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added!')),
        );
        _itemNameController.clear();
        setState(() {
          _variations = [ _VariationField() ];
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF21C36F);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: green,
        title: const Text('Add New Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter item name' : null,
              ),
              const SizedBox(height: 24),
              const Text('Variations', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._variations.asMap().entries.map((entry) {
                final idx = entry.key;
                final field = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: field.variationController,
                          decoration: const InputDecoration(
                            labelText: 'Variation',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter variation' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: field.priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty ? 'Enter price' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: field.costController,
                          decoration: const InputDecoration(
                            labelText: 'Cost',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty ? 'Enter cost' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeVariation(idx),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Variation'),
                  onPressed: _addVariation,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  child: const Text('Save Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariationField {
  final TextEditingController variationController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController costController = TextEditingController();
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_setup_screen.dart';



class MyAddresses extends StatefulWidget {
  const MyAddresses({super.key});

  @override
  State<MyAddresses> createState() => _MyAddressesPageState();
}

class _MyAddressesPageState extends State<MyAddresses> {
  final supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() {
          _addresses = [];
          _isLoading = false;
        });
        return;
      }

      final data = await supabase
          .from('addressDB')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      setState(() {
        _addresses = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load addresses: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    try {
      await supabase
          .from('addressDB')
          .delete()
          .eq('address_id', addressId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted')),
      );

      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete address: $e')),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> addressRow) async {
    final labelController =
        TextEditingController(text: addressRow['label'] ?? '');
    final addressController =
        TextEditingController(text: addressRow['address'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLabel = labelController.text.trim();
              final newAddress = addressController.text.trim();

              if (newLabel.isEmpty || newAddress.isEmpty) return;

              try {
                await supabase
                    .from('addressDB')
                    .update({
                      'label': newLabel,
                      'address': newAddress,
                    })
                    .eq('address_id', addressRow['address_id']);

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address updated')),
                );

                await _loadAddresses();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update address: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddressMenu(Map<String, dynamic> addressRow, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'edit',
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );

    if (selected == 'edit') {
      await _showEditDialog(addressRow);
    } else if (selected == 'delete') {
      await _deleteAddress(addressRow['address_id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        title: const Text(
          'My Addresses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LocationSetupScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Manage Addresses'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6FD4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? const Center(
                  child: Text(
                    'No saved addresses yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: _addresses.length,
                  separatorBuilder: (_,_) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = _addresses[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      title: Text(
                        row['label'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          row['address'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      trailing: GestureDetector(
                        onTapDown: (details) {
                          _showAddressMenu(row, details.globalPosition);
                        },
                        child: const Icon(Icons.more_horiz),
                      ),
                    );
                  },
                ),
    );
  }
}
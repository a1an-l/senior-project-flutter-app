import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class LocationInputPage extends StatefulWidget {
  final String title;
  final String placeholder;

  const LocationInputPage({
    super.key,
    required this.title,
    required this.placeholder,
  });

  @override
  State<LocationInputPage> createState() => _LocationInputPageState();
}
  class _LocationInputPageState extends State<LocationInputPage> {
    late TextEditingController userIDController;
    // late TextEditingController labelController;
    late TextEditingController addressController;

    @override 
    void initState() {
      super.initState();
      //userIDController = TextEditingController();
      //labelController = TextEditingController();
      addressController = TextEditingController();
    }

    @override
    void dispose() {
      //userIDController.dispose();
      //labelController.dispose();
      addressController.dispose();
      super.dispose();
    }
    Future<void> _saveAddress() async {
      final userID = 7; // Placeholder userID, replace with actual user ID later
      final address = addressController.text.trim();
      final label = widget.title;
      
      // Basic non-empty validation
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an address')),
        );
        return;
      }

      // DEBUG:
      //print('Saving address with label: $label and address: $address');

      try {
        // TO DO: Get userID from database and store address with that userID
        

        // Call your Supabase service to save the address
        await SupabaseService().addressSave(
          label: label,
          userID: userID,
          address: address,
        );
        

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved successfully')),
        );
        Navigator.pop(context); // Go back after saving
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving address: $e')),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A6FD4),
                Color(0xFF2196F3),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      onSubmitted: (_) => _saveAddress(),
                      controller: addressController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Use current location
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Icon(Icons.circle_outlined, color: Colors.white70, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Use current location',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Divider(color: Colors.white24),
                ),
              ],
            ),
          ),
        ),
      );
    }
  } 
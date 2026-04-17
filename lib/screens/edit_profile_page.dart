import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/services/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  final int userId;
  final String currentUsername;
  final String currentEmail;

  const EditProfilePage({
    super.key,
    required this.userId,
    required this.currentUsername,
    required this.currentEmail,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _profileService = ProfileService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();


  File? _pickedImageFile;       // newly picked local file
  String? _currentPhotoUrl;    // loaded from Supabase
  bool _isLoading = false;
  bool _isPhotoLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.currentUsername;
    _emailController.text = widget.currentEmail;
    _loadCurrentPhoto();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
Future<void> _onSubmit() async {
  final username = _usernameController.text.trim();
  final email = _emailController.text.trim();

  if (username.isEmpty || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username and email cannot be empty.')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    await _profileService.updateProfile(
      userId: widget.userId,
      username: username,
      email: email,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  } catch (e) {
    debugPrint('update profile error: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  Future<void> _loadCurrentPhoto() async {
    setState(() => _isPhotoLoading = true);
    try {
      final url = await _profileService.getProfilePhotoUrl(widget.userId);
      if (mounted) setState(() => _currentPhotoUrl = url);
    } catch (_) {
      // No photo yet 
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    // Let user choose source
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() {
      _pickedImageFile = File(picked.path);
      _isLoading = true;
    });

    try {
      final url = await _profileService.updateProfilePhoto(
        userId: widget.userId,
        imageFile: _pickedImageFile!,
      );
      setState(() => _currentPhotoUrl = url);
      _showSnack('Profile picture updated!', isError: false);
    } catch (e) {
      _showSnack('Failed to upload photo: $e');
      setState(() => _pickedImageFile = null); // revert preview on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  Future<void> _sendPasswordResetEmail() async {
  final email = _emailController.text.trim();

  if (email.isEmpty) {
    _showSnack('Email cannot be empty.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    await _profileService.sendPasswordResetEmail(email);
    _showSnack('Password reset email sent. Check your inbox.', isError: false);
  } catch (e) {
    _showSnack('Failed to send reset email: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAvatar() {
    ImageProvider? provider;

    if (_pickedImageFile != null) {
      provider = FileImage(_pickedImageFile!);
    } else if (_currentPhotoUrl != null) {
      provider = NetworkImage(_currentPhotoUrl!);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: Colors.white24,
          backgroundImage: provider,
          child: provider == null
              ? const Icon(Icons.person, size: 52, color: Colors.white)
              : null,
        ),
        GestureDetector(
          onTap: _isLoading ? null : _pickAndUploadPhoto,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt,
                size: 18, color: Color(0xFF1A6FD4)),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A6FD4), Color(0xFF2196F3)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _isPhotoLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : _buildAvatar(),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _pickAndUploadPhoto,
                          icon: const Icon(Icons.edit,
                              size: 14, color: Colors.white70),
                          label: const Text('Change Picture',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                backgroundColor: const Color(0xFF1A6FD4),
                title: const Text('Edit Profile',
                    style: TextStyle(color: Colors.white)),
              ),

              // ── Form body ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),

                      //Reset password button 
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _sendPasswordResetEmail,
                        icon: const Icon(Icons.lock_outline,
                            color: Color(0xFF1A6FD4)),
                        label: const Text('Reset Password',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A6FD4))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A6FD4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Submit ──
                      ElevatedButton(
                        onPressed: _isLoading ? null : _onSubmit,
          
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6FD4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('SUBMIT CHANGES',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Global loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A6FD4)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A6FD4)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1A6FD4), width: 1.5),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'landing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  File? _pickedImageFile;
  String? _currentPhotoUrl;
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
      // no photo yet
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
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
      setState(() => _pickedImageFile = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    final theme = Theme.of(context);

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.cardColor,
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
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.colorScheme.onSurface),
              title: Text(
                'Take a photo',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.colorScheme.onSurface),
              title: Text(
                'Choose from gallery',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
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

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('remember_me');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('Failed to sign out: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final theme = Theme.of(context);

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          'Sign Out',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await _handleSignOut();
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
    final theme = Theme.of(context);
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
          backgroundColor: theme.brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : Colors.white24,
          backgroundImage: provider,
          child: provider == null
              ? Icon(
                  Icons.person,
                  size: 52,
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface
                      : Colors.white,
                )
              : null,
        ),
        GestureDetector(
          onTap: _isLoading ? null : _pickAndUploadPhoto,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: Icon(
              Icons.camera_alt,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: isDark ? theme.cardColor : const Color(0xFF1A6FD4),
                foregroundColor: theme.appBarTheme.foregroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: isDark
                        ? BoxDecoration(
                            color: theme.cardColor,
                          )
                        : const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1A6FD4),
                                Color(0xFF2196F3),
                              ],
                              ),
                            ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            _isPhotoLoading
                                ? CircularProgressIndicator(
                                    color: isDark ? theme.colorScheme.onSurface : Colors.white,
                                  )
                                : _buildAvatar(),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _pickAndUploadPhoto,
                              icon: Icon(
                                Icons.edit,
                                size: 14,
                                color: isDark
                                    ? theme.colorScheme.onSurface.withOpacity(0.8)
                                    : Colors.white70,
                              ),
                              label: Text(
                                'Change Picture',
                                style: TextStyle(
                                  color: isDark
                                      ? theme.colorScheme.onSurface.withOpacity(0.8)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.appBarTheme.foregroundColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: theme.appBarTheme.foregroundColor,
                  ),
                ),
              ),
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
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _sendPasswordResetEmail,
                        icon: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          'Reset Password',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SUBMIT CHANGES',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _confirmSignOut,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
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
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
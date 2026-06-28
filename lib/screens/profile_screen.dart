import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/jobs_provider.dart';
import '../providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedDistrict;
  String? _selectedQualification;
  bool _isEditing = false;
  bool _isSaving = false;

  // Notification preferences
  bool _newJobAlerts = true;
  bool _lastDateReminders = true;
  bool _resultAlerts = true;
  bool _isTeluguLanguage = true;

  String _appVersion = '';

  static const List<String> _districts = [
    'Adilabad',
    'Bhadradri Kothagudem',
    'Hanumakonda',
    'Hyderabad',
    'Jagtial',
    'Jangaon',
    'Jayashankar Bhupalpally',
    'Jogulamba Gadwal',
    'Kamareddy',
    'Karimnagar',
    'Khammam',
    'Kumuram Bheem Asifabad',
    'Mahabubabad',
    'Mahbubnagar',
    'Mancherial',
    'Medak',
    'Medchal-Malkajgiri',
    'Mulugu',
    'Nagarkurnool',
    'Nalgonda',
    'Narayanpet',
    'Nirmal',
    'Nizamabad',
    'Peddapalli',
    'Rajanna Sircilla',
    'Rangareddy',
    'Sangareddy',
    'Siddipet',
    'Suryapet',
    'Vikarabad',
    'Wanaparthy',
    'Warangal',
    'Yadadri Bhuvanagiri',
  ];

  static const List<String> _qualifications = [
    '10th Pass',
    'Intermediate (12th)',
    'Degree (B.A / B.Sc / B.Com)',
    'Post Graduation (M.A / M.Sc / M.Com)',
    'B.E / B.Tech',
    'Diploma',
    'M.E / M.Tech',
    'MBA / MCA',
    'Ph.D',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppVersion();
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final langProvider = context.read<LanguageProvider>();
    _nameController.text = authProvider.userName;
    _selectedDistrict = authProvider.userDistrict;
    _selectedQualification = authProvider.userQualification;
    _newJobAlerts = authProvider.notifNewJobs;
    _lastDateReminders = authProvider.notifLastDate;
    _resultAlerts = authProvider.notifResults;
    _isTeluguLanguage = authProvider.isTeluguLanguage;
    _isTeluguLanguage = langProvider.isTelugu;
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (_) {
      setState(() => _appVersion = '1.0.0');
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.updateProfile(
        name: _nameController.text.trim(),
        district: _selectedDistrict,
        qualification: _selectedQualification,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateNotificationPreference(String key, bool value) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.updateNotificationPreference(key, value);
  }

  Future<void> _toggleLanguage(bool isTeluguSelected) async {
    setState(() => _isTeluguLanguage = isTeluguSelected);
    // Sync with LanguageProvider for app-wide translation
    context.read<LanguageProvider>().setLanguage(isTeluguSelected ? 'te' : 'en');
    final authProvider = context.read<AuthProvider>();
    await authProvider.setLanguage(isTeluguSelected ? 'te' : 'en');
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _shareApp() {
    Share.share(
      'Download TS Jobs App - Get Telangana Government Job Alerts!\nhttps://play.google.com/store/apps/details?id=com.tsjobs.app',
      subject: 'TS Jobs App',
    );
  }

  Future<void> _rateApp() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.tsjobs.app';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1A1A2E),
          ),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE91E63),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFFE91E63).withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            authProvider.userName.isNotEmpty
                                ? authProvider.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE91E63),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        authProvider.userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authProvider.phoneNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Edit Profile Section
            if (_isEditing) _buildEditSection(),

            // Notification Preferences
            _buildSectionContainer(
              title: 'Notification Preferences',
              icon: Icons.notifications_outlined,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'New Job Alerts',
                    subtitle: 'Get notified about new job postings',
                    value: _newJobAlerts,
                    onChanged: (value) {
                      setState(() => _newJobAlerts = value);
                      _updateNotificationPreference('new_jobs', value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildSwitchTile(
                    title: 'Last Date Reminders',
                    subtitle: 'Remind before application deadline',
                    value: _lastDateReminders,
                    onChanged: (value) {
                      setState(() => _lastDateReminders = value);
                      _updateNotificationPreference('last_date', value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildSwitchTile(
                    title: 'Result Alerts',
                    subtitle: 'Notify when results are announced',
                    value: _resultAlerts,
                    onChanged: (value) {
                      setState(() => _resultAlerts = value);
                      _updateNotificationPreference('results', value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Language Switch
            _buildSectionContainer(
              title: 'Language / భాష',
              icon: Icons.language_rounded,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleLanguage(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isTeluguLanguage
                              ? const Color(0xFFE91E63).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isTeluguLanguage
                                ? const Color(0xFFE91E63)
                                : Colors.grey.shade200,
                            width: _isTeluguLanguage ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'తెలుగు',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _isTeluguLanguage
                                  ? const Color(0xFFE91E63)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleLanguage(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isTeluguLanguage
                              ? const Color(0xFFE91E63).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isTeluguLanguage
                                ? const Color(0xFFE91E63)
                                : Colors.grey.shade200,
                            width: !_isTeluguLanguage ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'English',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: !_isTeluguLanguage
                                  ? const Color(0xFFE91E63)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Downloaded PDFs
            _buildSectionContainer(
              title: 'Downloaded PDFs',
              icon: Icons.download_done_rounded,
              child: Consumer<JobsProvider>(
                builder: (context, jobsProvider, _) {
                  final downloadedPdfs = jobsProvider.downloadedPdfs;

                  if (downloadedPdfs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No downloaded PDFs yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: downloadedPdfs.take(5).map((pdf) {
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          pdf.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          pdf.downloadDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                        onTap: () {
                          jobsProvider.openPdf(pdf.filePath);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // App Info & Actions
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.share_outlined,
                      color: Color(0xFF1A1A2E),
                    ),
                    title: const Text(
                      'Share App',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                    onTap: _shareApp,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.star_outline_rounded,
                      color: Color(0xFF1A1A2E),
                    ),
                    title: const Text(
                      'Rate Us',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                    onTap: _rateApp,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: Colors.grey.shade600,
                    ),
                    title: const Text(
                      'App Version',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      _appVersion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _isEditing = false);
                  _loadUserData();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          const Text(
            'Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE91E63),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // District
          const Text(
            'District',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedDistrict,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select district',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: _districts.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedDistrict = value);
            },
            menuMaxHeight: 250,
          ),
          const SizedBox(height: 16),

          // Qualification
          const Text(
            'Qualification',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedQualification,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select qualification',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: _qualifications.map((q) {
              return DropdownMenuItem(
                value: q,
                child: Text(q, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedQualification = value);
            },
            menuMaxHeight: 250,
          ),
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFFE91E63)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      activeColor: const Color(0xFFE91E63),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}

// Downloaded PDF Model
class DownloadedPdf {
  final String fileName;
  final String filePath;
  final String downloadDate;

  DownloadedPdf({
    required this.fileName,
    required this.filePath,
    required this.downloadDate,
  });
}

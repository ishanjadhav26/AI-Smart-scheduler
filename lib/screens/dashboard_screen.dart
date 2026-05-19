import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../widgets/meeting_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Add Event Form State Controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _agendaController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _launchExternal(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final activeTab = provider.activeTab;

    return Scaffold(
      backgroundColor: const Color(0xFF030008), // deep space black
      body: Row(
        children: [
          // ─── LEFT SIDEBAR NAVIGATION ──────────────────────────────
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: Color(0xFF07040C), // Sidebar dark purple tint
              border: Border(
                right: BorderSide(
                  color: Color(0xFF1F1235), // thin glowing border
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Application Brand Logo
                const Row(
                  children: [
                    Icon(Icons.alarm_on_rounded, color: Color(0xFFA78BFA), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'REMINDER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Active Account detail
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, color: Color(0xFFA78BFA), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.user?.email ?? 'Synchronized',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sidebar Tab Buttons
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSidebarItem(
                          icon: Icons.dashboard_rounded,
                          label: 'Overview',
                          isActive: activeTab == 'overview',
                          onTap: () => provider.switchTab('overview'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.history_toggle_off_rounded,
                          label: 'History Log',
                          isActive: activeTab == 'history',
                          onTap: () => provider.switchTab('history'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add Event',
                          isActive: activeTab == 'add-event',
                          onTap: () => provider.switchTab('add-event'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.calendar_today_rounded,
                          label: 'Google Calendar',
                          isActive: false,
                          onTap: () => _launchExternal('https://calendar.google.com'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.email_rounded,
                          label: 'Gmail',
                          isActive: false,
                          onTap: () => _launchExternal('https://mail.google.com'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.mail_outline_rounded,
                          label: 'Outlook',
                          isActive: false,
                          onTap: () => _launchExternal('https://outlook.live.com'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          isActive: activeTab == 'settings',
                          onTap: () => provider.switchTab('settings'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Sign Out
                _buildSidebarItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isActive: false,
                  onTap: () => provider.signOut(),
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),

          // ─── RIGHT CONTENT TAB PANELS ─────────────────────────────
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _buildActiveTabContent(provider, activeTab),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar Button Widget Builder
  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeBg = const Color(0xFFA78BFA).withOpacity(0.08);
    final activeBorder = const Color(0xFFA78BFA).withOpacity(0.2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? activeBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color ?? (isActive ? const Color(0xFFA78BFA) : Colors.grey.shade400),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color ?? (isActive ? Colors.white : Colors.grey.shade300),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Renders correct active tab view
  Widget _buildActiveTabContent(AppProvider provider, String tab) {
    switch (tab) {
      case 'history':
        return _buildHistoryTab(provider);
      case 'add-event':
        return _buildAddEventTab(provider);
      case 'settings':
        return _buildSettingsTab(provider);
      case 'overview':
      default:
        return _buildOverviewTab(provider);
    }
  }

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab(AppProvider provider) {
    final upcoming = provider.upcomingEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Meetings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${upcoming.length} active meeting${upcoming.length != 1 ? 's' : ''} listed',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
            
            // Sync now key action
            ElevatedButton.icon(
              onPressed: provider.isSyncing ? null : () => provider.syncNow(),
              icon: provider.isSyncing 
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(provider.isSyncing ? 'Syncing...' : 'Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA78BFA),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Focus mode banner
        if (provider.focusMode)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA).withOpacity(0.06),
              border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.do_not_disturb_on_rounded, color: Color(0xFFA78BFA), size: 18),
                SizedBox(width: 10),
                Text(
                  '🎯 Focus Mode Enabled — Voice call reminders are currently muted.',
                  style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // Upcoming meetings list scroll
        Expanded(
          child: upcoming.isEmpty
              ? _buildEmptyState(
                  icon: Icons.calendar_today_rounded,
                  title: 'No upcoming meetings scheduled',
                  subtitle: 'You are completely free! Try sync or manually creating an event.',
                )
              : ListView.builder(
                  itemCount: upcoming.length,
                  itemBuilder: (ctx, index) {
                    return MeetingCard(event: upcoming[index]);
                  },
                ),
        ),
      ],
    );
  }

  // 2. HISTORY TAB
  Widget _buildHistoryTab(AppProvider provider) {
    final past = provider.pastEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Completed Meetings Log',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${past.length} past meeting${past.length != 1 ? 's' : ''} logged',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // History logs
        Expanded(
          child: past.isEmpty
              ? _buildEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No past logs',
                  subtitle: 'You have no historical completed meetings on record.',
                )
              : ListView.builder(
                  itemCount: past.length,
                  itemBuilder: (ctx, index) {
                    return HistoryCard(event: past[index]);
                  },
                ),
        ),
      ],
    );
  }

  // 3. ADD EVENT FORM TAB
  Widget _buildAddEventTab(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Manual Event',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Creates a local event stored in UTC and triggers exact speech reminder calculations.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 32),

        Expanded(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F091A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.08)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    _buildLabel('Event Title *'),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      validator: (value) => value == null || value.trim().isEmpty ? '⚠️ Title is required' : null,
                      decoration: _buildInputDecoration('Enter meeting title'),
                    ),
                    const SizedBox(height: 20),

                    // Date & Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Date *'),
                              InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: _buildBoxDecoration(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedDate == null 
                                            ? 'Select Date' 
                                            : DateFormat.yMMMd().format(_selectedDate!),
                                        style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.white, fontSize: 13),
                                      ),
                                      const Icon(Icons.calendar_month, color: Color(0xFFA78BFA), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Time *'),
                              InkWell(
                                onTap: _pickTime,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: _buildBoxDecoration(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime == null 
                                            ? 'Select Time' 
                                            : _selectedTime!.format(context),
                                        style: TextStyle(color: _selectedTime == null ? Colors.grey : Colors.white, fontSize: 13),
                                      ),
                                      const Icon(Icons.access_time, color: Color(0xFFA78BFA), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Link field
                    _buildLabel('Meeting Link (Optional)'),
                    TextFormField(
                      controller: _linkController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildInputDecoration('Paste Zoom, Meet, Teams invite URL'),
                    ),
                    const SizedBox(height: 20),

                    // Agenda field
                    _buildLabel('Agenda (Optional)'),
                    TextFormField(
                      controller: _agendaController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildInputDecoration('Describe details...'),
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedDate == null || _selectedTime == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('⚠️ Date and Time are required')),
                                );
                                return;
                              }

                              final startDateTime = DateTime(
                                _selectedDate!.year,
                                _selectedDate!.month,
                                _selectedDate!.day,
                                _selectedTime!.hour,
                                _selectedTime!.minute,
                              );

                              provider.saveManualEvent(
                                title: _titleController.text.trim(),
                                startTime: startDateTime,
                                meetingLink: _linkController.text.trim(),
                                agenda: _agendaController.text.trim(),
                              );

                              _resetForm();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('📅 Event added successfully')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA78BFA),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 4. SETTINGS TAB
  Widget _buildSettingsTab(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings Panel',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage sync profiles, mutes, and background refresh times.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 32),

        Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F091A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Focus Mode Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 Focus Mode',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Mutes voice calls temporarily.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  Switch(
                    value: provider.focusMode,
                    activeColor: const Color(0xFFA78BFA),
                    onChanged: (val) => provider.toggleFocusMode(val),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1F1235), height: 32),

              // Calendar unsync section
              const Text(
                '🔌 Google Connection Status',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Your calendar is fully synced with ${provider.user?.email ?? "primary calendar"}.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0F091A),
                        title: const Text('Unsync Google Calendar', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'Are you sure you want to unsync calendar? This will log you out, delete cached state, and halt reminder engines.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              provider.unsyncCalendar();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Unsync', style: TextStyle(color: Color(0xFFEF4444))),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.08),
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Unsync Calendar Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FORM BUILDERS & UTILS ─────────────────────────────────
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      filled: true,
      fillColor: Colors.black.withOpacity(0.4),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: const Color(0xFFA78BFA).withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFA78BFA)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.12)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFA78BFA),
              onPrimary: Colors.black,
              surface: Color(0xFF0F091A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFA78BFA),
              onPrimary: Colors.black,
              surface: Color(0xFF0F091A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _linkController.clear();
    _agendaController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  // Standard empty state placeholder
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 60),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    _agendaController.dispose();
    super.dispose();
  }
}

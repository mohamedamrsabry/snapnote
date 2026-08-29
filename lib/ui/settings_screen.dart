import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'app_theme_colors.dart';
import 'archived_notes_screen.dart';
import 'permission_request_screen.dart';
import 'view_models/theme_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: pillColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryTextColor(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: primaryTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              Consumer<ThemeViewModel>(
                builder: (context, themeViewModel, child) {
                  return SwitchListTile(
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(color: primaryTextColor(context)),
                    ),
                    value: themeViewModel.isDarkMode,
                    onChanged: themeViewModel.setDarkMode,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Permissions'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _PermissionRow(
                permission: Permission.camera,
                label: 'Camera',
                featureName: 'camera',
              ),
              const _SettingsDivider(),
              _PermissionRow(
                permission: Permission.microphone,
                label: 'Microphone',
                featureName: 'microphone',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Notes'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              ListTile(
                title: Text(
                  'Archived Notes',
                  style: TextStyle(color: primaryTextColor(context)),
                ),
                subtitle: Text(
                  'Deleted notes are kept for 3 days before being removed for good.',
                  style: TextStyle(color: secondaryTextColor(context)),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: secondaryTextColor(context),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ArchivedNotesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: primaryTextColor(context),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: secondaryTextColor(context, 0.15),
    );
  }
}

class _PermissionRow extends StatefulWidget {
  final Permission permission;
  final String label;
  final String featureName;

  const _PermissionRow({
    required this.permission,
    required this.label,
    required this.featureName,
  });

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.permission.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _requestAccess() async {
    await ensurePermission(context, widget.permission, widget.featureName);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status?.isGranted ?? false;
    return ListTile(
      title: Text(
        widget.label,
        style: TextStyle(color: primaryTextColor(context)),
      ),
      subtitle: Text(
        granted ? 'Allowed' : 'Not allowed',
        style: TextStyle(color: secondaryTextColor(context)),
      ),
      trailing: granted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : TextButton(
              onPressed: _requestAccess,
              child: const Text('Enable'),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRequestScreen extends StatefulWidget {
  final Permission permission;
  final String featureName;

  const PermissionRequestScreen({
    super.key,
    required this.permission,
    required this.featureName,
  });

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isPermanentlyDenied = false;

  Future<void> _requestPermission() async {
    final status = await widget.permission.request();

    if (status.isGranted) {
      if (mounted) Navigator.of(context).pop(true);
    } else if (status.isPermanentlyDenied) {
      setState(() => _isPermanentlyDenied = true);
    } else {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isPermanentlyDenied
              ? _buildDeniedContent()
              : _buildRationaleContent(),
        ),
      ),
    );
  }

  Widget _buildRationaleContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 48),
        const SizedBox(height: 16),
        Text(
          'SnapNote needs access to your ${widget.featureName} to use this feature.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _requestPermission,
          child: const Text('Allow Access'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
      ],
    );
  }

  Widget _buildDeniedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: 48),
        const SizedBox(height: 16),
        Text(
          '${widget.featureName[0].toUpperCase()}${widget.featureName.substring(1)} access is off. Enable it in Settings to use this feature.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () async {
            await openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

Future<bool> ensurePermission(
  BuildContext context,
  Permission permission,
  String featureName,
) async {
  final status = await permission.status;
  if (status.isGranted) return true;
  if (!context.mounted) return false;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PermissionRequestScreen(
        permission: permission,
        featureName: featureName,
      ),
    ),
  );
  return result ?? false;
}

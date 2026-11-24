import 'package:flutter/material.dart';
import 'package:darna/services/esp32_service.dart';
import 'package:darna/services/token_storage.dart';
import 'package:darna/features/home/home_screen.dart';

// Initial one-time setup: user enters the setup token shown on the ESP32
// Serial Monitor and chooses a name for this (admin) phone.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final Esp32Service _esp32Service = Esp32Service();
  final TokenStorage _tokenStorage = TokenStorage();

  final _setupTokenController = TextEditingController();
  final _deviceNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _setupTokenController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<bool> _saveDeviceToken(String token, String name) async {
    final saved = await _tokenStorage.saveDevice(token: token, name: name);
    if (!saved && mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the device token securely. Please try again.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return saved;
  }

  Future<void> _setup() async {
    final setupToken = _setupTokenController.text.trim();
    final deviceName = _deviceNameController.text.trim();
    if (setupToken.isEmpty || deviceName.isEmpty) return;

    setState(() => _isLoading = true);

    // 1. First check if it is the initial admin provisioning token
    final (ok, deviceToken, message) = await _esp32Service.setupRegister(
      setupToken: setupToken,
      deviceName: deviceName,
    );

    if (ok && deviceToken.isNotEmpty) {
      if (!await _saveDeviceToken(deviceToken, deviceName)) return;
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    // 2. Otherwise check if this token is an authorized device token shared from an admin
    final (validToken, verifiedName, _, verifyMsg) = await _esp32Service
        .verifyAuthToken(token: setupToken);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (validToken) {
      final nameToSave = deviceName.isNotEmpty ? deviceName : verifiedName;
      if (!await _saveDeviceToken(setupToken, nameToSave)) return;
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.isNotEmpty &&
                  message != 'Setup rejected by the door controller.'
              ? message
              : verifyMsg.isNotEmpty
              ? verifyMsg
              : 'Invalid token or unable to connect to Darna.',
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Initial Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Darna Setup',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the setup token shown on the ESP32 Serial Monitor '
                'and give this phone a name.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _setupTokenController,
                decoration: const InputDecoration(
                  labelText: 'Setup token',
                  border: OutlineInputBorder(),
                  hintText: 'Paste the 64-character token from Serial',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Device name (e.g. Moalla0\'s Phone)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _setup,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register this device'),
              ),
              const SizedBox(height: 16),
              Text(
                'This is one-time setup. After this, use the app normally.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

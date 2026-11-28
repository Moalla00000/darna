import 'package:flutter/material.dart';
import 'package:darna/core/constants.dart';
import 'package:darna/services/esp32_service.dart';
import 'package:darna/services/token_storage.dart';
import 'package:darna/services/session_auth_service.dart';
import 'package:darna/widgets/door_status_chip.dart';
import 'package:darna/widgets/primary_action_button.dart';
import 'package:darna/widgets/pin_entry_dialog.dart';
import 'package:darna/features/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Esp32Service _esp32Service = Esp32Service();
  final TokenStorage _tokenStorage = TokenStorage();

  DoorStatus _status = DoorStatus.ready;
  bool _isLoading = false;
  bool _isShowingPinDialog = false;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await _tokenStorage.getDeviceToken();
    if (!mounted) return;
    setState(() {
      _deviceToken = token;
    });
  }

  Future<void> _handleOpenDoor() async {
    if (_isLoading || _isShowingPinDialog) return;

    final token = _deviceToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No device token registered. Register this phone first.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionAuth = SessionAuthService();
    if (!sessionAuth.isAuthenticated) {
      if (!sessionAuth.isPinConfigured) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PIN configuration error: DOOR_PIN is missing or invalid in .env.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _isShowingPinDialog = true);
      final authenticated = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const PinEntryDialog(),
      );
      if (!mounted) return;
      setState(() => _isShowingPinDialog = false);

      if (authenticated != true) {
        return;
      }
    }

    setState(() {
      _status = DoorStatus.opening;
      _isLoading = true;
    });

    final (success, message) = await _esp32Service.openDoor(token: token);

    if (!mounted) return;

    if (success) {
      // Keep "Opening Door..." and loading state active while the physical servo is moving
      await Future.delayed(AppConstants.doorOperationDuration);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _status = DoorStatus.opened;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Reset back to ready after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _status == DoorStatus.opened) {
          setState(() {
            _status = DoorStatus.ready;
          });
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _status = DoorStatus.error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Reset back to ready after 3 seconds on error
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _status == DoorStatus.error) {
          setState(() {
            _status = DoorStatus.ready;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Darna',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            size: 80,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Front Door',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to unlock',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        DoorStatusChip(status: _status),
                        const SizedBox(height: 48),
                        PrimaryActionButton(
                          isLoading: _isLoading,
                          onPressed: _handleOpenDoor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _deviceToken == null || _deviceToken!.isEmpty
                    ? 'Not registered'
                    : 'Token-authenticated',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _deviceToken == null || _deviceToken!.isEmpty
                      ? Colors.orange
                      : Colors.green.shade600,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

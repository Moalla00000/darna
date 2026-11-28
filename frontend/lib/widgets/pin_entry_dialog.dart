import 'dart:math';
import 'package:flutter/material.dart';
import 'package:darna/services/session_auth_service.dart';

/// Clean and modern PIN entry dialog matching Darna's Material 3 theme.
///
/// Features 4 masked indicator dots, custom numeric keypad (0-9 + backspace),
/// auto-submission upon 4th digit, and clear error feedback with auto-retry.
class PinEntryDialog extends StatefulWidget {
  const PinEntryDialog({super.key});

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog>
    with SingleTickerProviderStateMixin {
  final SessionAuthService _sessionAuth = SessionAuthService();
  String _enteredPin = '';
  String? _errorMessage;
  bool _isError = false;
  bool _isSubmitting = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isSubmitting || _enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
      _isError = false;
    });

    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onBackspace() {
    if (_isSubmitting || _enteredPin.isEmpty) return;

    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
      _isError = false;
    });
  }

  Future<void> _validatePin() async {
    setState(() => _isSubmitting = true);

    // Fail safe: check if PIN is configured in .env
    if (!_sessionAuth.isPinConfigured) {
      setState(() {
        _isSubmitting = false;
        _isError = true;
        _errorMessage = 'PIN configuration error. Unlocking disabled.';
      });
      _shakeController.forward(from: 0.0);
      return;
    }

    final isValid = _sessionAuth.verifyPin(_enteredPin);

    if (isValid) {
      // Mark session authenticated in runtime memory immediately
      _sessionAuth.markAuthenticated();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      // Incorrect PIN feedback
      setState(() {
        _isError = true;
        _errorMessage = 'Incorrect PIN. Please try again.';
      });

      _shakeController.forward(from: 0.0);

      // Brief delay so user sees all 4 dots turn red, then clear for retry
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        _enteredPin = '';
        _isError = false;
        _isSubmitting = false;
      });
    }
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 58,
      height: 58,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildDigitButton(String digit) {
    final theme = Theme.of(context);
    return _buildKeypadButton(
      onPressed: _isSubmitting ? null : () => _onDigitPressed(digit),
      child: Text(
        digit,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildIndicatorDots() {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = sin(_shakeAnimation.value * 3 * pi) * 10;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _enteredPin.length;
          Color dotColor;
          if (_isError) {
            dotColor = Colors.red.shade600;
          } else if (isFilled) {
            dotColor = colorScheme.primary;
          } else {
            dotColor = colorScheme.outlineVariant;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: isFilled ? 18 : 16,
            height: isFilled ? 18 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? dotColor : Colors.transparent,
              border: Border.all(
                color: dotColor,
                width: isFilled ? 2 : 1.5,
              ),
              boxShadow: isFilled && !_isError
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  'Enter your PIN',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                Text(
                  'Enter your 4-digit PIN to unlock Darna',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // 4 Indicator Dots
                _buildIndicatorDots(),
                const SizedBox(height: 10),

                // Error feedback message
                SizedBox(
                  height: 18,
                  child: Center(
                    child: Text(
                      _errorMessage ?? '',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Numeric Keypad
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDigitButton('1'),
                        _buildDigitButton('2'),
                        _buildDigitButton('3'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDigitButton('4'),
                        _buildDigitButton('5'),
                        _buildDigitButton('6'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDigitButton('7'),
                        _buildDigitButton('8'),
                        _buildDigitButton('9'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel Button
                        _buildKeypadButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                        _buildDigitButton('0'),
                        // Backspace Button
                        _buildKeypadButton(
                          onPressed: _enteredPin.isEmpty || _isSubmitting
                              ? null
                              : _onBackspace,
                          child: Icon(
                            Icons.backspace_outlined,
                            color: _enteredPin.isEmpty
                                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                                : colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

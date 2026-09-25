import 'dart:async';
import 'package:flutter/material.dart';

class AvanceInformativoDialog extends StatefulWidget {
  const AvanceInformativoDialog({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<AvanceInformativoDialog> createState() => _AvanceInformativoDialogState();
}

class _AvanceInformativoDialogState extends State<AvanceInformativoDialog>
    with SingleTickerProviderStateMixin {
  static const _durationSeconds = 5;
  late AnimationController _progressController;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _durationSeconds),
    )..forward();

    _autoDismissTimer = Timer(const Duration(seconds: _durationSeconds), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.campaign, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text(
            'AVANCE INFORMATIVO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Countdown progress bar
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              final remaining = (_durationSeconds * (1 - _progressController.value)).ceil();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0 - _progressController.value,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se cierra en ${remaining}s',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: widget.onDismiss,
          child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

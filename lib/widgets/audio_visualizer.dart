import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Transparent background — works in both light and dark mode
        return SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(24, (index) {
              final frequency = (index + 1) * 0.35;
              final heightMultiplier = widget.isPlaying
                  ? (sin((_controller.value * 2 * pi) + frequency) * 0.5 + 0.5)
                  : 0.15;
              final barHeight = (heightMultiplier * 32).clamp(4.0, 34.0);

              final colorRatio = index / 24.0;
              final barColor = Color.lerp(
                widget.primaryColor,
                widget.secondaryColor,
                colorRatio,
              )!;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 4,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      barColor,
                      widget.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  // Removed shadow to avoid overlapping blurs looking like a background box ("recuadro")
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

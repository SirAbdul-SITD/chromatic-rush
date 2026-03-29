import 'package:flutter/material.dart';
import '../utils/game_constants.dart';

class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final EdgeInsets? padding;
  final bool outlined;

  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = GameColors.neonBlue,
    this.icon,
    this.fontSize = 15,
    this.padding,
    this.outlined = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: widget.outlined
                ? Colors.transparent
                : widget.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.color,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.color, size: widget.fontSize + 4),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final double glowRadius;
  final FontWeight fontWeight;
  final double letterSpacing;

  const GlowText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.color = GameColors.neonBlue,
    this.glowRadius = 12,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        shadows: [
          Shadow(color: color, blurRadius: glowRadius),
          Shadow(color: color.withOpacity(0.5), blurRadius: glowRadius * 2),
        ],
      ),
    );
  }
}

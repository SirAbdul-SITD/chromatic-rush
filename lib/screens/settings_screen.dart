import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/game_constants.dart';
import '../utils/settings_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white70, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      'SETTINGS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.music_note_rounded,
                    label: 'MUSIC',
                    subtitle: 'Background music',
                    value: settings.musicEnabled,
                    color: GameColors.neonPurple,
                    onChanged: (_) => settings.toggleMusic(),
                  ),
                  const SizedBox(height: 14),
                  _SettingsTile(
                    icon: Icons.volume_up_rounded,
                    label: 'SOUND FX',
                    subtitle: 'Game sound effects',
                    value: settings.soundEnabled,
                    color: GameColors.neonBlue,
                    onChanged: (_) => settings.toggleSound(),
                  ),
                  const SizedBox(height: 14),
                  _SettingsTile(
                    icon: Icons.vibration_rounded,
                    label: 'VIBRATION',
                    subtitle: 'Haptic feedback',
                    value: settings.vibrationEnabled,
                    color: GameColors.neonGreen,
                    onChanged: (_) => settings.toggleVibration(),
                  ),

                  const SizedBox(height: 40),

                  // Version info
                  Text(
                    'CHROMATIC RUSH v1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 10,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Match colors. Survive.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.15),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? color.withOpacity(0.4) : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: value ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: value ? color : Colors.white38,
                size: 22,
              ),
            ),

            const SizedBox(width: 16),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value ? Colors.white : Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.35),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: value ? color.withOpacity(0.3) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: value ? color : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: value ? color : Colors.white38,
                      shape: BoxShape.circle,
                      boxShadow: value
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

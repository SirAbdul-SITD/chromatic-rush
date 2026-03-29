import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/game_constants.dart';
import '../utils/game_state.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<int> _scoreHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('score_history') ?? [];
    setState(() {
      _scoreHistory = raw.map(int.parse).toList()
        ..sort((a, b) => b.compareTo(a));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final best = gameState.bestScore;

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
                      'LEADERBOARD',
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

            // Best score trophy card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.15),
                      const Color(0xFFFF8C00).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 40)),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERSONAL BEST',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFD700),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          best.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Milestones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MILESTONES',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMilestoneRow(best, 10, '🌟 Survivor', GameColors.neonGreen),
                  const SizedBox(height: 8),
                  _buildMilestoneRow(best, 25, '⚡ Speed Demon', GameColors.neonBlue),
                  const SizedBox(height: 8),
                  _buildMilestoneRow(best, 50, '🔥 Chromatic Pro', GameColors.orange),
                  const SizedBox(height: 8),
                  _buildMilestoneRow(best, 100, '💎 Neon Legend', GameColors.neonPurple),
                  const SizedBox(height: 8),
                  _buildMilestoneRow(best, 200, '🌌 Galaxy Brain', GameColors.red),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Score history
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'RECENT SCORES',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: GameColors.neonBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : _scoreHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🎮',
                                style: TextStyle(fontSize: 40),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No scores yet.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Play your first game!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _scoreHistory.take(10).length,
                          itemBuilder: (context, i) {
                            final score = _scoreHistory[i];
                            return _ScoreRow(
                              rank: i + 1,
                              score: score,
                              isTop: i == 0,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneRow(int best, int target, String label, Color color) {
    final achieved = best >= target;
    final progress = (best / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achieved ? color.withOpacity(0.4) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: achieved ? Colors.white : Colors.white38,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                achieved ? '✓' : '$best / $target',
                style: TextStyle(
                  fontSize: 11,
                  color: achieved ? color : Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!achieved) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.6)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int rank;
  final int score;
  final bool isTop;

  const _ScoreRow({
    required this.rank,
    required this.score,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = isTop ? const Color(0xFFFFD700) : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                color: rankColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              score.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isTop ? const Color(0xFFFFD700) : Colors.white70,
                letterSpacing: 1,
              ),
            ),
          ),
          if (isTop)
            const Text('🏆', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

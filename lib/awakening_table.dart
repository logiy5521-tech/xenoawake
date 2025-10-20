class AwakeningData {
  final String level;
  final int totalCore;
  final int totalCrystal;
  final double resonanceRate;
  final double resonanceDamage;
  final double shield;
  final double freeze;
  final double attackPercent;

  AwakeningData({
    required this.level,
    required this.totalCore,
    required this.totalCrystal,
    required this.resonanceRate,
    required this.resonanceDamage,
    required this.shield,
    required this.freeze,
    required this.attackPercent,
  });
}

// 覚醒段階ごとのデータ（必要に応じて拡張可）
final List<AwakeningData> awakeningTable = [
  AwakeningData(
    level: "覚醒0",
    totalCore: 0,
    totalCrystal: 0,
    resonanceRate: 0,
    resonanceDamage: 0,
    shield: 0,
    freeze: 0,
    attackPercent: 0,
  ),
  AwakeningData(
    level: "黄1",
    totalCore: 0,
    totalCrystal: 10,
    resonanceRate: 3,
    resonanceDamage: 3,
    shield: 4,
    freeze: 5,
    attackPercent: 4,
  ),
  AwakeningData(
    level: "黄2",
    totalCore: 1,
    totalCrystal: 30,
    resonanceRate: 6,
    resonanceDamage: 6,
    shield: 8,
    freeze: 10,
    attackPercent: 8,
  ),
  // ... 以降省略。元データ分追加
];

final Map<int, int> biscuitCosts = {1: 0, 30: 1000, 60: 5000, 90: 16000};

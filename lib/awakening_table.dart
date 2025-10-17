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
  AwakeningData(
    level: "黄3",
    totalCore: 2,
    totalCrystal: 70,
    resonanceRate: 6,
    resonanceDamage: 6,
    shield: 8,
    freeze: 10,
    attackPercent: 8,
  ),
  AwakeningData(
    level: "黄4",
    totalCore: 4,
    totalCrystal: 130,
    resonanceRate: 9,
    resonanceDamage: 9,
    shield: 12,
    freeze: 15,
    attackPercent: 12,
  ),
  AwakeningData(
    level: "黄5",
    totalCore: 7,
    totalCrystal: 190,
    resonanceRate: 9,
    resonanceDamage: 9,
    shield: 12,
    freeze: 15,
    attackPercent: 12,
  ),
  AwakeningData(
    level: "赤1",
    totalCore: 11,
    totalCrystal: 250,
    resonanceRate: 15,
    resonanceDamage: 15,
    shield: 20,
    freeze: 25,
    attackPercent: 20,
  ),
  AwakeningData(
    level: "赤2",
    totalCore: 17,
    totalCrystal: 310,
    resonanceRate: 15,
    resonanceDamage: 15,
    shield: 20,
    freeze: 25,
    attackPercent: 20,
  ),
  AwakeningData(
    level: "赤3",
    totalCore: 25,
    totalCrystal: 370,
    resonanceRate: 22.5,
    resonanceDamage: 22.5,
    shield: 30,
    freeze: 37.5,
    attackPercent: 30,
  ),
  AwakeningData(
    level: "赤4",
    totalCore: 35,
    totalCrystal: 430,
    resonanceRate: 22.5,
    resonanceDamage: 22.5,
    shield: 30,
    freeze: 37.5,
    attackPercent: 30,
  ),
  AwakeningData(
    level: "赤5",
    totalCore: 50,
    totalCrystal: 490,
    resonanceRate: 30,
    resonanceDamage: 30,
    shield: 40,
    freeze: 50,
    attackPercent: 40,
  ),
];

final Map<int, int> biscuitCosts = {1: 0, 30: 169500, 60: 987000, 90: 2254500};

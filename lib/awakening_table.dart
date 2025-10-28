// awakening_table.dart (ペットレベル追加版)

class AwakeningData {
  final String level;
  final int totalCore;
  final int totalCrystal;
  final double resonanceRate;
  final double resonanceDamage;
  final double shield;
  final double freeze;

  const AwakeningData({
    required this.level,
    required this.totalCore,
    required this.totalCrystal,
    required this.resonanceRate,
    required this.resonanceDamage,
    required this.shield,
    required this.freeze,
  });
}

final List<AwakeningData> awakeningTable = [
  AwakeningData(
    level: "覚醒0",
    totalCore: 0,
    totalCrystal: 0,
    resonanceRate: 0.0,
    resonanceDamage: 0.0,
    shield: 0.0,
    freeze: 0.0,
  ),
  AwakeningData(
    level: "黄1",
    totalCore: 0,
    totalCrystal: 10,
    resonanceRate: 3.0,
    resonanceDamage: 3.0,
    shield: 4.0,
    freeze: 5.0,
  ),
  AwakeningData(
    level: "黄2",
    totalCore: 1,
    totalCrystal: 40,
    resonanceRate: 6.0,
    resonanceDamage: 6.0,
    shield: 8.0,
    freeze: 10.0,
  ),
  AwakeningData(
    level: "黄3",
    totalCore: 2,
    totalCrystal: 70,
    resonanceRate: 9.0,
    resonanceDamage: 9.0,
    shield: 12.0,
    freeze: 15.0,
  ),
  AwakeningData(
    level: "黄4",
    totalCore: 4,
    totalCrystal: 130,
    resonanceRate: 9.0,
    resonanceDamage: 9.0,
    shield: 12.0,
    freeze: 15.0,
  ),
  AwakeningData(
    level: "黄5",
    totalCore: 7,
    totalCrystal: 190,
    resonanceRate: 9.0,
    resonanceDamage: 9.0,
    shield: 12.0,
    freeze: 15.0,
  ),
  AwakeningData(
    level: "赤1",
    totalCore: 11,
    totalCrystal: 250,
    resonanceRate: 15.0,
    resonanceDamage: 15.0,
    shield: 20.0,
    freeze: 25.0,
  ),
  AwakeningData(
    level: "赤2",
    totalCore: 17,
    totalCrystal: 310,
    resonanceRate: 15.0,
    resonanceDamage: 15.0,
    shield: 20.0,
    freeze: 25.0,
  ),
  AwakeningData(
    level: "赤3",
    totalCore: 25,
    totalCrystal: 370,
    resonanceRate: 22.5,
    resonanceDamage: 22.5,
    shield: 30.0,
    freeze: 37.5,
  ),
  AwakeningData(
    level: "赤4",
    totalCore: 35,
    totalCrystal: 430,
    resonanceRate: 22.5,
    resonanceDamage: 22.5,
    shield: 30.0,
    freeze: 37.5,
  ),
  AwakeningData(
    level: "赤5",
    totalCore: 50,
    totalCrystal: 490,
    resonanceRate: 30.0,
    resonanceDamage: 30.0,
    shield: 40.0,
    freeze: 50.0,
  ),
];

// サポートスキル上限が上がるレベル
final List<String> supportSkillUpLevels = ["黄2", "黄4", "赤1", "赤3", "赤5"];

// ペットレベルデータ
class PetLevelData {
  final int level;
  final int totalBiscuit; // 累計ビスケット（個数）
  final int skillSlots; // スキル枠数

  const PetLevelData({required this.level, required this.totalBiscuit, required this.skillSlots});
}

final List<PetLevelData> petLevelTable = [
  PetLevelData(level: 1, totalBiscuit: 0, skillSlots: 1),
  PetLevelData(level: 30, totalBiscuit: 169500, skillSlots: 2),
  PetLevelData(level: 60, totalBiscuit: 987000, skillSlots: 3),
  PetLevelData(level: 90, totalBiscuit: 2254500, skillSlots: 4),
];

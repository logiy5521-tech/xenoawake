import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'awakening_table.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _coreController = TextEditingController(text: "0");
  final TextEditingController _crystalController = TextEditingController(text: "0");
  final TextEditingController _biscuitController = TextEditingController(text: "0");

  AwakeningData? _optimalAwakening;
  int _optimalSupportSlots = 2;
  int _mainPetLevel = 1;
  List<int> _supportPetLevels = [1, 1, 1];
  int _usedCore = 0;
  int _usedCrystal = 0;
  int _usedBiscuit = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();

    _coreController.text = prefs.getString('core') ?? '0';
    _crystalController.text = prefs.getString('crystal') ?? '0';
    _biscuitController.text = prefs.getString('biscuit') ?? '0';

    _calculateOptimalBuild();
  }

  Future<void> _saveInputValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('core', _coreController.text);
    await prefs.setString('crystal', _crystalController.text);
    await prefs.setString('biscuit', _biscuitController.text);
  }

  void _calculateOptimalBuild() {
    if (_ownedCore == 0 && _ownedCrystal == 0 && _ownedBiscuit == 0) {
      _resetToInitialState();
      return;
    }

    var result2 = _calculateBuildForSlots(2);
    var result3 = _calculateBuildForSlots(3);

    if (result3 == null && result2 == null) {
      _resetToInitialState();
      return;
    }

    Map<String, dynamic>? selectedResult;
    if (result3 != null && result2 != null) {
      selectedResult = (result3['totalSkillEffect'] > result2['totalSkillEffect']) ? result3 : result2;
    } else {
      selectedResult = result2 ?? result3;
    }

    if (selectedResult == null) {
      _resetToInitialState();
      return;
    }

    setState(() {
      _optimalSupportSlots = selectedResult!['supportSlots'];
      _optimalAwakening = selectedResult['awakening'];
      _mainPetLevel = selectedResult['mainLevel'];
      _supportPetLevels = selectedResult['supportLevels'];
      _usedCore = selectedResult['usedCore'];
      _usedCrystal = selectedResult['usedCrystal'];
      _usedBiscuit = selectedResult['usedBiscuit'];
    });

    _saveInputValues();
  }

  void _resetToInitialState() {
    setState(() {
      _optimalAwakening = null;
      _optimalSupportSlots = 2;
      _mainPetLevel = 1;
      _supportPetLevels = [1, 1, 1];
      _usedCore = 0;
      _usedCrystal = 0;
      _usedBiscuit = 0;
    });
  }

  Map<String, dynamic>? _calculateBuildForSlots(int supportSlots) {
    int unlockCoresCost = (supportSlots >= 3) ? 14 : 0;
    int unlockCrystalCost = (supportSlots >= 3) ? 380 : 0;
    int unlockBiscuitCost = (supportSlots >= 3) ? biscuitCosts[60]! * 2 : 0;

    if (_ownedCore < unlockCoresCost || _ownedCrystal < unlockCrystalCost || _ownedBiscuit < unlockBiscuitCost) {
      return null;
    }

    int availableCore = _ownedCore - unlockCoresCost;
    int availableCrystal = _ownedCrystal - unlockCrystalCost;
    int availableBiscuit = _ownedBiscuit - unlockBiscuitCost;

    AwakeningData awakening = _findMaxAwakeningLevel(availableCore, availableCrystal);
    List<int> petLevels = _calculateOptimalPetLevels(supportSlots, availableBiscuit);
    petLevels.sort((a, b) => b.compareTo(a));

    int mainLevel = petLevels[0];
    List<int> supportLevels = petLevels.sublist(1, supportSlots + 1);

    double totalSkillEffect = _calculateTotalSkillEffect(awakening, petLevels.take(1 + supportSlots).toList());

    int usedBiscuit = unlockBiscuitCost;
    for (int level in petLevels.take(1 + supportSlots)) {
      usedBiscuit += biscuitCosts[level]!;
    }

    return {
      'supportSlots': supportSlots,
      'awakening': awakening,
      'mainLevel': mainLevel,
      'supportLevels': supportLevels,
      'usedCore': awakening.totalCore + unlockCoresCost,
      'usedCrystal': awakening.totalCrystal + unlockCrystalCost,
      'usedBiscuit': usedBiscuit,
      'totalSkillEffect': totalSkillEffect,
    };
  }

  AwakeningData _findMaxAwakeningLevel(int availableCore, int availableCrystal) {
    AwakeningData result = awakeningTable.first;
    for (var data in awakeningTable) {
      if (data.totalCore <= availableCore && data.totalCrystal <= availableCrystal) {
        result = data;
      } else {
        break;
      }
    }
    return result;
  }

  List<int> _calculateOptimalPetLevels(int supportSlots, int availableBiscuit) {
    int totalPets = 1 + supportSlots;
    List<int> levels = List.filled(totalPets, 1);
    int remainingBiscuit = availableBiscuit;

    for (int i = 0; i < totalPets && remainingBiscuit >= biscuitCosts[30]!; i++) {
      levels[i] = 30;
      remainingBiscuit -= biscuitCosts[30]!;
    }

    for (int i = 0; i < totalPets; i++) {
      if (levels[i] == 30 && remainingBiscuit >= (biscuitCosts[60]! - biscuitCosts[30]!)) {
        levels[i] = 60;
        remainingBiscuit -= (biscuitCosts[60]! - biscuitCosts[30]!);
      }
    }

    for (int i = 0; i < totalPets; i++) {
      if (levels[i] == 60 && remainingBiscuit >= (biscuitCosts[90]! - biscuitCosts[60]!)) {
        levels[i] = 90;
        remainingBiscuit -= (biscuitCosts[90]! - biscuitCosts[60]!);
      }
    }

    // totalPets分だけ返す（余分なデータを含めない）
    return levels.take(totalPets).toList();
  }

  double _calculateTotalSkillEffect(AwakeningData awakening, List<int> levels) {
    int totalSlots1And2 = 0;
    int totalSlots3 = 0;
    int totalSlots4 = 0;

    for (int level in levels) {
      int slots = _getSkillSlots(level);
      if (slots >= 1) totalSlots1And2++;
      if (slots >= 2) totalSlots1And2++;
      if (slots >= 3) totalSlots3++;
      if (slots >= 4) totalSlots4++;
    }

    int maxResonanceRatePets = awakening.resonanceRate > 0 ? ((100 - 10) / awakening.resonanceRate).floor() : 999;
    int resonanceRateCount = totalSlots1And2 ~/ 2;
    int resonanceDamageCount = totalSlots1And2 - resonanceRateCount;

    if (resonanceRateCount > maxResonanceRatePets) {
      resonanceRateCount = maxResonanceRatePets;
      resonanceDamageCount = totalSlots1And2 - resonanceRateCount;
    }

    double totalResonanceRate = (awakening.resonanceRate * resonanceRateCount) + 10;
    double totalResonanceDamage = (awakening.resonanceDamage * resonanceDamageCount) + 10;

    return totalResonanceRate + totalResonanceDamage + awakening.shield * totalSlots3 + awakening.freeze * totalSlots4;
  }

  int _getSkillSlots(int level) {
    if (level >= 90) return 4;
    if (level >= 60) return 3;
    if (level >= 30) return 2;
    return 1;
  }

  int get _ownedCore => int.tryParse(_coreController.text) ?? 0;
  int get _ownedCrystal => int.tryParse(_crystalController.text) ?? 0;
  int get _ownedBiscuit => (int.tryParse(_biscuitController.text) ?? 0) * 1000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'XenoPets覚醒計算',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
            ),
            Text('by Logi@YAMATO', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildResourceInput(),
                const SizedBox(height: 16),
                _buildPetDetailsAndSkills(),
                const SizedBox(height: 16),
                _buildResultDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceInput() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FBFF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '所持リソース',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildNumberField('コア', _coreController, const Color(0xFF6366F1))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNumberField('覚醒クリスタル', _crystalController, const Color(0xFF8B5CF6))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNumberField('ビスケット(K)', _biscuitController, const Color(0xFFEC4899))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetDetailsAndSkills() {
    if (_optimalAwakening == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('リソースを入力してください', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFF9F0)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '最適編成',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                  ),
                  Row(
                    children: [
                      _buildBadge('覚醒: ${_optimalAwakening!.level}', const [Color(0xFFFF6B6B), Color(0xFFEE5A6F)]),
                      const SizedBox(width: 8),
                      _buildBadge('サポート: $_optimalSupportSlots体', const [Color(0xFF4FACFE), Color(0xFF00F2FE)]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPetTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gradientColors[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPetTable() {
    List<int> allLevels = [_mainPetLevel, ..._supportPetLevels.take(_optimalSupportSlots)];
    var skillDistribution = _calculateSkillDistribution(allLevels);

    return Table(
      border: TableBorder.all(color: const Color(0xFFE0E0E0), width: 1, borderRadius: BorderRadius.circular(8)),
      columnWidths: {
        0: const FlexColumnWidth(1.5),
        1: const FlexColumnWidth(1),
        2: const FlexColumnWidth(1.5),
        3: const FlexColumnWidth(1.8),
        4: const FlexColumnWidth(1.5),
        5: const FlexColumnWidth(1.5),
        if (skillDistribution['useAttackPercent']) 6: const FlexColumnWidth(1.5),
      },
      children: [
        _buildTableHeaderRow(skillDistribution['useAttackPercent']),
        ..._buildPetTableRows(allLevels, skillDistribution),
        _buildTotalRow(skillDistribution),
      ],
    );
  }

  Map<String, dynamic> _calculateSkillDistribution(List<int> levels) {
    int totalSlots1And2 = 0;
    int totalSlots3 = 0;
    int totalSlots4 = 0;

    for (int level in levels) {
      int slots = _getSkillSlots(level);
      if (slots >= 1) totalSlots1And2++;
      if (slots >= 2) totalSlots1And2++;
      if (slots >= 3) totalSlots3++;
      if (slots >= 4) totalSlots4++;
    }

    int maxResonanceRatePets = _optimalAwakening!.resonanceRate > 0
        ? ((100 - 10) / _optimalAwakening!.resonanceRate).floor()
        : 999;

    // 奇数の場合は確率を1つ多く
    int resonanceRateCount = (totalSlots1And2 + 1) ~/ 2; // 切り上げ
    int resonanceDamageCount = totalSlots1And2 ~/ 2; // 切り捨て

    if (resonanceRateCount > maxResonanceRatePets) {
      resonanceRateCount = maxResonanceRatePets;
      resonanceDamageCount = totalSlots1And2 - resonanceRateCount;
    }

    bool useAttackPercent = (resonanceRateCount + resonanceDamageCount) < totalSlots1And2;

    return {
      'resonanceRateCount': resonanceRateCount,
      'resonanceDamageCount': resonanceDamageCount,
      'totalSlots3': totalSlots3,
      'totalSlots4': totalSlots4,
      'totalSlots1And2': totalSlots1And2,
      'useAttackPercent': useAttackPercent,
    };
  }

  TableRow _buildTableHeaderRow(bool useAttackPercent) {
    List<Widget> headers = [
      _buildTableHeader('ペット', true),
      _buildTableHeader('LV', true),
      _buildTableHeader('共鳴確率', true),
      _buildTableHeader('共鳴ダメージ', true),
      _buildTableHeader('シールド', true),
      _buildTableHeader('氷結', true),
    ];

    if (useAttackPercent) headers.add(_buildTableHeader('攻撃+(%)', true));

    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
      ),
      children: headers,
    );
  }

  List<TableRow> _buildPetTableRows(List<int> levels, Map<String, dynamic> distribution) {
    List<TableRow> rows = [];
    List<String> labels = ['メイン', 'サポート1', 'サポート2', 'サポート3'];

    double resonanceRate = _optimalAwakening!.resonanceRate;
    double resonanceDamage = _optimalAwakening!.resonanceDamage;
    double shield = _optimalAwakening!.shield;
    double freeze = _optimalAwakening!.freeze;
    double attackPercent = _optimalAwakening!.attackPercent;

    int resonanceRateRemaining = distribution['resonanceRateCount'];
    int resonanceDamageRemaining = distribution['resonanceDamageCount'];

    for (int i = 0; i < levels.length; i++) {
      int slots = _getSkillSlots(levels[i]);
      String skillCol1 = '-';
      String skillCol2 = '-';
      String skill3 = '-';
      String skill4 = '-';

      // スロット1: 確率 or ダメージ or 攻撃+
      if (slots >= 1) {
        if (resonanceRateRemaining > 0) {
          skillCol1 = '${resonanceRate.toStringAsFixed(1)}%';
          resonanceRateRemaining--;
        } else if (resonanceDamageRemaining > 0) {
          skillCol1 = '${resonanceDamage.toStringAsFixed(1)}%';
          resonanceDamageRemaining--;
        } else if (distribution['useAttackPercent']) {
          skillCol1 = '${attackPercent.toStringAsFixed(1)}%';
        }
      }

      // スロット2: ダメージ or 確率 or 攻撃+
      if (slots >= 2) {
        if (resonanceDamageRemaining > 0) {
          skillCol2 = '${resonanceDamage.toStringAsFixed(1)}%';
          resonanceDamageRemaining--;
        } else if (resonanceRateRemaining > 0) {
          skillCol2 = '${resonanceRate.toStringAsFixed(1)}%';
          resonanceRateRemaining--;
        } else if (distribution['useAttackPercent']) {
          skillCol2 = '${attackPercent.toStringAsFixed(1)}%';
        }
      }

      if (slots >= 3) skill3 = '${shield.toStringAsFixed(1)}%';
      if (slots >= 4) skill4 = '${freeze.toStringAsFixed(1)}%';

      List<Widget> cells = [
        _buildTableCell(labels[i], bold: true),
        _buildTableCell('${levels[i]}'),
        _buildTableCell(skillCol1),
        _buildTableCell(skillCol2),
        _buildTableCell(skill3),
        _buildTableCell(skill4),
      ];

      if (distribution['useAttackPercent']) {
        String attackSkill = '-';
        if (skillCol1.contains(attackPercent.toStringAsFixed(1)) ||
            skillCol2.contains(attackPercent.toStringAsFixed(1))) {
          attackSkill = '${attackPercent.toStringAsFixed(1)}%';
        }
        cells.add(_buildTableCell(attackSkill));
      }

      rows.add(TableRow(children: cells));
    }

    return rows;
  }

  TableRow _buildTotalRow(Map<String, dynamic> distribution) {
    double resonanceRate = _optimalAwakening!.resonanceRate;
    double resonanceDamage = _optimalAwakening!.resonanceDamage;
    double shield = _optimalAwakening!.shield;
    double freeze = _optimalAwakening!.freeze;
    double attackPercent = _optimalAwakening!.attackPercent;

    double totalResonanceRate = (resonanceRate * distribution['resonanceRateCount']) + 10;
    double totalResonanceDamage = (resonanceDamage * distribution['resonanceDamageCount']) + 10;
    double totalShield = shield * distribution['totalSlots3'];
    double totalFreeze = freeze * distribution['totalSlots4'];

    int attackCount =
        distribution['totalSlots1And2'] - distribution['resonanceRateCount'] - distribution['resonanceDamageCount'];
    double totalAttackPercent = attackPercent * attackCount;

    List<Widget> cells = [
      _buildTableCell('合計', bold: true),
      _buildTableCell(''),
      _buildTableCell('${totalResonanceRate.toStringAsFixed(1)}%', bold: true, color: const Color(0xFF10B981)),
      _buildTableCell('${totalResonanceDamage.toStringAsFixed(1)}%', bold: true, color: const Color(0xFF10B981)),
      _buildTableCell('${totalShield.toStringAsFixed(1)}%', bold: true, color: const Color(0xFF10B981)),
      _buildTableCell('${totalFreeze.toStringAsFixed(1)}%', bold: true, color: const Color(0xFF10B981)),
    ];

    if (distribution['useAttackPercent']) {
      cells.add(
        _buildTableCell('${totalAttackPercent.toStringAsFixed(1)}%', bold: true, color: const Color(0xFF10B981)),
      );
    }

    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      children: cells,
    );
  }

  Widget _buildResultDisplay() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF0F9FF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'リソース使用状況',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    ),
                    children: [
                      _buildTableHeader('リソース', true),
                      _buildTableHeader('使用', true),
                      _buildTableHeader('残り', true),
                    ],
                  ),
                  _buildResourceTableRow('コア', _usedCore, _ownedCore - _usedCore),
                  _buildResourceTableRow('覚醒クリスタル', _usedCrystal, _ownedCrystal - _usedCrystal),
                  _buildResourceTableRow('ビスケット', _usedBiscuit, _ownedBiscuit - _usedBiscuit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildResourceTableRow(String label, int used, int remaining) {
    return TableRow(
      children: [
        _buildTableCell(label, bold: true),
        _buildTableCell(_formatNumber(used)),
        _buildTableCell(
          _formatNumber(remaining),
          bold: true,
          color: remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text, bool isHeader) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isHeader ? Colors.white : const Color(0xFF2C3E50),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String content, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Center(
        child: Text(
          content,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: color ?? const Color(0xFF34495E),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => _calculateOptimalBuild(),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      // 1000以上は全てK表示、3桁ごとにカンマ
      int thousands = number ~/ 1000;
      String formattedThousands = thousands.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '${formattedThousands}K';
    }
    return number.toString();
  }
}

// resource_calculator.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'awakening_table.dart';
import 'localization.dart';

const String kAppVersion = '1.0.0';
const String kAppCredit = 'Logi@YAMATO';

class ResourceCalculatorScreen extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChange;

  const ResourceCalculatorScreen({super.key, required this.locale, required this.onLocaleChange});

  @override
  State<ResourceCalculatorScreen> createState() => _ResourceCalculatorScreenState();
}

class _ResourceCalculatorScreenState extends State<ResourceCalculatorScreen> {
  final _coreController = TextEditingController();
  final _crystalController = TextEditingController();
  final _biscuitController = TextEditingController();

  bool isSameType = true;
  String selectedMainAwakening = '覚醒0';
  String selectedHelperAwakening = '覚醒0';
  String? resourceWarning;

  CalculationResult? result;

  @override
  void initState() {
    super.initState();
    _coreController.addListener(_autoCalculate);
    _crystalController.addListener(_autoCalculate);
    _biscuitController.addListener(_autoCalculate);
    _loadSavedValues();
  }

  @override
  void dispose() {
    _coreController.removeListener(_autoCalculate);
    _crystalController.removeListener(_autoCalculate);
    _biscuitController.removeListener(_autoCalculate);
    _coreController.dispose();
    _crystalController.dispose();
    _biscuitController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _coreController.text = prefs.getString('res_core') ?? '';
      _crystalController.text = prefs.getString('res_crystal') ?? '';
      _biscuitController.text = prefs.getString('res_biscuit') ?? '';
      isSameType = prefs.getBool('res_isSameType') ?? true;
      selectedMainAwakening = prefs.getString('res_mainAwakening') ?? '覚醒0';
      selectedHelperAwakening = prefs.getString('res_helperAwakening') ?? '覚醒0';
    });
    if (_coreController.text.isNotEmpty && _crystalController.text.isNotEmpty && _biscuitController.text.isNotEmpty) {
      _autoCalculate();
    }
  }

  Future<void> _saveValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('res_core', _coreController.text);
    await prefs.setString('res_crystal', _crystalController.text);
    await prefs.setString('res_biscuit', _biscuitController.text);
    await prefs.setBool('res_isSameType', isSameType);
    await prefs.setString('res_mainAwakening', selectedMainAwakening);
    await prefs.setString('res_helperAwakening', selectedHelperAwakening);
  }

  void _autoCalculate() {
    final coreText = _coreController.text;
    final crystalText = _crystalController.text;
    final biscuitText = _biscuitController.text;

    if (coreText.isEmpty || crystalText.isEmpty || biscuitText.isEmpty) {
      setState(() {
        result = null;
        resourceWarning = null;
      });
      return;
    }

    final core = int.tryParse(coreText) ?? 0;
    final crystal = int.tryParse(crystalText) ?? 0;
    final biscuit = (int.tryParse(biscuitText) ?? 0) * 1000;

    _calculate(core, crystal, biscuit);
    _saveValues();
  }

  void _calculate(int core, int crystal, int biscuit) {
    resourceWarning = null;

    if (isSameType) {
      _calculateSameType(core, crystal, biscuit);
    } else {
      _calculateDifferentType(core, crystal, biscuit);
    }
  }

  void _calculateSameType(int core, int crystal, int biscuit) {
    int bestAwk = 0;
    int bestHelperCount = 2;
    int bestMainLevel = 1;
    List<int> bestHelperLevels = [1, 1, 1];
    int bestSkillSlots = 0;
    double bestScore = 0.0;
    int maxHelpers = core >= 21 ? 3 : 2;

    for (int helpers = 2; helpers <= maxHelpers; helpers++) {
      for (int awk = 0; awk < awakeningTable.length; awk++) {
        final data = awakeningTable[awk];

        if (data.totalCore > core || data.totalCrystal > crystal) continue;
        if (helpers == 3 && data.totalCore < 21) {
          int dummyCore = 21 - data.totalCore;
          if (data.totalCore + dummyCore > core) continue;
        }

        var levelOpt = _optimizePetLevels(biscuit, helpers);
        double score = (levelOpt['totalSlots'] * 1000 + awk * 10 + helpers * 0.1).toDouble();

        if (score > bestScore) {
          bestScore = score;
          bestAwk = awk;
          bestHelperCount = helpers;
          bestMainLevel = levelOpt['mainLevel'];
          bestHelperLevels = List<int>.from(levelOpt['helperLevels']);
          bestSkillSlots = levelOpt['totalSlots'];
        }
      }
    }

    final data = awakeningTable[bestAwk];

    setState(() {
      result = CalculationResult(
        mainAwakening: data.level,
        helperAwakening: data.level,
        helperCount: bestHelperCount,
        mainLevel: bestMainLevel,
        helperLevels: bestHelperLevels,
        totalSkillSlots: bestSkillSlots,
        usedCore: data.totalCore,
        usedCrystal: data.totalCrystal,
        usedBiscuit: _getTotalBiscuitUsed(bestMainLevel, bestHelperLevels, bestHelperCount),
        availableCore: core,
        availableCrystal: crystal,
        availableBiscuit: biscuit,
      );
    });
  }

  void _calculateDifferentType(int core, int crystal, int biscuit) {
    final mainData = awakeningTable.firstWhere((d) => d.level == selectedMainAwakening);
    final helperData = awakeningTable.firstWhere((d) => d.level == selectedHelperAwakening);

    int totalCoreNeeded = mainData.totalCore + helperData.totalCore;
    int totalCrystalNeeded = mainData.totalCrystal + helperData.totalCrystal;

    if (totalCoreNeeded > core || totalCrystalNeeded > crystal) {
      setState(() {
        resourceWarning = 'リソースが不足しています（必要: コア$totalCoreNeeded, クリスタル$totalCrystalNeeded）';
        result = null;
      });
      return;
    }

    int maxHelpers = totalCoreNeeded >= 21 ? 3 : 2;

    if (maxHelpers == 3 && totalCoreNeeded < 21) {
      int dummyCore = 21 - totalCoreNeeded;
      if (totalCoreNeeded + dummyCore > core) {
        maxHelpers = 2;
      }
    }

    int bestHelperCount = maxHelpers;
    var levelOpt = _optimizePetLevels(biscuit, bestHelperCount);

    setState(() {
      result = CalculationResult(
        mainAwakening: selectedMainAwakening,
        helperAwakening: selectedHelperAwakening,
        helperCount: bestHelperCount,
        mainLevel: levelOpt['mainLevel'],
        helperLevels: List<int>.from(levelOpt['helperLevels']),
        totalSkillSlots: levelOpt['totalSlots'],
        usedCore: totalCoreNeeded,
        usedCrystal: totalCrystalNeeded,
        usedBiscuit: _getTotalBiscuitUsed(levelOpt['mainLevel'], levelOpt['helperLevels'], bestHelperCount),
        availableCore: core,
        availableCrystal: crystal,
        availableBiscuit: biscuit,
      );
    });
  }

  int _getTotalBiscuitUsed(int mainLevel, List<int> helperLevels, int helperCount) {
    int total = _getBiscuit(mainLevel);
    for (int i = 0; i < helperCount; i++) {
      total += _getBiscuit(helperLevels[i]);
    }
    return total;
  }

  Map<String, dynamic> _optimizePetLevels(int totalBiscuit, int helperCount) {
    List<int> levels = [1, 30, 60, 90];
    List<Map<String, int>> pets = [];

    pets.add({'level': 1, 'slots': 1});
    for (int i = 0; i < helperCount; i++) {
      pets.add({'level': 1, 'slots': 1});
    }

    while (true) {
      int bestPet = -1;
      int bestNextLevel = -1;
      int bestGain = 0;
      int bestCost = 999999999;

      for (int i = 0; i < pets.length; i++) {
        int current = pets[i]['level'] as int;
        int idx = levels.indexOf(current);
        if (idx >= levels.length - 1) continue;

        int next = levels[idx + 1];
        int gain = _getSkillSlots(next) - (pets[i]['slots'] as int);
        int cost = _getBiscuit(next) - _getBiscuit(current);

        if (cost > totalBiscuit) continue;

        if (gain > bestGain || (gain == bestGain && cost < bestCost)) {
          bestPet = i;
          bestNextLevel = next;
          bestGain = gain;
          bestCost = cost;
        }
      }

      if (bestPet == -1) break;

      pets[bestPet]['level'] = bestNextLevel;
      pets[bestPet]['slots'] = _getSkillSlots(bestNextLevel);
      totalBiscuit -= bestCost;
    }

    return {
      'mainLevel': pets[0]['level'],
      'helperLevels': <int>[
        if (helperCount >= 1) pets[1]['level']! else 1,
        if (helperCount >= 2) pets[2]['level']! else 1,
        if (helperCount >= 3) pets[3]['level']! else 1,
      ],
      'totalSlots': pets.fold(0, (sum, p) => sum + (p['slots'] as int)),
    };
  }

  int _getBiscuit(int level) {
    for (var data in petLevelTable) {
      if (data.level == level) return data.totalBiscuit;
    }
    return 0;
  }

  int _getSkillSlots(int level) {
    for (var data in petLevelTable) {
      if (data.level == level) return data.skillSlots;
    }
    return 1;
  }

  String _formatPercentage(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}%';
    } else {
      return '${value.toStringAsFixed(1)}%';
    }
  }

  List<List<String>> _calculateOptimalSkillAllocation(
    List<int> petSlots,
    AwakeningData mainData,
    AwakeningData helperData,
    int helperCount,
  ) {
    List<List<String>> allocation = [];
    for (int i = 0; i < 1 + helperCount; i++) {
      allocation.add([]);
    }

    // ステップ1: 共鳴確率を100%まで配分（ヘルパーから優先）
    double currentResonanceRate = 10.0;

    // ヘルパーから順に共鳴確率を割り当て
    for (int i = 1; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i]) {
        double value = helperData.resonanceRate;
        if (currentResonanceRate + value <= 100.0) {
          allocation[i].add('共鳴確率');
          currentResonanceRate += value;
        }
      }
    }

    // まだ100%に達していない場合、メインにも割り当て
    if (currentResonanceRate < 100.0 && allocation[0].length < petSlots[0]) {
      double value = mainData.resonanceRate;
      if (currentResonanceRate + value <= 100.0) {
        allocation[0].add('共鳴確率');
        currentResonanceRate += value;
      }
    }

    // 共鳴確率が100%に達した後の枠は「自由枠」に
    for (int i = 0; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i]) {
        double value = (i == 0) ? mainData.resonanceRate : helperData.resonanceRate;
        // 共鳴確率を既に持っていない場合のみチェック
        if (!allocation[i].contains('共鳴確率')) {
          if (currentResonanceRate + value > 100.0) {
            allocation[i].add('自由枠');
          }
        }
      }
    }

    // ステップ2: 共鳴ダメージを全ペット最大化
    for (int i = 0; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i] && !allocation[i].contains('共鳴ダメージ')) {
        allocation[i].add('共鳴ダメージ');
      }
    }

    // ステップ3: 残り枠を氷結、衰弱で埋める
    for (int i = 0; i < allocation.length; i++) {
      while (allocation[i].length < petSlots[i]) {
        if (!allocation[i].contains('氷結')) {
          allocation[i].add('氷結');
        } else if (!allocation[i].contains('衰弱')) {
          allocation[i].add('衰弱');
        } else {
          allocation[i].add('自由枠');
        }
      }
    }

    return allocation;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(widget.locale);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(loc.translate('appTitle')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: widget.locale,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.language, color: Colors.white),
              style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
              underline: Container(),
              items: const [
                DropdownMenuItem(value: 'ja', child: Text('日本語')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'ko', child: Text('한국어')),
              ],
              onChanged: (value) {
                if (value != null) widget.onLocaleChange(value);
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildInputCard(loc),
                      if (result != null) ...[
                        const SizedBox(height: 20),
                        _buildResultCard(loc),
                        const SizedBox(height: 20),
                        _buildResourceSummary(loc),
                      ],
                    ],
                  ),
                ),
              ),
              // フッター部分
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Created by $kAppCredit',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: Text('v$kAppVersion', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(AppLocalizations loc) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.translate('ownedResources'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(loc, loc.translate('core'), _coreController)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(loc, loc.translate('crystal'), _crystalController)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(loc, '${loc.translate('biscuit')} (K)', _biscuitController)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('${loc.translate('petType')}:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Flexible(
                  child: ChoiceChip(
                    label: Text(loc.translate('sameType')),
                    selected: isSameType,
                    onSelected: (selected) {
                      setState(() {
                        isSameType = true;
                        _autoCalculate();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ChoiceChip(
                    label: Text(loc.translate('differentType')),
                    selected: !isSameType,
                    onSelected: (selected) {
                      setState(() {
                        isSameType = false;
                        _autoCalculate();
                      });
                    },
                  ),
                ),
              ],
            ),
            if (!isSameType) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('mainPetAwakeningLevel'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedMainAwakening),
                          initialValue: selectedMainAwakening,
                          items: awakeningTable
                              .map((data) => DropdownMenuItem(value: data.level, child: Text(data.level)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedMainAwakening = value;
                                _autoCalculate();
                              });
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('helperPetAwakeningLevel'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedHelperAwakening),
                          initialValue: selectedHelperAwakening,
                          items: awakeningTable
                              .map((data) => DropdownMenuItem(value: data.level, child: Text(data.level)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedHelperAwakening = value;
                                _autoCalculate();
                              });
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (resourceWarning != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resourceWarning!,
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(AppLocalizations loc, String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(AppLocalizations loc) {
    return Card(
      elevation: 3,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.deepPurple[300]!, Colors.deepPurple[500]!]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.translate('referenceSetup'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        '${loc.translate('awakening')}: ${result!.mainAwakening}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green[400], borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        '${loc.translate('skillSlots')}: ${result!.totalSkillSlots}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              border: TableBorder.all(color: Colors.grey[300]!, width: 1.5),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(0.8),
                2: FlexColumnWidth(0.6),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(0.9),
                6: FlexColumnWidth(0.9),
              },
              children: [
                _buildTableHeaderRow(loc),
                _buildPetRowWithOptimalSkills(
                  loc,
                  loc.translate('mainPet'),
                  result!.mainAwakening,
                  result!.mainLevel,
                  awakeningTable.firstWhere((d) => d.level == result!.mainAwakening),
                  0,
                ),
                for (int i = 0; i < result!.helperCount; i++)
                  _buildPetRowWithOptimalSkills(
                    loc,
                    '${loc.translate('helperPet')} ${i + 1}',
                    result!.helperAwakening,
                    result!.helperLevels[i],
                    awakeningTable.firstWhere((d) => d.level == result!.helperAwakening),
                    i + 1,
                  ),
                _buildTotalRow(loc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeaderRow(AppLocalizations loc) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.deepPurple[500]),
      children: [
        loc.translate('pet'),
        loc.translate('awakening'),
        loc.translate('level'),
        loc.translate('resonanceRate'),
        loc.translate('resonanceDamage'),
        '(${loc.translate('freezeSkill')})',
        '(${loc.translate('weakness')})',
      ].map((text) => _buildCellBold(text, isHeader: true)).toList(),
    );
  }

  TableRow _buildPetRowWithOptimalSkills(
    AppLocalizations loc,
    String petName,
    String awakening,
    int level,
    AwakeningData awakeningData,
    int petIndex,
  ) {
    final mainData = awakeningTable.firstWhere((d) => d.level == result!.mainAwakening);
    final helperData = awakeningTable.firstWhere((d) => d.level == result!.helperAwakening);

    List<int> allSlots = [_getSkillSlots(result!.mainLevel)];
    for (int i = 0; i < result!.helperCount; i++) {
      allSlots.add(_getSkillSlots(result!.helperLevels[i]));
    }

    List<List<String>> petSkills = _calculateOptimalSkillAllocation(
      allSlots,
      mainData,
      helperData,
      result!.helperCount,
    );
    List<String> mySkills = petSkills[petIndex];

    Map<String, dynamic> skillValues = {
      '共鳴確率': {'text': '----', 'isFreeslot': false},
      '共鳴ダメージ': {'text': '----', 'isFreeslot': false},
      '氷結': {'text': '----', 'isFreeslot': false},
      '衰弱': {'text': '----', 'isFreeslot': false},
    };

    for (String skillType in mySkills) {
      if (skillType == '共鳴確率') {
        skillValues['共鳴確率'] = {'text': _formatPercentage(awakeningData.resonanceRate), 'isFreeslot': false};
      } else if (skillType == '共鳴ダメージ') {
        skillValues['共鳴ダメージ'] = {'text': _formatPercentage(awakeningData.resonanceDamage), 'isFreeslot': false};
      } else if (skillType == '氷結') {
        skillValues['氷結'] = {
          'text': '(${loc.translate('freezeSkill')})${_formatPercentage(awakeningData.freeze)}',
          'isFreeslot': false,
        };
      } else if (skillType == '衰弱') {
        skillValues['衰弱'] = {
          'text': '(${loc.translate('weakness')})${_formatPercentage(awakeningData.freeze)}',
          'isFreeslot': false,
        };
      } else if (skillType == '自由枠') {
        skillValues['共鳴確率'] = {'text': '(自由枠)', 'isFreeslot': true};
      }
    }

    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: [
        _buildCell(petName),
        _buildCell(awakening),
        _buildCell(level.toString()),
        _buildCellWithColor(skillValues['共鳴確率']['text'], skillValues['共鳴確率']['isFreeslot']),
        _buildCell(skillValues['共鳴ダメージ']['text']),
        _buildCellWithColor(skillValues['氷結']['text'], skillValues['氷結']['isFreeslot']),
        _buildCellWithColor(skillValues['衰弱']['text'], skillValues['衰弱']['isFreeslot']),
      ],
    );
  }

  TableRow _buildTotalRow(AppLocalizations loc) {
    final mainData = awakeningTable.firstWhere((d) => d.level == result!.mainAwakening);
    final helperData = awakeningTable.firstWhere((d) => d.level == result!.helperAwakening);

    List<int> allSlots = [_getSkillSlots(result!.mainLevel)];
    for (int i = 0; i < result!.helperCount; i++) {
      allSlots.add(_getSkillSlots(result!.helperLevels[i]));
    }

    List<List<String>> petSkills = _calculateOptimalSkillAllocation(
      allSlots,
      mainData,
      helperData,
      result!.helperCount,
    );

    double totalResonanceRate = 10.0;
    double totalResonanceDamage = 10.0;
    double totalFreeze = 0.0;
    double totalWeakness = 0.0;

    for (int i = 0; i < petSkills.length; i++) {
      final data = (i == 0) ? mainData : helperData;
      for (String skillType in petSkills[i]) {
        if (skillType == '共鳴確率') {
          totalResonanceRate += data.resonanceRate;
        } else if (skillType == '共鳴ダメージ') {
          totalResonanceDamage += data.resonanceDamage;
        } else if (skillType == '氷結') {
          totalFreeze += data.freeze;
        } else if (skillType == '衰弱') {
          totalWeakness += data.freeze;
        }
      }
    }

    if (totalResonanceRate > 100) totalResonanceRate = 100;

    return TableRow(
      decoration: BoxDecoration(color: Colors.yellow[100]),
      children: [
        _buildCellBold(loc.translate('total')),
        _buildCellBold(''),
        _buildCellBold(''),
        _buildCellBold(_formatPercentage(totalResonanceRate)),
        _buildCellBold(_formatPercentage(totalResonanceDamage)),
        _buildCellBold(totalFreeze > 0 ? _formatPercentage(totalFreeze) : ''),
        _buildCellBold(totalWeakness > 0 ? _formatPercentage(totalWeakness) : ''),
      ],
    );
  }

  Widget _buildResourceSummary(AppLocalizations loc) {
    int remainingCore = result!.availableCore - result!.usedCore;
    int remainingCrystal = result!.availableCrystal - result!.usedCrystal;
    int remainingBiscuit = result!.availableBiscuit - result!.usedBiscuit;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.translate('resourceUsageStatus'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('usedResources'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 8),
                      Text('${loc.translate('core')}: ${result!.usedCore}', style: const TextStyle(fontSize: 14)),
                      Text('${loc.translate('crystal')}: ${result!.usedCrystal}', style: const TextStyle(fontSize: 14)),
                      Text(
                        '${loc.translate('biscuit')}: ${(result!.usedBiscuit / 1000).toStringAsFixed(0)}K',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('remainingResources'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      Text('${loc.translate('core')}: $remainingCore', style: const TextStyle(fontSize: 14)),
                      Text('${loc.translate('crystal')}: $remainingCrystal', style: const TextStyle(fontSize: 14)),
                      Text(
                        '${loc.translate('biscuit')}: ${(remainingBiscuit / 1000).toStringAsFixed(0)}K',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.black87),
      ),
    );
  }

  Widget _buildCellWithColor(String text, bool isFreeslot) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: isFreeslot ? Colors.green : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCellBold(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isHeader ? Colors.white : Colors.black87),
      ),
    );
  }
}

class CalculationResult {
  final String mainAwakening;
  final String helperAwakening;
  final int helperCount;
  final int mainLevel;
  final List<int> helperLevels;
  final int totalSkillSlots;
  final int usedCore;
  final int usedCrystal;
  final int usedBiscuit;
  final int availableCore;
  final int availableCrystal;
  final int availableBiscuit;

  CalculationResult({
    required this.mainAwakening,
    required this.helperAwakening,
    required this.helperCount,
    required this.mainLevel,
    required this.helperLevels,
    required this.totalSkillSlots,
    required this.usedCore,
    required this.usedCrystal,
    required this.usedBiscuit,
    required this.availableCore,
    required this.availableCrystal,
    required this.availableBiscuit,
  });
}

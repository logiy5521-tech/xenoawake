// resource_calculator.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'awakening_table.dart';
import 'localization.dart';

const String kAppVersion = '1.1.2';
const String kAppCredit = 'Logi@YAMATO';

class _ZenkakuToHankakuFormatter extends TextInputFormatter {
  static final RegExp _zenNum = RegExp(r'[０１２３４５６７８９]');
  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String converted = newValue.text.replaceAllMapped(_zenNum, (Match m) {
      final ch = m.group(0)!;
      return String.fromCharCode(ch.codeUnitAt(0) - 0xFEE0);
    });
    converted = converted.replaceAll(_nonDigit, '');
    final offset = converted.length;
    return TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class ResourceCalculatorScreen extends StatefulWidget {
  final String locale;
  final void Function(String) onLocaleChange;

  const ResourceCalculatorScreen({super.key, required this.locale, required this.onLocaleChange});

  @override
  State<ResourceCalculatorScreen> createState() => _ResourceCalculatorScreenState();
}

class _ResourceCalculatorScreenState extends State<ResourceCalculatorScreen> {
  final _coreController = TextEditingController();
  final _crystalController = TextEditingController();
  final _biscuitController = TextEditingController();
  bool isSameType = true;
  CalculationResult? result;
  String? resourceWarning;

  // Secret mode
  bool isSecretMode = false;
  int _titleTapCount = 0;
  DateTime? _lastTapAt;
  final _th4Controller = TextEditingController(text: '45');
  final _th5Controller = TextEditingController(text: '70');
  final _th6Controller = TextEditingController(text: '100');

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
    _coreController.dispose();
    _crystalController.dispose();
    _biscuitController.dispose();
    _th4Controller.dispose();
    _th5Controller.dispose();
    _th6Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _coreController.text = prefs.getString('res_core') ?? '';
      _crystalController.text = prefs.getString('res_crystal') ?? '';
      _biscuitController.text = prefs.getString('res_biscuit') ?? '';
      isSameType = prefs.getBool('res_isSameType') ?? true;
      isSecretMode = prefs.getBool('res_secretMode') ?? false;
      _th4Controller.text = (prefs.getInt('res_th4') ?? 45).toString();
      _th5Controller.text = (prefs.getInt('res_th5') ?? 70).toString();
      _th6Controller.text = (prefs.getInt('res_th6') ?? 100).toString();
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
    await prefs.setBool('res_secretMode', isSecretMode);
    await prefs.setInt('res_th4', int.tryParse(_th4Controller.text) ?? 45);
    await prefs.setInt('res_th5', int.tryParse(_th5Controller.text) ?? 70);
    await prefs.setInt('res_th6', int.tryParse(_th6Controller.text) ?? 100);
  }

  int _requiredCoreForHelpers(int helpers) {
    if (helpers <= 2) {
      return 0;
    } else if (helpers == 3) {
      return 21;
    } else if (helpers == 4) {
      return int.tryParse(_th4Controller.text) ?? 45;
    } else if (helpers == 5) {
      return int.tryParse(_th5Controller.text) ?? 70;
    } else {
      return int.tryParse(_th6Controller.text) ?? 100; // 6体
    }
  }

  int _computeMaxHelpers(int totalCorePossible) {
    int base = isSecretMode ? 6 : 3;
    int maxH = 2;
    for (int h = 2; h <= base; h++) {
      if (totalCorePossible >= _requiredCoreForHelpers(h)) {
        maxH = h;
      }
    }
    return maxH;
  }

  void _autoCalculate() {
    if (_coreController.text.isEmpty || _crystalController.text.isEmpty || _biscuitController.text.isEmpty) {
      setState(() {
        result = null;
        resourceWarning = null;
      });
      return;
    }

    final core = int.tryParse(_coreController.text) ?? 0;
    final crystal = int.tryParse(_crystalController.text) ?? 0;
    final biscuit = (int.tryParse(_biscuitController.text) ?? 0) * 1000;

    setState(() {
      if (isSameType) {
        _calculateSameType(core, crystal, biscuit);
      } else {
        _calculateDifferentType(core, crystal, biscuit);
      }
    });
    _saveValues();
  }

  void _calculateSameType(int core, int crystal, int biscuit) {
    int bestAwk = 0;
    int bestHelperCount = 2;
    int bestMainLevel = 1;
    List<int> bestHelperLevels = [1, 1, 1, 1, 1, 1];
    int bestSkillSlots = 0;
    double bestScore = 0.0;

    for (int awk = 0; awk < awakeningTable.length; awk++) {
      final data = awakeningTable[awk];
      if (data.totalCore > core || data.totalCrystal > crystal) {
        continue;
      }

      int maxHelpers = _computeMaxHelpers(core);
      for (int helpers = 2; helpers <= maxHelpers; helpers++) {
        var levelOpt = _optimizePetLevels(biscuit, helpers);
        double score = (levelOpt['totalSlots'] * 1000 + awk * 10 + helpers * 0.1).toDouble();
        if (score > bestScore) {
          bestScore = score;
          bestAwk = awk;
          bestHelperCount = helpers;
          bestMainLevel = levelOpt['mainLevel'];
          bestHelperLevels = List.from(levelOpt['helperLevels']);
          bestSkillSlots = levelOpt['totalSlots'];
        }
      }
    }

    final data = awakeningTable[bestAwk];
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
  }

  void _calculateDifferentType(int core, int crystal, int biscuit) {
    if (awakeningTable.isEmpty) {
      setState(() {
        resourceWarning = '覚醒データが見つかりません';
        result = null;
      });
      return;
    }

    final mainData = awakeningTable.last;
    final helperData = awakeningTable.last;
    int totalCoreNeeded = mainData.totalCore + helperData.totalCore;
    int totalCrystalNeeded = mainData.totalCrystal + helperData.totalCrystal;

    if (totalCoreNeeded > core || totalCrystalNeeded > crystal) {
      setState(() {
        resourceWarning = 'リソースが不足しています（必要: コア$totalCoreNeeded, クリスタル$totalCrystalNeeded）';
        result = null;
      });
      return;
    }

    int maxHelpers = _computeMaxHelpers(core);
    var levelOpt = _optimizePetLevels(biscuit, maxHelpers);

    result = CalculationResult(
      mainAwakening: mainData.level,
      helperAwakening: helperData.level,
      helperCount: maxHelpers,
      mainLevel: levelOpt['mainLevel'],
      helperLevels: List.from(levelOpt['helperLevels']),
      totalSkillSlots: levelOpt['totalSlots'],
      usedCore: totalCoreNeeded,
      usedCrystal: totalCrystalNeeded,
      usedBiscuit: _getTotalBiscuitUsed(levelOpt['mainLevel'], levelOpt['helperLevels'], maxHelpers),
      availableCore: core,
      availableCrystal: crystal,
      availableBiscuit: biscuit,
    );
  }

  int _getTotalBiscuitUsed(int mainLevel, List<int> helperLevels, int helperCount) {
    int total = _getBiscuit(mainLevel);
    for (int i = 0; i < helperCount; i++) {
      total += _getBiscuit(helperLevels[i]);
    }
    return total;
  }

  Map<String, dynamic> _optimizePetLevels(int totalBiscuit, int helperCount) {
    const levels = [1, 30, 60, 90];
    List<Map<String, int>> pets = List.generate(helperCount + 1, (_) => {'level': 1, 'slots': 1});

    while (true) {
      int bestPet = -1;
      int bestNextLevel = -1;
      int bestGain = 0;
      int bestCost = 999999999;

      for (int i = 0; i < pets.length; i++) {
        int current = pets[i]['level']!;
        int idx = levels.indexOf(current);
        if (idx >= levels.length - 1) {
          continue;
        }

        int next = levels[idx + 1];
        int gain = _getSkillSlots(next) - pets[i]['slots']!;
        int cost = _getBiscuit(next) - _getBiscuit(current);

        if (cost > totalBiscuit) {
          continue;
        }

        if (gain > bestGain || (gain == bestGain && cost < bestCost)) {
          bestPet = i;
          bestNextLevel = next;
          bestGain = gain;
          bestCost = cost;
        }
      }

      if (bestPet == -1) {
        break;
      }

      pets[bestPet]['level'] = bestNextLevel;
      pets[bestPet]['slots'] = _getSkillSlots(bestNextLevel);
      totalBiscuit -= bestCost;
    }

    final helpers = List.generate(6, (i) => i + 1 <= helperCount ? pets[i + 1]['level']! : 1);
    return {
      'mainLevel': pets[0]['level']!,
      'helperLevels': helpers,
      'totalSlots': pets.fold(0, (sum, p) => sum + p['slots']!),
    };
  }

  int _getBiscuit(int level) {
    for (var data in petLevelTable) {
      if (data.level == level) {
        return data.totalBiscuit;
      }
    }
    return 0;
  }

  int _getSkillSlots(int level) {
    for (var data in petLevelTable) {
      if (data.level == level) {
        return data.skillSlots;
      }
    }
    return 1;
  }

  String _formatPercentage(double value) {
    return value == value.roundToDouble() ? '${value.toInt()}%' : '${value.toStringAsFixed(1)}%';
  }

  List<List<String>> _calculateOptimalSkillAllocation(
    List<int> petSlots,
    AwakeningData mainData,
    AwakeningData helperData,
    int helperCount,
  ) {
    List<List<String>> allocation = List.generate(1 + helperCount, (_) => []);
    double currentResonanceRate = 10.0;

    // ヘルパー優先で共鳴確率を詰める
    for (int i = 1; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i]) {
        double value = helperData.resonanceRate;
        if (currentResonanceRate + value <= 100.0) {
          allocation[i].add('共鳴確率');
          currentResonanceRate += value;
        }
      }
    }

    // メインに共鳴確率を入れる余地があれば
    if (currentResonanceRate < 100.0 && allocation[0].length < petSlots[0]) {
      double value = mainData.resonanceRate;
      if (currentResonanceRate + value <= 100.0) {
        allocation[0].add('共鳴確率');
        currentResonanceRate += value;
      }
    }

    // 100%を越えるなら自由枠
    for (int i = 0; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i]) {
        double value = (i == 0) ? mainData.resonanceRate : helperData.resonanceRate;
        if (!allocation[i].contains('共鳴確率') && currentResonanceRate + value > 100.0) {
          allocation[i].add('自由枠');
        }
      }
    }

    // 共鳴ダメージを埋める
    for (int i = 0; i < allocation.length; i++) {
      if (allocation[i].length < petSlots[i] && !allocation[i].contains('共鳴ダメージ')) {
        allocation[i].add('共鳴ダメージ');
      }
    }

    // 残りを氷結→衰弱→自由枠の順に埋める
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

  void _onTitleTapped() {
    final now = DateTime.now();
    if (_lastTapAt == null || now.difference(_lastTapAt!) > const Duration(seconds: 3)) {
      _titleTapCount = 0;
    }

    _lastTapAt = now;
    _titleTapCount++;

    if (_titleTapCount >= 5) {
      _titleTapCount = 0;
      setState(() {
        isSecretMode = !isSecretMode;
      });
      _saveValues();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSecretMode ? '実験モードをONにしました' : '実験モードをOFFにしました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(widget.locale);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTapped,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${loc.translate('appTitle')} - $kAppCredit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isSecretMode)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange[400], borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    '実験機能',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
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
              onChanged: (String? value) {
                if (value != null) {
                  widget.onLocaleChange(value);
                }
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
                      if (isSecretMode) ...[const SizedBox(height: 12), _buildSecretModeCard()],
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
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                  child: Text('v$kAppVersion', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                Expanded(child: _buildTextField(loc, loc.translate('core'), _coreController, '例: 4')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(loc, loc.translate('crystal'), _crystalController, '例: 2000')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(loc, '${loc.translate('biscuit')} (K)', _biscuitController, '例: 2000')),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${loc.translate('mainAndHelperPet')}:',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: Text(loc.translate('sameType')),
                  selected: isSameType,
                  onSelected: (_) {
                    setState(() {
                      isSameType = true;
                      _autoCalculate();
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(loc.translate('differentType')),
                  selected: !isSameType,
                  onSelected: (_) {
                    setState(() {
                      isSameType = false;
                      _autoCalculate();
                    });
                  },
                ),
              ],
            ),
            if (!isSameType && resourceWarning != null) ...[
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
        ),
      ),
    );
  }

  Widget _buildTextField(AppLocalizations loc, String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          inputFormatters: [_ZenkakuToHankakuFormatter(), FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildSecretModeCard() {
    return Card(
      color: Colors.orange[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'スキル枠解放条件設定（実験）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              '「スキル枠解放条件設定:これは実験モードであり、将来のアップデートを予測して楽しむためのモードです。個人個人の判断で利用してください。将来こうなるかどうかは誰にもわかりません」',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildThresholdField('4体 解放コア', _th4Controller, '45')),
                const SizedBox(width: 10),
                Expanded(child: _buildThresholdField('5体 解放コア', _th5Controller, '70')),
                const SizedBox(width: 10),
                Expanded(child: _buildThresholdField('6体 解放コア', _th6Controller, '100')),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  _saveValues();
                  _autoCalculate();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('実験設定を保存しました'), duration: Duration(seconds: 1)));
                },
                icon: const Icon(Icons.save),
                label: const Text('保存して再計算'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          inputFormatters: [_ZenkakuToHankakuFormatter(), FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: hint,
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
        _buildCellBold(loc.translate('pet'), isHeader: true),
        _buildCellBold(loc.translate('awakening'), isHeader: true),
        _buildCellBold(loc.translate('level'), isHeader: true),
        _buildCellBold(loc.translate('resonanceRate'), isHeader: true),
        _buildCellBold(loc.translate('resonanceDamage'), isHeader: true),
        _buildCellBold('(${loc.translate('freezeSkill')})', isHeader: true),
        _buildCellBold('(${loc.translate('weakness')})', isHeader: true),
      ],
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

    Map<String, Map<String, dynamic>> skillValues = {
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
        _buildCellWithColor(skillValues['共鳴確率']!['text'], skillValues['共鳴確率']!['isFreeslot']),
        _buildCell(skillValues['共鳴ダメージ']!['text']),
        _buildCellWithColor(skillValues['氷結']!['text'], skillValues['氷結']!['isFreeslot']),
        _buildCellWithColor(skillValues['衰弱']!['text'], skillValues['衰弱']!['isFreeslot']),
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

    if (totalResonanceRate > 100) {
      totalResonanceRate = 100;
    }

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
  final String mainAwakening, helperAwakening;
  final int helperCount, mainLevel;
  final List<int> helperLevels;
  final int totalSkillSlots, usedCore, usedCrystal, usedBiscuit;
  final int availableCore, availableCrystal, availableBiscuit;

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

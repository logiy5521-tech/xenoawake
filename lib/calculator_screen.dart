import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'awakening_table.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const int slot3CoreThreshold = 21;

  static const _prefsCore = 'resource_core';
  static const _prefsCrystal = 'resource_crystal';
  static const _prefsBiscuit = 'resource_biscuit';

  final _coreCtrl = TextEditingController();
  final _crystalCtrl = TextEditingController();
  final _biscuitCtrl = TextEditingController();

  Map<String, dynamic>? res2, res3;
  String? inputError;

  @override
  void initState() {
    super.initState();
    _loadInputs();
  }

  Future<void> _loadInputs() async {
    final prefs = await SharedPreferences.getInstance();
    _coreCtrl.text = prefs.getString(_prefsCore) ?? '';
    _crystalCtrl.text = prefs.getString(_prefsCrystal) ?? '';
    _biscuitCtrl.text = prefs.getString(_prefsBiscuit) ?? '';
    Future.delayed(const Duration(milliseconds: 30), _calcAll);
  }

  Future<void> _saveInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCore, _coreCtrl.text);
    await prefs.setString(_prefsCrystal, _crystalCtrl.text);
    await prefs.setString(_prefsBiscuit, _biscuitCtrl.text);
  }

  bool _isNumeric(String s) => RegExp(r'^\d+$').hasMatch(s);

  void _calcAll() {
    if (!_isNumeric(_coreCtrl.text) || !_isNumeric(_crystalCtrl.text) || !_isNumeric(_biscuitCtrl.text)) {
      setState(() {
        inputError = '半角数字で入力してください';
        res2 = null;
        res3 = null;
      });
      return;
    }

    inputError = null;
    int core = int.tryParse(_coreCtrl.text) ?? 0;
    int crystal = int.tryParse(_crystalCtrl.text) ?? 0;
    int biscuit = (int.tryParse(_biscuitCtrl.text) ?? 0) * 1000;

    setState(() {
      res2 = _calcOptimal(2, core, crystal, biscuit);
      res3 = _calcOptimal(3, core, crystal, biscuit);
    });
    _saveInputs();
  }

  Map<String, dynamic>? _calcOptimal(int slots, int core, int crystal, int biscuit) {
    int unlockCore = 0, unlockCrystal = 0;

    if (slots == 3) {
      int accCore = 0, accCrystal = 0, i = 0;
      while (i < awakeningTable.length) {
        accCore += awakeningTable[i].totalCore;
        accCrystal += awakeningTable[i].totalCrystal;
        if (accCore >= slot3CoreThreshold) break;
        i++;
      }
      if (accCore < slot3CoreThreshold) {
        return {
          "slot3_unlocked": false,
          "remain_core": slot3CoreThreshold - accCore,
          "remain_crystal": (i < awakeningTable.length) ? (awakeningTable[i].totalCrystal - accCrystal) : 0,
        };
      }
      unlockCore = accCore;
      unlockCrystal = accCrystal;

      // unlockCore/unlockCrystal は slot3 開放のみ
      int usableCore = core - unlockCore;
      int usableCrystal = crystal - unlockCrystal;
      if (usableCore < 0 || usableCrystal < 0 || biscuit < 0) return null;
    }

    AwakeningData? maxAwk;
    for (var a in awakeningTable.reversed) {
      if (a.totalCore <= (slots == 3 ? core - unlockCore : core) &&
          a.totalCrystal <= (slots == 3 ? crystal - unlockCrystal : crystal)) {
        maxAwk = a;
        break;
      }
    }
    if (maxAwk == null) return null; // 消費不可時

    int petCount = 1 + slots;
    final lvOpts = [90, 60, 30, 1];
    List<List<int>> patterns = _lvPatterns(petCount, lvOpts, biscuit);

    _PatternScore? best;
    for (final pat in patterns) {
      List<int> sorted = [...pat]..sort((b, a) => a.compareTo(b));
      var skills = _skillDetail(maxAwk, sorted);
      var scoreArr = [
        skills['共鳴確率'] ?? 0.0,
        skills['共鳴ダメージ'] ?? 0.0,
        skills['シールド'] ?? 0.0,
        skills['氷結'] ?? 0.0,
        skills['攻撃%'] ?? 0.0,
      ];
      if (best == null || _betterScore(scoreArr, best.scoreArr)) {
        best = _PatternScore(sorted, skills, scoreArr);
      }
    }
    if (best == null) return null;

    final usedBiscuit = best.lvPat.fold<int>(0, (sum, lv) => sum + (biscuitCosts[lv] ?? 0));

    return {
      'awakening': maxAwk,
      'petLevels': best.lvPat,
      'skills': best.skills,
      // 覚醒素材消費（maxAwk 分）
      'usedCore': maxAwk.totalCore,
      'usedCrystal': maxAwk.totalCrystal,
      'usedBiscuit': usedBiscuit,
      "slot3_unlocked": slots == 3,
      "unlockCore": unlockCore,
      "unlockCrystal": unlockCrystal,
    };
  }

  List<List<int>> _lvPatterns(int count, List<int> opts, int limit) {
    List<List<int>> res = [];
    void dfs(int idx, List<int> cur, int used) {
      if (idx == count) {
        res.add(List<int>.from(cur));
        return;
      }
      for (var lv in opts) {
        int add = (biscuitCosts[lv] ?? 0);
        if (used + add > limit) continue;
        cur.add(lv);
        dfs(idx + 1, cur, used + add);
        cur.removeLast();
      }
    }

    dfs(0, [], 0);
    return res;
  }

  bool _betterScore(List<double> a, List<double> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  Map<String, double> _skillDetail(AwakeningData a, List<int> levels) {
    int slotsAll = 0, slots3 = 0, slots4 = 0;
    for (var lv in levels) {
      int s = _slots(lv);
      slotsAll += (s >= 1) ? 1 : 0;
      slotsAll += (s >= 2) ? 1 : 0;
      if (s >= 3) slots3++;
      if (s >= 4) slots4++;
    }
    double resSum = a.resonanceRate * slotsAll;
    double maxRes = resSum.clamp(0, 100);
    double atk = resSum > 100 ? a.attackPercent * ((resSum - 100) / (a.resonanceRate > 0 ? a.resonanceRate : 1)) : 0;
    return {
      '共鳴確率': maxRes,
      '共鳴ダメージ': a.resonanceDamage * slotsAll,
      '攻撃%': atk,
      'シールド': a.shield * slots3,
      '氷結': a.freeze * slots4,
    };
  }

  int _slots(int lv) {
    if (lv >= 90) return 4;
    if (lv >= 60) return 3;
    if (lv >= 30) return 2;
    return 1;
  }

  Widget _inputField(String label, TextEditingController ctrl, {String? suffix, IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, size: 28) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        hintText: 'ここに数字を入力',
      ),
      autofillHints: const [],
      onChanged: (_) => _calcAll(),
    );
  }

  Widget _inputCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.edit, color: Colors.indigo, size: 28),
                SizedBox(width: 8),
                Text('所持リソースを入力', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                _inputField('異獣コア', _coreCtrl, icon: Icons.circle),
                _inputField('覚醒クリスタル', _crystalCtrl, icon: Icons.star),
                _inputField('ビスケット(K)', _biscuitCtrl, icon: Icons.cookie),
              ],
            ),
            if (inputError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(inputError!, style: const TextStyle(fontSize: 13, color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimal(String title, Map<String, dynamic>? data, int slotCount) {
    if (data != null && data['slot3_unlocked'] == false) {
      return Card(
        color: Colors.red.shade50,
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 26),
              const SizedBox(width: 10),
              Text(
                'スロット3構成：実現不可\nあと異獣コア${data['remain_core']}個・クリスタル${data['remain_crystal']}個消費でスロット3解放',
                style: const TextStyle(fontSize: 17, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    } else if (data == null) {
      return Card(
        color: Colors.red.shade50,
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 28),
              const SizedBox(width: 10),
              Text(
                '$title: 実現不可（素材不足)',
                style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final AwakeningData a = data['awakening'] as AwakeningData;
    final List<int> petLv = (data['petLevels'] as List).cast<int>();
    final skills = (data['skills'] as Map).cast<String, double>();
    final usedCore = data['usedCore'] as int;
    final usedCrystal = data['usedCrystal'] as int;
    final usedBiscuit = data['usedBiscuit'] as int;

    // 追加: unlock 分（スロット3開放コスト）
    final unlockCoreUsed = data['unlockCore'] as int? ?? 0;
    final unlockCrystalUsed = data['unlockCrystal'] as int? ?? 0;

    // 入力値
    final inputCore = int.tryParse(_coreCtrl.text) ?? 0;
    final inputCrystal = int.tryParse(_crystalCtrl.text) ?? 0;
    final inputBiscuit = (int.tryParse(_biscuitCtrl.text) ?? 0) * 1000;

    // 修正: 残数は unlock + 覚醒本体の消費を合算して差し引く
    final remainCore = inputCore - usedCore - unlockCoreUsed;
    final remainCrystal = inputCrystal - usedCrystal - unlockCrystalUsed;
    final remainBiscuit = inputBiscuit - usedBiscuit;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '最適編成案',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.blue[900]),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(24)),
                  child: Text(
                    '覚醒:${a.level}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.purple.shade400, borderRadius: BorderRadius.circular(24)),
                  child: Text(
                    'サポート:$slotCount体',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                columns: const [
                  DataColumn(label: Text('ペット')),
                  DataColumn(label: Text('LV')),
                  DataColumn(label: Text('共鳴確率')),
                  DataColumn(label: Text('共鳴ダメージ')),
                  DataColumn(label: Text('(シールド)')),
                  DataColumn(label: Text('(氷結)')),
                ],
                rows:
                    List.generate(
                      petLv.length,
                      (i) => DataRow(
                        cells: [
                          DataCell(Text(i == 0 ? 'メイン' : 'サポート$i')),
                          DataCell(
                            Text('${petLv[i]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                          DataCell(Text('${a.resonanceRate.toStringAsFixed(1)}%')),
                          DataCell(Text('${a.resonanceDamage.toStringAsFixed(1)}%')),
                          DataCell(Text('${a.shield.toStringAsFixed(1)}%')),
                          DataCell(Text('${a.freeze.toStringAsFixed(1)}%')),
                        ],
                      ),
                    )..add(
                      DataRow(
                        color: WidgetStateProperty.all(Colors.yellow.shade50),
                        cells: [
                          const DataCell(Text('合計', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(Text('—')),
                          DataCell(
                            Text(
                              '${skills['共鳴確率']?.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${skills['共鳴ダメージ']?.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${skills['シールド']?.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${skills['氷結']?.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
            if (skills['攻撃%'] != null && (skills['攻撃%'] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '共鳴確率上限超過分は攻撃%で加算 → +${skills['攻撃%']?.toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.indigo.shade50),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Text('リソース使用状況', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
                      children: [
                        TableRow(
                          children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('コア')),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                // 表示は maxAwk 分のみ（開放分は別途残数に反映）
                                '$usedCore',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[900]),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '$remainCore',
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('覚醒クリスタル')),
                            Padding(padding: const EdgeInsets.all(6), child: Text('$usedCrystal')),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '$remainCrystal',
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('ビスケット')),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${usedBiscuit ~/ 1000}K')),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '${(remainBiscuit ~/ 1000)}K',
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        // 任意: 開放分の可視化
                        if (unlockCoreUsed > 0 || unlockCrystalUsed > 0)
                          TableRow(
                            children: [
                              const Padding(padding: EdgeInsets.all(6), child: Text('開放(参考)')),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '+C:$unlockCoreUsed, +Cr:$unlockCrystalUsed',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                              const Padding(padding: EdgeInsets.all(6), child: Text('')),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FC),
    appBar: AppBar(
      title: const Text('XenoPets覚醒計算', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.indigo.shade700,
      elevation: 2,
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputCard(),
              const SizedBox(height: 12),
              _buildOptimal('スロット2構成', res2, 2),
              const SizedBox(height: 16),
              _buildOptimal('スロット3構成', res3, 3),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PatternScore {
  List<int> lvPat;
  Map<String, double> skills;
  List<double> scoreArr;
  _PatternScore(this.lvPat, this.skills, this.scoreArr);
}

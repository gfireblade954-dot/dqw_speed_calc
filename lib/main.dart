import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DQW 素早さ計算',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185FA5)),
        useMaterial3: true,
      ),
      home: const SpeedCalcPage(),
    );
  }
}

class SpeedCalcPage extends StatefulWidget {
  const SpeedCalcPage({super.key});
  @override
  State<SpeedCalcPage> createState() => _SpeedCalcPageState();
}

// カード1枚の表示結果
class _CardResult {
  final String text;
  final Color color;
  const _CardResult(this.text, this.color);
}

class _SpeedCalcPageState extends State<SpeedCalcPage>
    with SingleTickerProviderStateMixin {
  bool isMega = false;
  late final TabController _tabController;

  // ── Tab1: B基準計算 ──
  final TextEditingController _bBaseController = TextEditingController();

  // ── Tab2: 詳細検証 ──
  final List<String> names = ['A', 'B', 'C', 'D'];
  final List<TextEditingController> controllers =
      List.generate(4, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bBaseController.dispose();
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 共通計算ロジック ──

  // N の範囲: 通常100〜115(16通り), メガ100〜120(21通り)
  int get nMax => isMega ? 120 : 115;
  int get nCount => nMax - 99;

  // 行動値 = 素早さ × N ÷ 100 (切り捨て)
  int actMax(int spd) => spd * nMax ~/ 100;

  // AさんがBさんより確定先攻になる最低素早さ
  // AはidxがB未満 → タイ勝ち → actMin(A) ≥ actMax(B) が条件
  int minSpeedToGoFirst(int bSpd) => actMax(bSpd);

  // 確定後攻になる最大素早さ（index大側 = タイ負け）
  // actMax(self) ≤ actMin(cmp) = spd が条件
  int neededToLoseTie(int spd) => ((spd + 1) * 100 - 1) ~/ nMax;

  // 確定後攻になる最大素早さ（index小側 = タイ勝ち）
  // actMax(self) < actMin(cmp) = spd が条件
  int neededToLose(int spd) => (spd * 100 - 1) ~/ nMax;

  // 確定必要値: 相手のactMax + 1（タイ負け側が確定先攻するため）
  int neededToBeat(int spd) => actMax(spd) + 1;

  // 各キャラの比較対象index
  int compareTarget(int idx) => idx == 0 ? 1 : idx - 1;

  // selfIdxがcmpIdxより先攻になる確率(%)
  double calcWinRate(int selfSpd, int selfIdx, int cmpSpd, int cmpIdx) {
    int wins = 0;
    final total = nCount * nCount;
    for (int ns = 100; ns <= nMax; ns++) {
      for (int nc = 100; nc <= nMax; nc++) {
        final avS = selfSpd * ns ~/ 100;
        final avC = cmpSpd * nc ~/ 100;
        if (avS > avC || (avS == avC && selfIdx < cmpIdx)) wins++;
      }
    }
    return wins / total * 100;
  }

  // 空きキャラの連鎖比較速度を取得する
  int? _getChainSpeed(int idx) {
    final v = int.tryParse(controllers[idx].text);
    if (v != null && v > 0) return v;

    if (idx == 0) return null;

    int? anchorVal;
    int anchorIdx = -1;
    for (int i = idx - 1; i >= 0; i--) {
      final av = int.tryParse(controllers[i].text);
      if (av != null && av > 0) {
        anchorVal = av;
        anchorIdx = i;
        break;
      }
    }
    if (anchorVal == null) return null;

    int spd = anchorVal;
    for (int i = anchorIdx; i < idx; i++) {
      final nextVal = int.tryParse(controllers[i + 1].text);
      if (nextVal != null && nextVal > 0) {
        spd = nextVal;
      } else {
        spd = neededToLoseTie(spd);
      }
    }
    return spd;
  }

  // 右側で最も近い入力済みキャラを起点に
  // idx が確定先攻するための最低素早さを右→左に連鎖計算する。
  // 途中に入力済みキャラがあれば実値優先。
  int? _getChainSpeedFromRight(int idx) {
    for (int i = idx + 1; i < 4; i++) {
      final anchorVal = int.tryParse(controllers[i].text);
      if (anchorVal != null && anchorVal > 0) {
        // anchor(i) から idx まで右→左に連鎖
        // 空きキャラ: actMax(右隣の最低値) = そのキャラの先攻最低値
        int spd = anchorVal;
        for (int j = i; j > idx; j--) {
          final leftVal = int.tryParse(controllers[j - 1].text);
          if (leftVal != null && leftVal > 0) {
            spd = leftVal; // 入力済みキャラは実値優先
          } else {
            spd = actMax(spd); // 空き: 右隣より先攻するための最低値
          }
        }
        return spd;
      }
    }
    return null;
  }

  // Tab2: カードidxの結果を返す
  _CardResult? getCardResult(int idx) {
    final int? selfVal = int.tryParse(controllers[idx].text);
    final bool selfOk = selfVal != null && selfVal > 0;
    final int cmpIdx = compareTarget(idx);

    // ── 自分が空きのとき ──
    if (!selfOk) {
      // ① 左チェーン: 比較対象側から連鎖値を取得
      final int? cmpChain = _getChainSpeed(cmpIdx);
      if (cmpChain != null) {
        if (idx < cmpIdx) {
          // A(idx=0): Bより先攻側 → タイ勝ち → actMax(B)以上で確定先攻
          return _CardResult(
            '${minSpeedToGoFirst(cmpChain)}以上で確定先攻',
            Colors.blue.shade700,
          );
        }
        // B,C,D: 左隣より後攻側 → タイ負け → neededToLoseTie以下で後攻
        return _CardResult(
          '${neededToLoseTie(cmpChain)}以下で後攻',
          Colors.grey.shade600,
        );
      }

      // ② 右チェーン: 左にアンカーがない場合、右側から先攻最低値を連鎖計算
      final int? rightChain = _getChainSpeedFromRight(idx);
      if (rightChain != null) {
        return _CardResult('$rightChain以上で確定先攻', Colors.blue.shade700);
      }

      return null;
    }

    // ── 自分が入力済み ──
    final int self = selfVal;

    final int? cmpVal = int.tryParse(controllers[cmpIdx].text);
    final bool cmpOk = cmpVal != null && cmpVal > 0;

    // 比較対象が未入力: その情報は相手の空きカードが担うため何も表示しない
    if (!cmpOk) return null;

    // ── 両方入力済み: 先攻率を計算 ──
    final int cmp = cmpVal;
    final double rate = calcWinRate(self, idx, cmp, cmpIdx);
    final String rStr = rate.toStringAsFixed(2);

    if (rate >= 100.0) return _CardResult('確定先攻', Colors.blue.shade700);
    if (rate <= 0.0)   return _CardResult('確定後攻', Colors.blue.shade700);
    if (rate >= 50.0) {
      return _CardResult('$rStr%で先攻', Colors.orange.shade700);
    }
    // 先攻率50%未満: 後攻率を表示
    final postStr = (100.0 - rate).toStringAsFixed(2);
    return _CardResult('$postStr%で後攻', Colors.grey.shade600);
  }

  void onChanged() => setState(() {});

  void clearAll() {
    setState(() {
      _bBaseController.clear();
      for (var c in controllers) {
        c.clear();
      }
    });
  }

  // ── バトル種別セグメントボタン ──
  Widget _buildBattleTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Text('バトル種別',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('通常 (×1.15)')),
                  ButtonSegment(
                      value: true, label: Text('メガ/ギガ/魔王 (×1.20)')),
                ],
                selected: {isMega},
                onSelectionChanged: (v) =>
                    setState(() {
                      isMega = v.first;
                    }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab1: B基準計算 ──

  Widget _buildBBaseTab() {
    final int? bVal = int.tryParse(_bBaseController.text);
    final bool bOk = bVal != null && bVal > 0;

    // B入力済みのとき各閾値を計算
    final int? aMin = bOk ? minSpeedToGoFirst(bVal) : null;
    final int? cMax = bOk ? neededToLoseTie(bVal) : null;
    final int? dMax = (cMax != null) ? neededToLoseTie(cMax) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBattleTypeSelector(),
          const SizedBox(height: 12),

          // Bさん入力カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bさん（基準）',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bBaseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '素早さを入力',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // A / C / D の結果カード（幅600+: 横3列 / スマホ: 縦3列）
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              final resultCards = [
                _buildBBaseResultCard(
                  label: 'Aさん（Bより先）',
                  content: aMin != null
                      ? '$aMin以上で確定先攻'
                      : 'Bさんの素早さを入力してください',
                  color: aMin != null
                      ? Colors.blue.shade700
                      : Colors.grey.shade400,
                ),
                _buildBBaseResultCard(
                  label: 'Cさん（Bより後）',
                  content: cMax != null
                      ? '$cMax以下で確定後攻'
                      : 'Bさんの素早さを入力してください',
                  color: cMax != null
                      ? Colors.orange.shade700
                      : Colors.grey.shade400,
                ),
                _buildBBaseResultCard(
                  label: 'Dさん（Cより後）',
                  content: dMax != null
                      ? '$dMax以下で確定後攻'
                      : 'Bさんの素早さを入力してください',
                  color: dMax != null
                      ? Colors.orange.shade700
                      : Colors.grey.shade400,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: resultCards.asMap().entries.map((e) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: e.key == 0 ? 0 : 4,
                          right: e.key == 2 ? 0 : 4,
                        ),
                        child: e.value,
                      ),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: resultCards
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8), child: c))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 8),
          Text(
            '行動順: A→B→C→D\n'
            'A確定先攻: actMax(B)以上 / C・D確定後攻: タイ負け計算',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBBaseResultCard({
    required String label,
    required String content,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab2: 詳細検証 ──

  Widget _buildDetailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBattleTypeSelector(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final cards = List.generate(4, _buildDetailCard);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards.asMap().entries.map((e) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: e.key == 0 ? 0 : 4,
                          right: e.key == 3 ? 0 : 4,
                        ),
                        child: e.value,
                      ),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: cards
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8), child: c))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '行動順: A→B→C→D\n'
            '比較対象: A↔B, B↔A, C↔B, D↔C',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(int idx) {
    final result = getCardResult(idx);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${names[idx]}さん',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controllers[idx],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '素早さを入力',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => onChanged(),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                result.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: result.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DQW 素早さ計算'),
        actions: [
          TextButton(onPressed: clearAll, child: const Text('クリア')),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'シンプルモード'),
            Tab(text: '詳細モード'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBBaseTab(),
          _buildDetailTab(),
        ],
      ),
    );
  }
}

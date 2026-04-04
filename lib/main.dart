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

class _SpeedCalcPageState extends State<SpeedCalcPage> {
  bool isMega = false;
  final List<String> names = ['A', 'B', 'C', 'D'];
  final List<TextEditingController> controllers =
      List.generate(4, (_) => TextEditingController());

  // N の範囲: 通常100〜115(16通り), メガ100〜120(21通り)
  int get nMax => isMega ? 120 : 115;
  int get nCount => nMax - 99;

  // 行動値 = 素早さ × N ÷ 100 (切り捨て)
  int actMax(int spd) => spd * nMax ~/ 100;

  // 確定必要値: 相手のactMax + 1
  int neededToBeat(int spd) => actMax(spd) + 1;

  // 確定後攻になる最大素早さ（自分がタイを制する場合: index小 = 先攻）
  // actMax(self) < actMin(cmp) = spd が条件
  int neededToLose(int spd) => (spd * 100 - 1) ~/ nMax;

  // 確定後攻になる最大素早さ（自分がタイを負ける場合: index大 = 後攻）
  // actMax(self) ≤ actMin(cmp) = spd が条件（タイも負けるので ≤）
  // floor(self * nMax / 100) ≤ spd  ⟺  self ≤ floor(((spd+1)*100 - 1) / nMax)
  int neededToLoseTie(int spd) => ((spd + 1) * 100 - 1) ~/ nMax;

  // 各キャラの比較対象index
  // A(0): Bと比較(1)  B(1): Aと比較(0)  C(2): Bと比較(1)  D(3): Cと比較(2)
  int compareTarget(int idx) => idx == 0 ? 1 : idx - 1;

  // selfIdxがcmpIdxより先攻になる確率(%)
  // 全N組み合わせを列挙: 自分行動値 > 相手行動値 → 先攻
  //                       同値 → 低index(左)が先攻
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
  // - idx が入力済み → 実際の値を返す
  // - idx が空き → 左側で最近の入力済みキャラを起点に
  //   neededToLose を連鎖適用して仮速度を算出
  // 起点が見つからなければ null を返す（何も表示しない）
  int? _getChainSpeed(int idx) {
    // 入力済みなら実値を返す
    final v = int.tryParse(controllers[idx].text);
    if (v != null && v > 0) return v;

    // 空き: idx=0(A)は左に起点なし
    if (idx == 0) return null;

    // 左側で最も近い入力済みキャラを探す
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
    if (anchorVal == null) return null; // 起点なし

    // 起点 → idx まで連鎖計算
    // 途中に入力済みキャラがいれば実値に切り替える
    int spd = anchorVal;
    for (int i = anchorIdx; i < idx; i++) {
      final nextVal = int.tryParse(controllers[i + 1].text);
      if (nextVal != null && nextVal > 0) {
        spd = nextVal; // 入力済みキャラは実値優先
      } else {
        spd = neededToLoseTie(spd); // 空きは後攻上限で連鎖（常にindex大側 = タイ負け）
      }
    }
    return spd;
  }

  // カードidxの結果を返す（null = 何も表示しない）
  _CardResult? getCardResult(int idx) {
    final int? selfVal = int.tryParse(controllers[idx].text);
    final bool selfOk  = selfVal != null && selfVal > 0;
    final int cmpIdx   = compareTarget(idx);

    // ── 自分が空きのとき ──
    // 連鎖計算で比較対象の有効速度を取得して後攻上限を表示
    if (!selfOk) {
      final int? cmpChain = _getChainSpeed(cmpIdx);
      if (cmpChain == null) return null;
      // index大（B/C/D）はタイも負けるので neededToLoseTie、A は neededToLose
      final int threshold = idx > cmpIdx
          ? neededToLoseTie(cmpChain)
          : neededToLose(cmpChain);
      return _CardResult(
        '$threshold以下で後攻',
        Colors.grey.shade600,
      );
    }

    // 以下、自分は入力済み
    final int self = selfVal; // selfOk が true なので非null（Dartが型推論済み）

    final int? cmpVal = int.tryParse(controllers[cmpIdx].text);
    final bool cmpOk  = cmpVal != null && cmpVal > 0;

    // ── 比較対象が空きのとき ──
    // 確定必要値 = 自分のactMax + 1（比較対象がこれ以上なら確定先攻される）
    if (!cmpOk) {
      return _CardResult(
        '確定必要値: ${neededToBeat(self)}',
        Colors.blue.shade700,
      );
    }

    // ── 両方入力済み: 先攻率を計算 ──
    final int cmp      = cmpVal;
    final double rate  = calcWinRate(self, idx, cmp, cmpIdx);
    final String rStr  = rate.toStringAsFixed(2);

    if (rate >= 100.0) return _CardResult('確定先攻', Colors.blue.shade700);
    if (rate <=   0.0) return _CardResult('確定後攻', Colors.blue.shade700);
    if (self >= cmp) {
      return _CardResult('$rStr%で先攻', Colors.orange.shade700);
    }
    // index大（B/C/D）はタイも負けるので neededToLoseTie、A は neededToLose
    final int threshold = idx > cmpIdx
        ? neededToLoseTie(cmp)
        : neededToLose(cmp);
    return _CardResult(
      '$threshold以下なら後攻',
      Colors.grey.shade600,
    );
  }

  void onChanged() => setState(() {});

  void clearAll() {
    setState(() {
      for (var c in controllers) { c.clear(); }
    });
  }

  // キャラ1枚分のカード
  Widget _buildCard(int idx) {
    final result = getCardResult(idx);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // キャラ名
            Text(
              '${names[idx]}さん',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // 素早さ入力欄
            TextField(
              controller: controllers[idx],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '素早さを入力',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => onChanged(),
            ),
            // 結果表示エリア
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── バトル種別 ──
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Text('バトル種別',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: false, label: Text('通常 (×1.15)')),
                          ButtonSegment(
                              value: true,
                              label: Text('メガ/ギガ/魔王 (×1.20)')),
                        ],
                        selected: {isMega},
                        onSelectionChanged: (v) =>
                            setState(() { isMega = v.first; }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── キャラ入力エリア（幅600未満: 縦1列 / 以上: 横1列）──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final cards = List.generate(4, _buildCard);

                if (isWide) {
                  // PC・横向き: 横1列
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cards.asMap().entries.map((e) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left:  e.key == 0 ? 0 : 4,
                            right: e.key == 3 ? 0 : 4,
                          ),
                          child: e.value,
                        ),
                      );
                    }).toList(),
                  );
                }

                // スマホ縦向き: 縦1列
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
      ),
    );
  }
}

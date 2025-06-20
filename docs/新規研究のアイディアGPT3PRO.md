**前提と課題整理:**

現状のリソース（歩行解析アプリ／IMUプラットフォーム／学内被験者パネル）を踏まえると、  
1) 追加ハードウェアの調達や新規臨床集団のリクルートは最小化したい  
2) 既存コードベースを“深掘り”して論文化に十分な新規性を生む必要がある  

という二点がボトルネックです。したがって以下では、

・研究案５（高齢者＋神経計測）は除外  
・研究案３は段階的縮小案（3-lite）を提示  
・研究案１・２・４はプロトコルと評価指標を具体化  

したうえで、それぞれの既存研究を網羅的に洗い出すための「文献レビュー用プロンプト集」を併載します。

---

**研究案１: 可変難度・二重課題プロトコルによる動的天井効果の定量化**

目的  
歩行に認知負荷を付加しながら適応テンポ制御の効果が変動する“動的天井”を個人単位で数値化する。

実験デザイン  
・被験者: 健常成人 N=24（男女均等、音楽経験バラツキ確保）  
・条件: 0-back / 1-back / 2-back × 適応テンポ vs 固定テンポ（6条件、各6分）  
・順序: ラテン方格デザインで順序効果を除去  
・測定変数  
　– 歩行周期変動係数 CV  
　– stride-interval entropy (sample entropy, m=2, r=0.2)  
　– 心拍同期指数 $$SDNN$$  
　– 主観的負荷 NASA-TLX  

解析  
混合効果モデル  
$$CV_{ijk} = \beta_0 + \beta_1 \text{負荷}_i + \beta_2 \text{制御方式}_j + \beta_3 (\text{負荷} \times \text{方式})_{ij}+ u_{\text{被験者 }k} + \varepsilon_{ijk}$$  

パイロット 6 名で効果量を推定しサンプルサイズを確定する（G*Power, f=0.25 で N≈22）。

進捗管理  
Week 1-2: 機能仕様実装（N-back 音声読み上げモジュール）  
Week 3: 予備試験→閾値調整  
Week 4-6: 本試験  
Week 7: 解析・ドラフト作成  

---

**研究案２: 注意焦点操作がリズム同調効率に及ぼす効果の因果検証**

目的  
外的焦点（環境）と内的焦点（身体動き）により位相補正ゲインと周期収束時間がどう変わるかを検証。

操作チェック  
・眼球運動をスマートグラス内蔵アイトラッカー（Tobii Pro Glasses 3）で記録  
・外的焦点条件：遠方 LED ポールに意識を向ける  
・内的焦点条件：つま先位置を随時確認させる  

主要指標  
・位相誤差 $$\varphi(t)$$ の RMSE  
・周期収束時間 $$T_c$$（|SPM目標−実測| < 3 SPM になるまでの時間）  
・ウィーク後保持率（24h 再テスト）  

統計  
対応あり t 検定＋Bayes Factor（BF10 で実質的証拠を評価）。保持率は反復測定 ANOVA。  

---

**研究案３-lite: 最小構成マルチセンサーフュージョンによるリアルタイム歩行状態推定**

難易度低減策  
1) EMG と IMU の 2 モダリティみに絞り、レーダーは Phase-2 へ延期  
2) 既存 IMU (M5StickC Plus 2)＋市販アームバンド型 EMG (Myo Armband) を Bluetooth で時刻同期  
3) 100 ms 更新のテンポ制御ループを Flutter/Dart 上に統合  

アルゴリズム  
・モデル: CNN（IMU 時系列 128 × 6）+ EMG 簡易統計量 (RMS, MAV) を Concatenate→Bi-LSTM → Fully Connected  
・量子化: TensorFlow Lite int-8 量子化でスマホ On-device 推論  
・性能目標: SPM 推定誤差 <1.2、レイテンシ <150 ms  

段階的マイルストーン  
Phase-A: 同期・通信基盤（2 週間）  
Phase-B: データ収集 10 名 × 30 min、クロス検証  
Phase-C: アプリ組込み & A/B テスト（適応 vs 固定）  

---

**研究案４: 強化学習ベース自己進化テンポアルゴリズム＋Explainable AI**

タスク定式化  
・状態 $$s_t$$: [SPM, CV, HR, 歩行安定スコア]  
・行動 $$a_t$$: −5 / 0 / +5 BPM  
・報酬 $$R_t = -(\text{CV}) - 0.1|a_t| - 0.05 (\Delta HR)$$  
・アルゴリズム: Soft Actor-Critic (SAC, discrete)  

安全策  
・行動空間を ±5 BPM に制限  
・探索温度パラメータ $$\alpha$$ を CV 上限超過時に半減  

Explainability  
Integrated Gradients で各状態変数の行動寄与を可視化し、週次 PDF レポートを自動生成。

評価  
N=12、5 日連続使用→学習曲線 (報酬平均) が 3 日目で収束するかを検定。  
擬似固定テンポ群との差を RM-ANOVA で比較。  

---

**文献レビュー用プロンプト集**

下記プロンプト（英語ベース）を PubMed / IEEE Xplore / Google Scholar / Web of Science / Scopus でそのままコピー＆ペースト → ​「過去 5 年」「Human studies」のフィルタを推奨。カッコ内は AND/OR で適宜組合せ。

1. 研究案１関連  
```
("dynamic ceiling effect" OR "ceiling effect" OR "performance ceiling") AND (gait OR walking) AND ("dual task" OR "n-back") AND ("rhythmic auditory stimulation" OR "metronome pacing")  
```

2. 研究案２関連  
```
("attentional focus" OR "external focus" OR "internal focus") AND (entrainment OR "sensorimotor synchronization") AND (gait OR walking)  
```

3. 研究案３-lite関連  
```
(IMU OR "inertial measurement unit") AND EMG AND (fusion OR "multimodal") AND (gait OR walking) AND (real-time OR "online")  
```

4. 研究案４関連  
```
("reinforcement learning" OR "actor-critic" OR SAC) AND (metronome OR "tempo adaptation") AND (gait OR walking) AND ("explainable AI" OR XAI)  
```

5. 横断レビュー（共通語句を組み替えて網羅検索）  
```
("adaptive tempo" OR "adaptive metronome") AND ("sensorimotor synchronization") AND ("gait variability")  
```

検索ヒント  
・レビュー論文だけでなく “protocol”, “pilot study”, “preprint” をキーワードに含めると未発表手法の把握に有効  
・Citation chaining（主要論文の引用／被引用）で年代を遡り、理論起点を確認  
・IEEE では “Real-Time Systems” カテゴリ、PubMed では MeSH “Walking/physiology*” でフィルタリング  

---

**次のアクション提案:**

1. 上記プロンプトで Zotero コレクションを構築（1 週間）  
2. パイロット対象者 4 名を使って研究案１・２のスクリプト検証（2 週間）  
3. 研究案３-lite Phase-A の通信同期実装に着手（並行 2 週間）  
4. 学会アブストラクト締切 8 週間前に初期結果を整理  

これにより、実装難易度と被験者確保の制約下でも、短期で成果が見込めるロードマップが完成します。
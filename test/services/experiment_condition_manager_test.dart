import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/experiment_condition_manager.dart';

void main() {
  group('ExperimentConditionManager - Latin Square Design', () {
    late ExperimentConditionManager manager;

    setUp(() {
      manager = ExperimentConditionManager();
    });

    test('generates 6 unique conditions', () {
      manager.initialize(participantNumber: 1);
      
      final conditions = manager.getAllConditions();
      expect(conditions.length, equals(6));
      
      // すべての条件がユニークであることを確認
      final uniqueIds = conditions.map((c) => c.id).toSet();
      expect(uniqueIds.length, equals(6));
    });

    test('covers all tempo control and cognitive load combinations', () {
      manager.initialize(participantNumber: 1);
      
      final conditions = manager.getAllConditions();
      
      // テンポ制御の組み合わせを確認
      final adaptiveConditions = conditions.where((c) => 
        c.tempoControl == TempoControl.adaptive).toList();
      final fixedConditions = conditions.where((c) => 
        c.tempoControl == TempoControl.fixed).toList();
      
      expect(adaptiveConditions.length, equals(3));
      expect(fixedConditions.length, equals(3));
      
      // 認知負荷の組み合わせを確認
      final nBack0 = conditions.where((c) => 
        c.cognitiveLoad == CognitiveLoad.nBack0).length;
      final nBack1 = conditions.where((c) => 
        c.cognitiveLoad == CognitiveLoad.nBack1).length;
      final nBack2 = conditions.where((c) => 
        c.cognitiveLoad == CognitiveLoad.nBack2).length;
      
      expect(nBack0, equals(2));
      expect(nBack1, equals(2));
      expect(nBack2, equals(2));
    });

    test('applies Latin square ordering based on participant number', () {
      // 異なる被験者番号で異なる順序になることを確認
      final orders = <List<String>>[];
      
      for (int i = 1; i <= 6; i++) {
        final tempManager = ExperimentConditionManager();
        tempManager.initialize(participantNumber: i);
        
        final order = tempManager.getAllConditions().map((c) => c.id).toList();
        orders.add(order);
      }
      
      // 各被験者の順序が異なることを確認
      for (int i = 0; i < orders.length; i++) {
        for (int j = i + 1; j < orders.length; j++) {
          expect(orders[i], isNot(equals(orders[j])));
        }
      }
      
      // ラテン方格の特性：各位置に各条件が1回ずつ現れる
      for (int position = 0; position < 6; position++) {
        final conditionsAtPosition = orders.map((order) => order[position]).toSet();
        expect(conditionsAtPosition.length, equals(6));
      }
    });

    test('maintains counterbalancing across participants', () {
      // 6人の被験者で各条件が各位置に均等に配置されることを確認
      final positionCounts = <String, Map<int, int>>{};
      
      for (int participant = 1; participant <= 6; participant++) {
        final tempManager = ExperimentConditionManager();
        tempManager.initialize(participantNumber: participant);
        
        final conditions = tempManager.getAllConditions();
        for (int position = 0; position < conditions.length; position++) {
          final conditionId = conditions[position].id;
          
          positionCounts[conditionId] ??= {};
          positionCounts[conditionId]![position] = 
              (positionCounts[conditionId]![position] ?? 0) + 1;
        }
      }
      
      // 各条件が各位置に正確に1回現れることを確認
      for (final conditionId in positionCounts.keys) {
        for (int position = 0; position < 6; position++) {
          expect(positionCounts[conditionId]![position], equals(1));
        }
      }
    });

    test('handles participant numbers beyond 6 with cyclic assignment', () {
      // 被験者番号7は被験者番号1と同じ順序になるべき
      manager.initialize(participantNumber: 7);
      final order7 = manager.getAllConditions().map((c) => c.id).toList();
      
      final manager1 = ExperimentConditionManager();
      manager1.initialize(participantNumber: 1);
      final order1 = manager1.getAllConditions().map((c) => c.id).toList();
      
      expect(order7, equals(order1));
      
      // 被験者番号13も被験者番号1と同じ
      final manager13 = ExperimentConditionManager();
      manager13.initialize(participantNumber: 13);
      final order13 = manager13.getAllConditions().map((c) => c.id).toList();
      
      expect(order13, equals(order1));
    });

    test('tracks progress correctly', () {
      manager.initialize(participantNumber: 1);
      
      // 初期状態
      var progress = manager.getProgress();
      expect(progress.completedBlocks, equals(0));
      expect(progress.totalBlocks, equals(6));
      expect(progress.progressPercentage, equals(0.0));
      expect(progress.currentCondition, isNotNull);
      
      // 1ブロック完了
      manager.completeCurrentBlock();
      progress = manager.getProgress();
      expect(progress.completedBlocks, equals(1));
      expect(progress.progressPercentage, closeTo(0.167, 0.001));
      
      // すべてのブロック完了
      for (int i = 1; i < 6; i++) {
        manager.completeCurrentBlock();
      }
      
      progress = manager.getProgress();
      expect(progress.completedBlocks, equals(6));
      expect(progress.progressPercentage, equals(1.0));
      expect(progress.isComplete, isTrue);
    });

    test('getCurrentCondition returns correct condition', () {
      manager.initialize(participantNumber: 1);
      
      final firstCondition = manager.getCurrentCondition();
      expect(firstCondition, isNotNull);
      
      // 次の条件に移動
      manager.completeCurrentBlock();
      final secondCondition = manager.getCurrentCondition();
      
      expect(secondCondition, isNotNull);
      expect(secondCondition, isNot(equals(firstCondition)));
    });

    test('handles reset correctly', () {
      manager.initialize(participantNumber: 1);
      
      // いくつかのブロックを完了
      manager.completeCurrentBlock();
      manager.completeCurrentBlock();
      
      expect(manager.getProgress().completedBlocks, equals(2));
      
      // リセット
      manager.reset();
      
      expect(manager.getProgress().completedBlocks, equals(0));
      expect(manager.getCurrentCondition(), isNotNull);
    });

    test('provides correct condition descriptions', () {
      manager.initialize(participantNumber: 1);
      
      final conditions = manager.getAllConditions();
      
      for (final condition in conditions) {
        // 説明が適切に設定されていることを確認
        expect(condition.description, isNotEmpty);
        
        if (condition.tempoControl == TempoControl.adaptive) {
          expect(condition.description, contains('適応'));
        } else {
          expect(condition.description, contains('固定'));
        }
        
        if (condition.cognitiveLoad == CognitiveLoad.nBack0) {
          expect(condition.description, contains('0-back'));
        } else if (condition.cognitiveLoad == CognitiveLoad.nBack1) {
          expect(condition.description, contains('1-back'));
        } else if (condition.cognitiveLoad == CognitiveLoad.nBack2) {
          expect(condition.description, contains('2-back'));
        }
      }
    });

    test('exports condition order for analysis', () {
      manager.initialize(participantNumber: 3);
      
      final exportData = manager.exportConditionOrder();
      
      expect(exportData['participantNumber'], equals(3));
      expect(exportData['conditions'], isA<List>());
      expect(exportData['conditions'].length, equals(6));
      
      // 各条件のエクスポートデータを確認
      for (int i = 0; i < exportData['conditions'].length; i++) {
        final condition = exportData['conditions'][i];
        expect(condition['order'], equals(i + 1));
        expect(condition['id'], isNotEmpty);
        expect(condition['tempoControl'], isNotEmpty);
        expect(condition['cognitiveLoad'], isNotEmpty);
      }
    });
  });
}
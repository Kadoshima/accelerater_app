import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/nback_sequence_generator.dart';

void main() {
  group('NBackSequenceGenerator', () {
    late NBackSequenceGenerator generator;

    setUp(() {
      generator = NBackSequenceGenerator();
    });

    test('generates sequence with correct length', () {
      final sequence = generator.generate(length: 10, nLevel: 2);
      expect(sequence.length, equals(10));
    });

    test('generates digits within specified range', () {
      final sequence = generator.generate(
        length: 50,
        nLevel: 1,
        minDigit: 1,
        maxDigit: 9,
      );
      
      for (final digit in sequence) {
        expect(digit, greaterThanOrEqualTo(1));
        expect(digit, lessThanOrEqualTo(9));
      }
    });

    test('ensures n-back targets exist for n-back > 0', () {
      final sequence = generator.generate(length: 20, nLevel: 1);
      
      // 1-back: 少なくとも1つの連続する同じ数字があるべき
      bool hasTarget = false;
      for (int i = 1; i < sequence.length; i++) {
        if (sequence[i] == sequence[i - 1]) {
          hasTarget = true;
          break;
        }
      }
      expect(hasTarget, isTrue, reason: '1-back sequence should have at least one target');
    });

    test('ensures n-back targets for 2-back', () {
      final sequence = generator.generate(length: 30, nLevel: 2);
      
      // 2-back: 少なくとも1つの2つ前と同じ数字があるべき
      bool hasTarget = false;
      for (int i = 2; i < sequence.length; i++) {
        if (sequence[i] == sequence[i - 2]) {
          hasTarget = true;
          break;
        }
      }
      expect(hasTarget, isTrue, reason: '2-back sequence should have at least one target');
    });

    test('0-back generates valid sequence', () {
      final sequence = generator.generate(length: 15, nLevel: 0);
      expect(sequence.length, equals(15));
      
      // 0-backでは最初の数字がターゲット
      final firstDigit = sequence.first;
      expect(firstDigit, greaterThanOrEqualTo(1));
      expect(firstDigit, lessThanOrEqualTo(9));
    });

    test('throws exception for invalid parameters', () {
      expect(
        () => generator.generate(length: -1, nLevel: 1),
        throwsA(isA<AssertionError>()),
      );
      
      expect(
        () => generator.generate(length: 10, nLevel: -1),
        throwsA(isA<AssertionError>()),
      );
      
      expect(
        () => generator.generate(length: 10, nLevel: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('generates different sequences on multiple calls', () {
      final sequence1 = generator.generate(length: 20, nLevel: 1);
      final sequence2 = generator.generate(length: 20, nLevel: 1);
      
      // 確率的に異なるはず（完全一致の確率は極めて低い）
      expect(sequence1, isNot(equals(sequence2)));
    });

    test('respects minimum target frequency', () {
      const int sequenceLength = 100;
      const int nLevel = 1;
      final sequence = generator.generate(length: sequenceLength, nLevel: nLevel);
      
      int targetCount = 0;
      for (int i = nLevel; i < sequence.length; i++) {
        if (sequence[i] == sequence[i - nLevel]) {
          targetCount++;
        }
      }
      
      // ターゲットは少なくとも20%以上出現すべき
      final targetRatio = targetCount / (sequenceLength - nLevel);
      expect(targetRatio, greaterThanOrEqualTo(0.2));
    });
  });

  group('NBackSequenceGenerator - Response Validation', () {
    test('correctly validates n-back responses', () {
      final sequence = [1, 3, 5, 3, 7, 5, 2, 7, 1, 2];
      
      // 1-back tests
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 3,
          nLevel: 1,
          response: 3,
        ),
        isTrue,
      ); // 3 == 3
      
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 4,
          nLevel: 1,
          response: 3,
        ),
        isFalse,
      ); // 7 != 3
      
      // 2-back tests
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 5,
          nLevel: 2,
          response: 3,
        ),
        isTrue,
      ); // 5 matches position 3
      
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 7,
          nLevel: 2,
          response: 5,
        ),
        isTrue,
      ); // 7 matches position 5
      
      // 0-back test (always compare with first digit)
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 8,
          nLevel: 0,
          response: 1,
        ),
        isTrue,
      ); // matches first digit
    });

    test('handles edge cases in response validation', () {
      final sequence = [5, 2, 8, 2, 5];
      
      // Index before n-back is possible
      expect(
        NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 0,
          nLevel: 1,
          response: null,
        ),
        isTrue,
      ); // No response expected
      
      // Invalid index
      expect(
        () => NBackSequenceGenerator.isCorrectResponse(
          sequence: sequence,
          currentIndex: 10,
          nLevel: 1,
          response: 5,
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('NBackSequenceGenerator - Statistics', () {
    test('calculates correct accuracy', () {
      final responses = [
        (stimulus: 1, response: null, isCorrect: true),
        (stimulus: 3, response: 1, isCorrect: true),
        (stimulus: 3, response: 3, isCorrect: false),
        (stimulus: 5, response: 3, isCorrect: true),
        (stimulus: 7, response: 3, isCorrect: false),
      ];
      
      final accuracy = NBackSequenceGenerator.calculateAccuracy(responses);
      expect(accuracy, equals(0.6)); // 3/5 = 0.6
    });

    test('calculates correct response time statistics', () {
      final responseTimes = [500, 600, 400, 800, 700];
      
      final stats = NBackSequenceGenerator.calculateResponseTimeStats(responseTimes);
      expect(stats['mean'], equals(600.0));
      expect(stats['median'], equals(600.0));
      expect(stats['min'], equals(400));
      expect(stats['max'], equals(800));
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:koperasi_app/services/app_update_service.dart';

void main() {
  group('SemanticVersion Unit Tests', () {
    test('1.9.0 vs 1.10.0 integer comparison prevents string ordering bug', () {
      final v1 = SemanticVersion.parse('1.9.0');
      final v2 = SemanticVersion.parse('1.10.0');

      // In plain string comparison, '1.9.0' > '1.10.0' would be true (WRONG!).
      // With SemanticVersion integer comparison:
      expect(v1.isLowerThan(v2), isTrue);
      expect(v2.isGreaterThan(v1), isTrue);
      expect(v1.compareTo(v2), lessThan(0));
    });

    test('Identical versions should be equal', () {
      final v1 = SemanticVersion.parse('1.0.0');
      final v2 = SemanticVersion.parse('1.0.0');

      expect(v1.compareTo(v2), equals(0));
      expect(v1 == v2, isTrue);
      expect(v1.isLowerThan(v2), isFalse);
      expect(v1.isGreaterThan(v2), isFalse);
      expect(v1.isAtLeast(v2), isTrue);
    });

    test('Major version upgrade (2.0.0 vs 1.99.99)', () {
      final v1 = SemanticVersion.parse('2.0.0');
      final v2 = SemanticVersion.parse('1.99.99');

      expect(v1.isGreaterThan(v2), isTrue);
      expect(v2.isLowerThan(v1), isTrue);
    });

    test('Patch version upgrade (1.0.1 vs 1.0.0)', () {
      final v1 = SemanticVersion.parse('1.0.1');
      final v2 = SemanticVersion.parse('1.0.0');

      expect(v1.isGreaterThan(v2), isTrue);
      expect(v2.isLowerThan(v1), isTrue);
    });

    test('Build numbers comparison (1.0.0+2 vs 1.0.0+1)', () {
      final v1 = SemanticVersion.parse('1.0.0+2');
      final v2 = SemanticVersion.parse('1.0.0+1');

      expect(v1.isGreaterThan(v2), isTrue);
      expect(v2.isLowerThan(v1), isTrue);
    });

    test('Tolerates prefix v (v1.2.3 vs 1.2.3)', () {
      final v1 = SemanticVersion.parse('v1.2.3');
      final v2 = SemanticVersion.parse('1.2.3');

      expect(v1 == v2, isTrue);
      expect(v1.compareTo(v2), equals(0));
    });

    test('Tolerates malformed and empty version strings gracefully', () {
      final emptyVer = SemanticVersion.parse('');
      final invalidVer = SemanticVersion.parse('invalid-version');

      expect(emptyVer.major, equals(0));
      expect(emptyVer.minor, equals(0));
      expect(emptyVer.patch, equals(0));

      expect(invalidVer.major, equals(0));
      expect(invalidVer.minor, equals(0));
      expect(invalidVer.patch, equals(0));
    });

    test('Handles short version strings like 1.2', () {
      final v = SemanticVersion.parse('1.2');
      expect(v.major, equals(1));
      expect(v.minor, equals(2));
      expect(v.patch, equals(0));
    });
  });
}

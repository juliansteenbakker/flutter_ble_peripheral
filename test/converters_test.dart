import 'dart:typed_data';

import 'package:flutter_ble_peripheral/src/models/map_uint8list_converter.dart';
import 'package:flutter_ble_peripheral/src/models/uint8list_converter.dart';
import 'package:flutter_ble_peripheral/src/models/uint8list_map_string_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Uint8ListConverter', () {
    const converter = Uint8ListConverter();

    test('round trips a byte list', () {
      final bytes = Uint8List.fromList([0, 1, 255]);
      expect(converter.toJson(bytes), [0, 1, 255]);
      expect(converter.fromJson([0, 1, 255]), bytes);
    });

    test('passes null through', () {
      expect(converter.fromJson(null), isNull);
      expect(converter.toJson(null), isNull);
    });

    // The platform channel hands back List<dynamic>, not List<int>.
    test('accepts a dynamically typed list', () {
      expect(converter.fromJson(<dynamic>[1, 2]), Uint8List.fromList([1, 2]));
    });
  });

  group('Uint8ListMapIntConverter', () {
    const converter = Uint8ListMapIntConverter();

    test('parses string keys as ints', () {
      final decoded = converter.fromJson({
        '76': <dynamic>[1, 2],
        '65535': <dynamic>[3],
      });

      expect(decoded, {
        76: Uint8List.fromList([1, 2]),
        65535: Uint8List.fromList([3]),
      });
    });

    test('encodes int keys back to strings', () {
      final encoded = converter.toJson({
        76: Uint8List.fromList([1, 2]),
      });

      expect(encoded, {
        '76': const [1, 2],
      });
    });

    test('passes null through', () {
      expect(converter.fromJson(null), isNull);
      expect(converter.toJson(null), isNull);
    });

    test('throws on a key that is not an int', () {
      expect(
        () => converter.fromJson({
          'not-an-int': <dynamic>[1],
        }),
        throwsFormatException,
      );
    });
  });

  group('Uint8ListMapStringConverter', () {
    const converter = Uint8ListMapStringConverter();

    test('round trips service data keyed by UUID', () {
      const uuid = '0000feaa-0000-1000-8000-00805f9b34fb';
      final decoded = converter.fromJson({
        uuid: <dynamic>[16, 32],
      });

      expect(decoded, {
        uuid: Uint8List.fromList([16, 32]),
      });
      expect(converter.toJson(decoded), {
        uuid: const [16, 32],
      });
      // Not a Uint8List: the method channel encodes one as a byte array rather
      // than a list, and a plain int list is what the platform side reads.
      expect(converter.toJson(decoded)![uuid], isNot(isA<Uint8List>()));
    });

    test('passes null through', () {
      expect(converter.fromJson(null), isNull);
      expect(converter.toJson(null), isNull);
    });
  });
}

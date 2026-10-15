import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late KeyStorageService keyStorageService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    keyStorageService = KeyStorageService(storage: mockStorage);
  });

  group('KeyStorageService', () {
    test('returns existing 32-byte key when already stored', () async {
      final sampleKeyBytes = Uint8List.fromList(List.generate(32, (i) => i));
      final base64Key = base64Encode(sampleKeyBytes);

      when(() => mockStorage.read(key: KeyStorageService.kDbEncryptionKeyName))
          .thenAnswer((_) async => base64Key);

      final result = await keyStorageService.getOrCreateEncryptionKey();

      expect(result, equals(sampleKeyBytes));
      verify(() => mockStorage.read(key: KeyStorageService.kDbEncryptionKeyName))
          .called(1);
      verifyNever(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });

    test('generates and stores new 32-byte key when not present', () async {
      when(() => mockStorage.read(key: KeyStorageService.kDbEncryptionKeyName))
          .thenAnswer((_) async => null);
      when(() => mockStorage.write(
            key: KeyStorageService.kDbEncryptionKeyName,
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final result = await keyStorageService.getOrCreateEncryptionKey();

      expect(result.length, equals(32));
      verify(() => mockStorage.read(key: KeyStorageService.kDbEncryptionKeyName))
          .called(1);
      verify(() => mockStorage.write(
            key: KeyStorageService.kDbEncryptionKeyName,
            value: any(named: 'value'),
          )).called(1);
    });

    test('regenerates new key when stored key is corrupted or not 32 bytes', () async {
      // 16 bytes instead of 32
      final shortKey = base64Encode(Uint8List(16));
      when(() => mockStorage.read(key: KeyStorageService.kDbEncryptionKeyName))
          .thenAnswer((_) async => shortKey);
      when(() => mockStorage.write(
            key: KeyStorageService.kDbEncryptionKeyName,
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final result = await keyStorageService.getOrCreateEncryptionKey();

      expect(result.length, equals(32));
      verify(() => mockStorage.write(
            key: KeyStorageService.kDbEncryptionKeyName,
            value: any(named: 'value'),
          )).called(1);
    });

    test('hasEncryptionKey delegates to storage containsKey', () async {
      when(() => mockStorage.containsKey(key: KeyStorageService.kDbEncryptionKeyName))
          .thenAnswer((_) async => true);

      final hasKey = await keyStorageService.hasEncryptionKey();

      expect(hasKey, isTrue);
      verify(() => mockStorage.containsKey(key: KeyStorageService.kDbEncryptionKeyName))
          .called(1);
    });

    test('clearEncryptionKey deletes key from storage', () async {
      when(() => mockStorage.delete(key: KeyStorageService.kDbEncryptionKeyName))
          .thenAnswer((_) async {});

      await keyStorageService.clearEncryptionKey();

      verify(() => mockStorage.delete(key: KeyStorageService.kDbEncryptionKeyName))
          .called(1);
    });
  });
}

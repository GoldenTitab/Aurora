import 'package:aurora/data/services/bulk_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BulkImportParser', () {
    test('txt: یک عنوان در هر خط، خط خالی و کامنت نادیده', () {
      const c = 'Attack on Titan\n\n# کامنت\nDeath Note  \n';
      final out = BulkImportParser.parse(c, 'txt');
      expect(out, ['Attack on Titan', 'Death Note']);
    });

    test('txt: سال داخل پرانتز حذف می‌شود', () {
      const c = 'Naruto (2002)\nOne Piece [1999]';
      final out = BulkImportParser.parse(c, 'txt');
      expect(out, ['Naruto', 'One Piece']);
    });

    test('csv: ستون عنوان از هدر پیدا می‌شود', () {
      const c = 'title,score\nAttack on Titan,9\nDeath Note,8';
      final out = BulkImportParser.parse(c, 'csv');
      expect(out, ['Attack on Titan', 'Death Note']);
    });

    test('csv: بدون هدر، ستون اول', () {
      const c = 'Attack on Titan\nDeath Note';
      final out = BulkImportParser.parse(c, 'csv');
      expect(out, ['Attack on Titan', 'Death Note']);
    });

    test('csv: کوتیشن و کاما داخل عنوان', () {
      const c = 'title\n"JoJo\'s Bizarre, Adventure"\nBleach';
      final out = BulkImportParser.parse(c, 'csv');
      expect(out, ["JoJo's Bizarre, Adventure", 'Bleach']);
    });

    test('json: لیست رشته‌ها', () {
      const c = '["Attack on Titan", "Death Note"]';
      expect(BulkImportParser.parse(c, 'json'), [
        'Attack on Titan',
        'Death Note',
      ]);
    });

    test('json: لیست آبجکت‌ها با کلید title', () {
      const c = '[{"title": "Naruto"}, {"name": "Bleach"}]';
      expect(BulkImportParser.parse(c, 'json'), ['Naruto', 'Bleach']);
    });

    test('json: آبجکت با کلید anime', () {
      const c = '{"anime": ["One Piece", "Naruto"]}';
      expect(BulkImportParser.parse(c, 'json'), ['One Piece', 'Naruto']);
    });

    test('confident: تطبیق دقیق و زیررشته', () {
      expect(
        BulkImportParser.confident(
          'Attack on Titan',
          'Attack on Titan',
          'Shingeki no Kyojin',
        ),
        isTrue,
      );
      expect(
        BulkImportParser.confident('Naruto', 'Naruto Shippuden', 'ناروتو'),
        isTrue,
      );
      expect(
        BulkImportParser.confident('Bleach', 'One Piece', 'وان پیس'),
        isFalse,
      );
    });
  });
}

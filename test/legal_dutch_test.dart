// Every paragraph of the terms and the privacy policy has its Dutch
// version: a changed English sentence must not quietly fall back to English.
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/i18n_nl.dart';
import 'package:vriendtime/src/screens/legal_document_screen.dart';

void main() {
  test('the legal texts are fully in Dutch', () {
    for (final type in LegalDocumentType.values) {
      final doc = LegalDocuments.documentFor(type);
      final texts = [
        doc.title,
        doc.introduction,
        for (final s in doc.sections) ...[s.heading, ...s.paragraphs],
      ];
      for (final text in texts) {
        expect(nlStrings.containsKey(text), isTrue,
            reason:
                'no Dutch for: ${text.substring(0, text.length.clamp(0, 80))}');
      }
    }
  });
}

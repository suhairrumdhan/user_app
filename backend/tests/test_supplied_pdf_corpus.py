"""Optional local corpus check; no prescription or patient data is stored here."""

import json
import os
from pathlib import Path
import unittest


# Medicine identities visually checked against the 31 supplied digital PDFs.
# The positions follow the sorted PDF filenames, but the filenames stay local.
EXPECTED_NAMES = [
    ['ciprobay'],
    ['augmentin', 'panadol', 'tamoxifen', 'trido', 'dostinex'],
    ['ciprobay', 'treto', 'fybogyl', 'panadol'],
    ['omnic', 'ciprobay', 'treto', 'vesicare', 'rociphine'],
    ['divide', 'augmentin', 'femara', 'strongstart lp'],
    ['amoclan', 'divido', 'trido', 'tamoxfen', 'dostinex', 'pregnyl'],
    ['augmentin', 'voltaren', 'trido', 'tamoxifen', 'dostinex'],
    ['ciprobay', 'panadol'],
    ['suprax'],
    ['vancomycin', 'rociphen', 'votrex', 'pantoprazol', 'augmentin'],
    ['ciprobay', 'votrex'],
    ['vancomycin', 'rociphen', 'votrex', 'pantoprazol', 'augmentin'],
    ['ciprobay', 'treto', 'omnic'],
    ['ciprobay', 'panadol'],
    ['ciprobay', 'panadol'],
    ['ciprobay', 'spasmex'],
    ['augmentin', 'voltaren'],
    ['augmentin', 'gentamicin', 'omeprazol', 'panadol', 'ciprobay', 'treto'],
    ['ciprobay', 'doliprane', 'treto', 'omnic'],
    ['ciprobay', 'omnic'],
    ['omnic', 'ciprobay'],
    ['omnic', 'ciprobay'],
    ['ciprobay', 'treto', 'divide', 'omnic', 'omeprazole'],
    ['divido 75', 'augmentin', 'dostenix', 'femara', 'strongstart lp'],
    ['ciprobay', 'voltaren'],
    ['ciprobay'],
    ['ciprobay', 'treto', 'omnic'],
    ['ciprobay', 'doliprane', 'omeprazole sandoz', 'treto', 'omnic'],
    ['ciprobay', 'treto', 'vesicare', 'panadol'],
    ['rociphen', 'ciprobay', 'panadol', 'augmentin'],
    ['ciprobay', 'omnic'],
]


class SuppliedPdfCorpusTest(unittest.TestCase):
    @unittest.skipUnless(os.getenv('PRESCRIPTION_CORPUS_OUTPUT'),
                         'No local Flutter PDF extraction supplied')
    def test_production_extraction_through_document_endpoint(self):
        from app import app

        documents = json.loads(Path(os.environ['PRESCRIPTION_CORPUS_OUTPUT'])
                               .read_text(encoding='utf-8'))
        self.assertEqual(len(documents), len(EXPECTED_NAMES))
        client = app.test_client()
        for index, (document, expected) in enumerate(zip(documents, EXPECTED_NAMES), 1):
            with self.subTest(pdf=index):
                response = client.post('/analyze-prescription', json={
                    'text': document['text'], 'inputMode': 'document',
                })
                self.assertEqual(response.status_code, 200)
                self.assertEqual([item['sourceName'] for item in response.json['items']],
                                 expected)
                self.assertEqual(response.json['uncertainText'], [])
        self.assertEqual(sum(map(len, EXPECTED_NAMES)), 103)


if __name__ == '__main__':
    unittest.main()

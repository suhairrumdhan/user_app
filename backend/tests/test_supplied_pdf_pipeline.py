"""Optional real-file integration, after the production Flutter extractor test."""
import os
from pathlib import Path
import unittest


class SuppliedPdfPipelineTest(unittest.TestCase):
    @unittest.skipUnless(os.getenv('PRESCRIPTION_EXTRACTED_TEXT'), 'No local extracted PDF supplied')
    def test_two_medication_pdf_through_actual_mobile_endpoint(self):
        from app import app
        text = Path(os.environ['PRESCRIPTION_EXTRACTED_TEXT']).read_text(encoding='utf-8')
        response = app.test_client().post('/analyze-prescription',
                                         json={'text': text, 'inputMode': 'document'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual([m['sourceText'] for m in response.json['items']],
                         ['Omnic 0.4 mg cap', 'Ciprobay tab 500 mg'])
        self.assertEqual(response.json['uncertainText'], [])
        self.assertNotIn('tricox', str(response.json).lower())


if __name__ == '__main__':
    unittest.main()

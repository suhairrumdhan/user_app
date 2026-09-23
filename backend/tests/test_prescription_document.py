"""Regression fixtures include the whole document, not just medication lines."""
from pathlib import Path
import unittest

from services.analyzer import analyze_text
from services.dictionary_builder import load_catalog, build_search_index

MEDICINES = """Augmentin 1 g Tab 1X 2X 5Days
Panadol Tab 500 mg 2x 3x 3days
Tamoxifen 20 mg tab 1X 1X 2months
Trido tab 1X 2X 3months
Dostinex 0.5 mg tab 1/ every 3 days 6 tab"""
NAMES = ["augmentin", "panadol", "tamoxifen", "trido", "dostinex"]

# Patient/doctor values are deliberately synthetic, not copied personal data.
FULL_DOCUMENT = """Test International Hospital
وصفة طبية
Name:
اسم المريض للاختبار
Age:
48
years old
Rx:
""" + MEDICINES + """
Dr. Test Prescriber, MD.
Urology Specialist
29/07/2023"""


class PrescriptionDocumentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load_catalog(str(Path(__file__).resolve().parents[1] / "data"))
        cls.index = build_search_index(cls.catalog)

    def analyze(self, text, **options):
        return analyze_text(text, self.catalog, self.index, **options)

    def assert_five_medications(self, result):
        self.assertEqual([m["sourceName"] for m in result["items"]], NAMES)
        self.assertEqual(len(result["medicines"]), 4)
        self.assertEqual([m["sourceName"] for m in result["unmatchedLines"]], ["trido"])
        self.assertEqual(result["items"][1]["strength"], "500 mg")
        self.assertEqual(result["items"][-1]["strength"], "0.5 mg")

    def test_full_prescription_including_patient_doctor_age_and_date(self):
        self.assert_five_medications(self.analyze(FULL_DOCUMENT))

    def test_exact_nine_displayed_items_from_report_reduce_to_five(self):
        # The screenshot had no visible field labels attached to the garbage.
        text = "وصفة طبية\nاسم المريض للاختبار\nyears old\n" + MEDICINES + "\n2023/"
        result = self.analyze(text)
        self.assert_five_medications(result)
        self.assertNotRegex(result["cleanedText"], r"[\u0600-\u06ff]")
        self.assertNotIn("years old", result["cleanedText"])
        self.assertNotIn("2023", result["cleanedText"])

    def test_latin_patient_name_and_split_doctor_footer_are_not_medicines(self):
        text = FULL_DOCUMENT.replace("اسم المريض للاختبار", "John Example Patient")
        text = text.replace("Dr. Test Prescriber, MD.", "Dr.\nJames Example\nMD.")
        self.assert_five_medications(self.analyze(text))

    def test_missing_rx_and_missing_name_label_still_exclude_prefix_and_footer(self):
        text = "Test Hospital\nJohn Example Patient\n48 years old\n" + MEDICINES + "\nDoctor\nJames Example\n2023/"
        self.assert_five_medications(self.analyze(text))

    def test_numeric_date_fragments_and_age_fragments_do_not_become_medicines(self):
        for value in ["2023/", "29/07/2023", "2 9/0 7/2023", "48", "years old", "48 years old", "48 yrs"]:
            with self.subTest(value=value):
                self.assertEqual(self.analyze(value)["items"], [])
                self.assertEqual(self.analyze(value, manual_input=True)["items"], [])

    def test_no_medication_result_from_header_and_footer_only(self):
        text = "Test Hospital\nName\nJohn Example\nAge\n48\nyears old\nRx\nDr.\nJames Example\n2023/"
        self.assertEqual(self.analyze(text)["items"], [])

    def test_arabic_is_excluded_even_with_english_units(self):
        result = self.analyze("وصفة طبية\nدواء عربي 500 mg tab")
        self.assertEqual(result["items"], [])
        result = self.analyze("دواء Augmentin 1g tab بعد الأكل")
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(result["items"][0]["sourceText"], "Augmentin 1g tab")
        self.assertNotRegex(str(result["items"]), r"[\u0600-\u06ff]")

    def test_unknown_name_inside_rx_section_is_retained_without_inventing_match(self):
        result = self.analyze("Name\nJohn Example\nRx:\nUncataloguedBrand\nDr. Example")
        self.assertEqual(result["items"], [])
        self.assertEqual([r["text"] for r in result["uncertainText"]], ["UncataloguedBrand"])

    def test_unknown_name_between_medication_lines_is_preserved(self):
        result = self.analyze("Augmentin 1g tab\nUncataloguedBrand\nPanadol 500mg tab")
        self.assertEqual([m["sourceText"] for m in result["items"]],
                         ["Augmentin 1g tab", "UncataloguedBrand", "Panadol 500mg tab"])
        self.assertTrue(result["items"][1]["needsReview"])
        self.assertEqual(result["uncertainText"], [])

    def test_manual_product_list_keeps_unknown_names_without_document_context(self):
        result = self.analyze("UncataloguedBrand\nUnknown Cosmetic Serum", manual_input=True)
        self.assertEqual(len(result["items"]), 2)
        self.assertTrue(all(m["needsReview"] for m in result["items"]))

    def test_rx_inline_and_next_page_do_not_leak_footer_names(self):
        text = "Rx: Augmentin 1g tab\nDr. Example\nPage Hospital\nRx:\nTrido tab\nDr. Another"
        self.assertEqual([m["sourceName"] for m in self.analyze(text)["items"]], ["augmentin", "trido"])

    def test_current_mobile_endpoint_receives_only_five_items(self):
        from app import app
        result = app.test_client().post("/analyze-prescription", json={"text": FULL_DOCUMENT})
        self.assertEqual(result.status_code, 200)
        self.assert_five_medications(result.json)
        self.assertEqual(app.test_client().get("/health").json["inputPolicy"], "spatial-rows-evidence-v5")

    def test_second_document_and_legacy_scrambled_fragments_yield_two_medicines(self):
        examples = [
            'Test Hospital\nName: Test Patient Age 70 years old\nRx:\n'
            'الاصليOmnic 0.4 mg cap 2x1x5 days then 1x1x30days at Bed time\n'
            'الاصليCiprobay tab 500mg 1x2x10days\n'
            'Assistant Prof. Dr. Test Doctor MD\nUrology Specialist\n19/12/2024',
            'Rx:\nat Bed time\nx30days\n1x1\nthen\n'
            'Omnic 0.4 mg cap 2x1x5 days\nCiprobay tab 500mg 1x2x10days\n.Assistant Prof',
        ]
        for text in examples:
            result = self.analyze(text, document_input=True)
            self.assertEqual([m['sourceName'] for m in result['items']], ['omnic', 'ciprobay'])
            self.assertEqual([m['strength'] for m in result['items']], ['0.4 mg', '500 mg'])
            self.assertEqual(result['uncertainText'], [])

    def test_unknown_text_has_no_automatic_drug_status_even_inside_rx(self):
        result = self.analyze('Rx:\nSome heading\nReturn next Tuesday\nUnknownBrand\nTrido tab', document_input=True)
        self.assertEqual([m['sourceName'] for m in result['items']], ['trido'])
        self.assertEqual(result['medicines'], [])
        self.assertEqual([r['text'] for r in result['uncertainText']],
                         ['Some heading', 'Return next Tuesday', 'UnknownBrand'])

    def test_instruction_grammar_and_footer_titles_not_only_reported_words(self):
        for text in ['after breakfast', 'with food', 'before sleep', 'once daily', 'x 14weeks',
                     'then', '1 tab at night', 'as needed', 'Prof.', 'Associate Professor']:
            with self.subTest(text=text):
                result = self.analyze('Rx:\n' + text, document_input=True)
                self.assertEqual(result['items'], [])
                self.assertEqual(result['uncertainText'], [])
        result = self.analyze('Rx:\nThenex 5 mg tab\nDailycare cream')
        self.assertEqual(len(result['items']), 2)

    def test_wrapped_strengths_and_numbered_list_without_rx(self):
        result = self.analyze('1. Omnic\n0.4mg cap\n2. Ciprobay\n500mg tab', document_input=True)
        self.assertEqual([m['sourceName'] for m in result['items']], ['omnic', 'ciprobay'])
        self.assertEqual([m['strength'] for m in result['items']], ['0.4 mg', '500 mg'])
        result = self.analyze('Omeprazole\n"Sandoz"\n40mg cap', document_input=True)
        self.assertEqual(result['items'][0]['sourceName'], 'omeprazole')

    def test_no_strength_join_across_region_or_page_or_patient_label(self):
        for separator in ['\n\n', '\n\f\n', '\nName:\nTest Patient\n']:
            result = self.analyze('UnknownBrand' + separator + '20mg', document_input=True)
            self.assertEqual(result['items'], [])
            self.assertEqual(result['uncertainText'][0]['text'], 'UnknownBrand')
        result = self.analyze('Name:\nTest Patient\n20mg\nRx:\nTrido tab', document_input=True)
        self.assertEqual([m['sourceName'] for m in result['items']], ['trido'])

    def test_explicit_manual_and_document_modes_differ_only_in_candidate_selection(self):
        from app import app
        client = app.test_client()
        doc = client.post('/analyze-prescription', json={'text': 'UnknownBrand', 'inputMode': 'document'}).json
        manual = client.post('/analyze-prescription', json={'text': 'UnknownBrand', 'inputMode': 'manual'}).json
        self.assertEqual(doc['items'], [])
        self.assertEqual(doc['uncertainText'][0]['text'], 'UnknownBrand')
        self.assertTrue(manual['items'][0]['needsReview'])
        self.assertEqual(client.post('/analyze-prescription', json={'text': 'x', 'inputMode': 'bad'}).status_code, 400)

    def test_bare_unknown_name_with_directions_keeps_api_shape(self):
        from app import app
        response = app.test_client().post('/analyze-prescription', json={
            'inputMode': 'document',
            'text': 'Name:\nJane Example\nRx:\nSome heading\nNewbrand\n1x2x5days\nDr. Example',
        }).json
        self.assertEqual([m['sourceName'] for m in response['items']], ['newbrand'])
        self.assertEqual(response['medicines'], [])
        self.assertEqual([m['sourceName'] for m in response['unmatchedLines']], ['newbrand'])
        self.assertEqual(response['items'][0]['reviewReasons'], ['no_match'])
        self.assertEqual([r['text'] for r in response['uncertainText']], ['Some heading'])

    def test_bare_words_without_independent_evidence_stay_uncertain(self):
        result = self.analyze('Rx:\nHeading\nAdvice\nUnknownBrand\nDr. Example',
                              document_input=True)
        self.assertEqual(result['items'], [])
        self.assertEqual([r['text'] for r in result['uncertainText']],
                         ['Heading', 'Advice', 'UnknownBrand'])

    def test_inline_rx_bare_name_is_review_only(self):
        result = self.analyze('Rx: Newbrand\nTake 1 tab daily', document_input=True)
        self.assertEqual([m['sourceName'] for m in result['items']], ['newbrand'])
        self.assertEqual(result['medicines'], [])
        self.assertTrue(result['items'][0]['needsReview'])

    def test_heading_before_generic_instruction_is_not_promoted(self):
        result = self.analyze('Rx:\nHeading\nTake daily', document_input=True)
        self.assertEqual(result['items'], [])
        self.assertEqual([r['text'] for r in result['uncertainText']], ['Heading'])

    def test_pdf_glued_schedule_and_wrapped_details_restore_four_rows(self):
        # Synthetic transcription of the failure visible in the user screenshots.
        # It does not contain the patient's or doctor's identifying details.
        text = ('Rx:\nCiprobay\ntab 500mg1x2x5daysTreto\n'
                'Cap 1X2X15days\nFybogyl Sachets 1x2x5days\n'
                'Panadol Tab 500mg 2x3x3days')
        result = self.analyze(text, document_input=True)
        self.assertEqual([item['sourceName'] for item in result['items']],
                         ['ciprobay', 'treto', 'fybogyl', 'panadol'])
        self.assertEqual(result['items'][0]['strength'], '500 mg')
        self.assertEqual(result['items'][0]['dosageForm'], 'tab')
        self.assertEqual(result['items'][1]['dosageForm'], 'cap')
        self.assertTrue(result['items'][1]['needsReview'])
        self.assertTrue(result['items'][2]['needsReview'])
        self.assertEqual(result['uncertainText'], [])

    def test_glued_then_before_a_brand_keeps_both_medicines(self):
        text = ('Rx:\nat Bed time x30days 1x1 thenOmnic 0.4 mg cap 2x1x5 days\n'
                'Ciprobay tab 500mg 1x2x10days')
        result = self.analyze(text, document_input=True)
        self.assertEqual([item['sourceName'] for item in result['items']],
                         ['omnic', 'ciprobay'])
        self.assertEqual(result['uncertainText'], [])


if __name__ == "__main__":
    unittest.main()

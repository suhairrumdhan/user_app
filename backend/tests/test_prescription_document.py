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
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(result["items"][0]["sourceText"], "UncataloguedBrand")
        self.assertTrue(result["items"][0]["needsReview"])

    def test_unknown_name_between_medication_lines_is_preserved(self):
        result = self.analyze("Augmentin 1g tab\nUncataloguedBrand\nPanadol 500mg tab")
        self.assertEqual([m["sourceText"] for m in result["items"]],
                         ["Augmentin 1g tab", "UncataloguedBrand", "Panadol 500mg tab"])

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
        self.assertEqual(app.test_client().get("/health").json["inputPolicy"], "english-medication-lines-v1")


if __name__ == "__main__":
    unittest.main()

import hashlib
import json
from pathlib import Path
import unittest

from services.analyzer import analyze_text
from services.dictionary_builder import load_catalog, build_search_index
from services.matcher import select_final_match
from services.normalization import (
    normalize_text, clean_brand_name, extract_strength, extract_dosage_form,
)
from tools.import_rxterms import convert_rows

DATA = Path(__file__).resolve().parents[1] / "data"


def record(name):
    return {"id": name, "raw_name": name, "brand_name": clean_brand_name(name),
            "normalized_full": normalize_text(name), "strength": extract_strength(name),
            "dosage_form": extract_dosage_form(name)}


def analyze(source, names):
    dictionary = [record(name) for name in names]
    return analyze_text(source, dictionary, build_search_index(dictionary))


class MatchingSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load_catalog(str(DATA))
        cls.index = build_search_index(cls.catalog)

    def test_real_five_line_regression_preserves_source_not_tricox(self):
        source = (
            "Augmentin 1g Tab 1X2X5Days\nPanadol Tab 500mg 2x3x3days\n"
            "Tamoxifen 20mg tab 1X1X2months\nTrido tab 1X2X3months\n"
            "Dostinex 0.5mg tab 1/ every 3 days 6 tablets"
        )
        result = analyze_text(source, self.catalog, self.index)
        self.assertEqual(len(result["medicines"]), 4)
        self.assertEqual([m["sourceName"] for m in result["items"]],
                         ["augmentin", "panadol", "tamoxifen", "trido", "dostinex"])
        self.assertEqual(result["unmatchedLines"][0]["sourceName"], "trido")
        self.assertEqual(result["items"][1]["strength"], "500 mg")
        self.assertIn("500", result["items"][1]["matchedDisplayName"])
        self.assertEqual(result["items"][3]["sourceText"], "Trido tab")
        self.assertNotIn("tricox", str(result["medicines"]).lower())

    def test_fuzzy_match_never_enters_accepted_medicines(self):
        result = analyze("Panadoll 500mg tab", ["Panadol 500mg tab"])
        self.assertEqual(result["medicines"], [])
        item = result["unmatchedLines"][0]
        self.assertEqual(item["sourceName"], "panadoll")
        self.assertIn("spelling_suggestion", item["reviewReasons"])
        self.assertEqual(item["suggestions"][0]["name"], "Panadol 500mg tab")

    def test_preserves_modifiers_and_does_not_drop_to_shared_first_word(self):
        for source, available in [
            ("Panadol 500mg tab", "Panadol Extra 500mg tab"),
            ("Panadol + 500mg tab", "Panadol 500mg tab"),
            ("Example XR 20mg tab", "Example 20mg tab"),
            ("Example Plus 20mg tab", "Example 20mg tab"),
            ("Example eye drop", "Example ear drop"),
        ]:
            with self.subTest(source=source):
                result = analyze(source, [available])
                self.assertEqual(result["medicines"], [])
                self.assertTrue(result["items"][0]["needsReview"])
                self.assertEqual(result["items"][0]["sourceText"], source)

    def test_conflicting_strength_and_form_are_not_suggestions(self):
        for name in ["Example 40mg tab", "Example 20mg cap"]:
            result = analyze("Example 20mg tab", [name])
            self.assertEqual(result["unmatchedLines"][0]["suggestions"], [])

    def test_missing_strength_is_never_guessed(self):
        result = analyze("Example tab", ["Example 20mg tab", "Example 40mg tab"])
        item = result["unmatchedLines"][0]
        self.assertIsNone(item["strength"])
        self.assertIn("missing_strength", item["reviewReasons"])

    def test_missing_units_are_not_silently_discarded(self):
        result = analyze("Example 5 tab", ["Example 50mg tab"])
        self.assertEqual(result["medicines"], [])
        self.assertEqual(result["items"][0]["sourceText"], "Example 5 tab")
        self.assertIn("5", result["items"][0]["sourceName"])

    def test_combination_compares_all_components(self):
        result = analyze("Example 500mg + 125mg tab", ["Example 500mg + 250mg tab"])
        self.assertEqual(result["medicines"], [])
        self.assertEqual(result["items"][0]["strength"], "500 mg + 125 mg")
        self.assertEqual(extract_strength("Example 500/125mg"), "500 mg + 125 mg")

    def test_decimal_and_concentration_units(self):
        self.assertEqual(extract_strength("Example 0.5mg"), "0.5 mg")
        self.assertNotEqual(extract_strength("Example 0.5mg"), extract_strength("Example 5mg"))
        self.assertEqual(extract_strength("Example 250mg/5ml"), extract_strength("Example 50mg/ml"))
        self.assertEqual(extract_strength("Example 1gm"), "1000 mg")
        self.assertEqual(extract_strength("Example 0,500mg"), "0.5 mg")
        self.assertIsNone(extract_strength("Example 50,000 IU"))
        self.assertFalse(analyze("Example 50,000 IU tab", ["Example 50 IU tab"])["medicines"])

    def test_distinct_strengths_are_not_deduplicated_and_order_is_preserved(self):
        result = analyze("Example 40mg tab\nExample 20mg tab\nExample 40mg tab",
                         ["Example 20mg tab", "Example 40mg tab"])
        self.assertEqual([m["strength"] for m in result["items"]], ["40 mg", "20 mg"])

    def test_no_fifteen_item_silent_truncation(self):
        source = "\n".join(f"Product {i} cream" for i in range(20))
        self.assertEqual(len(analyze(source, [])["items"]), 20)

    def test_unknown_cosmetic_name_remains_for_review(self):
        item = analyze("Unknown Cosmetic Serum", [])["items"][0]
        self.assertEqual(item["sourceText"], "Unknown Cosmetic Serum")
        self.assertTrue(item["needsReview"])
        self.assertEqual(analyze("Dailycare Serum", [])["items"][0]["sourceText"], "Dailycare Serum")
        self.assertEqual(analyze("Daily Face Serum", [])["items"][0]["sourceText"], "Daily Face Serum")

    def test_catalog_quarantines_unknown_source_and_tracks_reference(self):
        self.assertFalse(any(m["source"] == "legacy_unverified_2" for m in self.catalog))
        self.assertFalse(any(m["raw_name"] == "Amoxicillin Tablet 802 mg" for m in self.catalog))
        official = [m for m in self.catalog if m["source"] == "nlm_rxterms"]
        self.assertGreater(len(official), 1000)
        self.assertTrue(all(m["review_only"] and m["market"] == "US" for m in official))
        self.assertEqual(len({m["id"] for m in self.catalog}), len(self.catalog))

    def test_reference_only_records_cannot_be_automatically_accepted(self):
        reference = next(m for m in self.catalog if m["source"] == "nlm_rxterms")
        result = analyze_text(reference["raw_name"], [reference], build_search_index([reference]))
        self.assertEqual(result["medicines"], [])
        self.assertIn("reference_catalog_only", result["items"][0]["reviewReasons"])

    def test_reference_snapshot_matches_receipt(self):
        receipt = json.loads((DATA / "rxterms_receipt.json").read_text())
        self.assertEqual(hashlib.sha256((DATA / "rxterms_reference.jsonl").read_bytes()).hexdigest(),
                         receipt["output_sha256"])

    def test_importer_rejects_retired_suppressed_complex_and_modified_forms(self):
        good = {"RXCUI": "1", "TTY": "SBD", "DISPLAY_NAME": "Example (Oral Pill)",
                "RXN_DOSE_FORM": "Oral Tablet", "STRENGTH": "20 mg"}
        rows = [good, {**good, "IS_RETIRED": "1"},
                {**good, "SUPPRESS_FOR": "Y"}, {**good, "STRENGTH": "20-5 mg"},
                {**good, "RXN_DOSE_FORM": "Extended Release Oral Tablet"}]
        self.assertEqual(len(convert_rows(rows, "202609")), 1)


class ApiCompatibilityTests(unittest.TestCase):
    def test_manual_and_prescription_preserve_the_same_order_and_review_contract(self):
        from app import app
        client = app.test_client()
        payload = {"text": "Trido tab\nPanadol 500mg tab"}
        a = client.post("/analyze-manual", json=payload)
        b = client.post("/analyze-prescription", json=payload)
        self.assertEqual(a.status_code, 200)
        self.assertEqual(a.json["items"], b.json["items"])
        self.assertTrue(a.json["items"][0]["needsReview"])
        self.assertEqual(client.get("/health").json["matchingPolicy"], "source-preserving-v2")


if __name__ == "__main__":
    unittest.main()

import unittest

from services.analyzer import analyze_text
from services.dictionary_builder import build_search_index
from services.matcher import generate_candidates, select_final_match
from services.normalization import clean_brand_name, extract_strength, normalize_text


def item(name, item_id):
    return {
        "id": item_id,
        "raw_name": name,
        "normalized_full": normalize_text(name),
        "brand_name": clean_brand_name(name),
        "strength": extract_strength(name),
        "dosage_form": None,
    }


class PrescriptionProcessingTests(unittest.TestCase):
    def setUp(self):
        self.dictionary = [
            item("Ciprobay 250mg", "250"),
            item("Ciprobay 500mg", "500"),
            item("Doliprane 500mg", "d500"),
            item("Doliprane 1000mg", "d1000"),
            item("ANDRIOL 40mg", "a40"),
            item("omeprazole 20mg", "o20"),
        ]
        self.index = build_search_index(self.dictionary)

    def test_strength_must_match_and_grams_are_equivalent_to_milligrams(self):
        self.assertEqual(extract_strength("Doliprane 1gm"), "1000 mg")
        self.assertEqual(
            select_final_match("Doliprane 1gm", self.dictionary, self.index)["raw_name"],
            "Doliprane 1000mg",
        )
        self.assertEqual(
            select_final_match("Ciprobay 500mg", self.dictionary, self.index)["raw_name"],
            "Ciprobay 500mg",
        )
        self.assertIsNone(select_final_match("omeprazole 40mg", self.dictionary, self.index))

    def test_a_shared_strength_does_not_invent_an_unrelated_medicine(self):
        self.assertIsNone(select_final_match("Sandoz 40mg", self.dictionary, self.index))

    def test_candidates_cannot_cross_prescription_lines(self):
        result = analyze_text("Ciprobay 500mg\nDoliprane 1gm", self.dictionary, self.index)
        self.assertEqual(result["cleanedText"].count("\n"), 1)
        self.assertNotIn(
            "ciprobay 500 mg doliprane",
            generate_candidates(result["cleanedText"].splitlines()[0]),
        )
        self.assertFalse(any("doliprane" in med["rawText"] and "ciprobay" in med["rawText"]
                             for med in result["medicines"]))

    def test_a_line_cannot_drop_its_strength_or_form(self):
        candidates = generate_candidates("Ciprobay tab 500mg 1x2x5days")
        self.assertTrue(candidates)
        self.assertTrue(all(extract_strength(candidate) == "500 mg"
                            for candidate in candidates))
        self.assertNotIn("ciprobay tab", candidates)
        result = analyze_text("Ciprobay tab 500mg 1x2x5days", self.dictionary, self.index)
        self.assertTrue(result["medicines"])
        self.assertTrue(all(med["matchedDisplayName"] != "Ciprobay 250mg"
                            for med in result["medicines"]))

    def test_unmatched_medicine_lines_are_kept_for_user_review(self):
        result = analyze_text(
            "Ciprobay tab 500mg\nTreto Cap 1X2X15days\nDoliprane 1gm tab",
            self.dictionary, self.index,
        )
        self.assertEqual([entry["name"] for entry in result["unmatchedLines"]],
                         ["Treto"])
        self.assertEqual(result["unmatchedLines"][0]["dosageForm"], "cap")
        self.assertTrue(any(med["matchedDisplayName"] == "Ciprobay 500mg"
                            for med in result["medicines"]))

    def test_unverified_catalog_strength_is_not_marked_confirmed(self):
        med = item("Omnic 0.4 30 Cap", "omnic")
        med["dosage_form"] = "cap"
        dictionary = [med]
        index = build_search_index(dictionary)
        match = select_final_match("Omnic 0.4 mg cap", dictionary, index)
        self.assertIsNotNone(match)
        self.assertTrue(match["needsReview"])
        self.assertLess(match["confidence"], 0.90)

    def test_each_medicine_line_produces_at_most_one_result(self):
        result = analyze_text(
            "Name\nAge 54 years old\nCiprobay tab 500mg 1x2x5days\n"
            "Doliprane 1gm tab 1x2x5days\nDr. Specialist",
            self.dictionary, self.index,
        )
        self.assertLessEqual(len(result["medicines"]), 2)
        self.assertFalse(any(entry["name"].lower() in {"name", "age", "dr"}
                             for entry in result["unmatchedLines"]))


if __name__ == "__main__":
    unittest.main()

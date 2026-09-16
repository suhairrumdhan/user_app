"""Preserve source order and uncertainty through the entire API response."""
import re
from typing import List, Dict
from services.normalization import normalize_text, source_identity
from services.matcher import generate_candidates, select_final_match

HEADER = re.compile(
    r"^(?:name|age|rx|dr|doctor|date|patient|hospital|signature|"
    r"اسم|العمر|التاريخ|المريض)(?:\b|:)|"
    r"\b(?:hospital|specialist|prescription)\s*$|^\d+[/-]\d+[/-]\d+$", re.I)


def analyze_text(text: str, dictionary: List[Dict], index: Dict) -> Dict:
    medicines, unmatched, items, rejected = [], [], [], []
    seen = set()
    for line_number, raw in enumerate(text.splitlines()):
        raw = raw.strip()
        if not raw or HEADER.search(raw):
            continue
        identity = source_identity(raw)
        candidate = generate_candidates(raw)
        if not candidate:
            continue
        match = select_final_match(candidate[0], dictionary, index)
        # Free-form prose without a recognized name/form/strength is not a
        # medication. Short unknown product names (including cosmetics) survive.
        if not match and not identity["strength"] and not identity["dosageForm"]:
            if len(identity["name"].split()) > 5 or ":" in raw:
                continue
        key = (identity["name"], identity["strength"], identity["dosageForm"])
        if key in seen:
            continue
        seen.add(key)
        base = {
            "rawText": raw, "sourceText": identity["text"],
            "sourceName": identity["name"], "name": identity["name"],
            "sourceLine": line_number,
            "normalizedText": normalize_text(identity["text"]),
            "parsedBrandName": identity["name"], "parsedScientificName": None,
            "strength": identity["strength"], "dosageForm": identity["dosageForm"],
            "quantity": 1,
        }
        if match and not match["needsReview"]:
            entry = {**base, "matchedDisplayName": match["raw_name"],
                     "confidence": match["confidence"], "matchType": match["matchType"],
                     "needsReview": False, "status": "matched",
                     "catalogId": match["catalogId"], "source": match["source"],
                     "market": match["market"], "alternatives": [], "reviewReasons": []}
            medicines.append(entry)
        else:
            entry = {**base, "needsReview": True, "status": "review",
                     "reviewReasons": match["reviewReasons"] if match else ["no_match"],
                     "suggestions": match["alternatives"] if match else []}
            unmatched.append(entry)
            rejected.append({"candidate": identity["text"], "reason": entry["reviewReasons"][0]})
        items.append(entry)
    return {
        "cleanedText": "\n".join(normalize_text(line) for line in text.splitlines() if line.strip()),
        "medicines": medicines, "unmatchedLines": unmatched,
        "items": items, "rejectedCandidates": rejected,
    }

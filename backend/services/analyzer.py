from typing import List, Dict

from services.normalization import normalize_text
from services.matcher import generate_candidates, select_final_match


def analyze_text(text: str, dictionary: List[Dict]) -> Dict:
    cleaned = normalize_text(text)
    candidates = generate_candidates(cleaned, max_n=6)

    medicines = []
    rejected = []
    accepted_spans = []

    for candidate in candidates:
        match = select_final_match(candidate, dictionary)

        if not match:
            rejected.append({
                "candidate": candidate,
                "reason": "no_reliable_match",
            })
            continue

        current_span = match["normalizedText"]

        # skip if this span is inside a bigger accepted span
        skip = False
        for span in accepted_spans:
            if current_span in span:
                skip = True
                break

        if skip:
            continue

        accepted_spans.append(current_span)

        medicines.append({
            "rawText": candidate,
            "normalizedText": match["normalizedText"],
            "parsedBrandName": match["parsedBrandName"],
            "parsedScientificName": match["parsedScientificName"],
            "strength": match["strength"],
            "dosageForm": match["dosageForm"],
            "quantity": 1,
            "matchedDisplayName": match["raw_name"],
            "confidence": match["confidence"],
            "matchType": match["matchType"],
            "needsReview": match["needsReview"],
            "alternatives": match["alternatives"],
        })

    medicines.sort(
        key=lambda x: (x["needsReview"], -x["confidence"])
    )

    return {
        "cleanedText": cleaned,
        "medicines": medicines,
        "rejectedCandidates": rejected[:20],
    }
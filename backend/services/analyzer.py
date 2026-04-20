from typing import List, Dict
from rapidfuzz import fuzz

from services.normalization import normalize_text
from services.matcher import generate_candidates, select_final_match


def _is_similar_medicine(a: Dict, b: Dict) -> bool:
    a_brand = (a.get("parsedBrandName") or "").strip()
    b_brand = (b.get("parsedBrandName") or "").strip()

    a_name = (a.get("matchedDisplayName") or "").strip()
    b_name = (b.get("matchedDisplayName") or "").strip()

    if a_brand and b_brand and a_brand == b_brand:
        return True

    if a_name and b_name and fuzz.ratio(a_name, b_name) >= 92:
        return True

    return False


def _pick_better_match(a: Dict, b: Dict) -> Dict:
    # الأفضلية للأعلى confidence
    if a["confidence"] != b["confidence"]:
        return a if a["confidence"] > b["confidence"] else b

    # ثم للأقل needsReview
    if a["needsReview"] != b["needsReview"]:
        return a if not a["needsReview"] else b

    # ثم للأطول rawText
    if len(a["rawText"]) != len(b["rawText"]):
        return a if len(a["rawText"]) > len(b["rawText"]) else b

    return a


def _post_process_matches(medicines: List[Dict], max_results: int = 15) -> List[Dict]:
    # 1) ترتيب أولي
    medicines.sort(
        key=lambda x: (
            x["needsReview"],
            -x["confidence"],
            -len(x["rawText"]),
        )
    )

    # 2) حذف المكرر / المتشابه
    filtered: List[Dict] = []
    for med in medicines:
        merged = False

        for i, existing in enumerate(filtered):
            if _is_similar_medicine(existing, med):
                filtered[i] = _pick_better_match(existing, med)
                merged = True
                break

        if not merged:
            filtered.append(med)

    # 3) حذف النتائج الضعيفة جدًا
    strong = [m for m in filtered if m["confidence"] >= 0.80]

    if strong:
        filtered = strong

    # 4) ترتيب نهائي
    filtered.sort(
        key=lambda x: (
            x["needsReview"],
            -x["confidence"],
            -len(x["rawText"]),
        )
    )

    # 5) تقليم العدد النهائي
    return filtered[:max_results]


def analyze_text(text: str, dictionary: List[Dict], index: Dict[str, Dict]) -> Dict:
    cleaned = normalize_text(text)
    candidates = generate_candidates(cleaned, max_n=3)

    medicines = []
    rejected = []
    accepted_spans = []
    match_cache = {}

    for candidate in candidates:
        if candidate in match_cache:
            match = match_cache[candidate]
        else:
            match = select_final_match(candidate, dictionary, index)
            match_cache[candidate] = match

        if not match:
            rejected.append({
                "candidate": candidate,
                "reason": "no_reliable_match",
            })
            continue

        current_span = match["normalizedText"]

        skip = False
        for span in accepted_spans:
            if current_span in span or span in current_span:
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

    medicines = _post_process_matches(medicines, max_results=15)

    return {
        "cleanedText": cleaned,
        "medicines": medicines,
        "rejectedCandidates": rejected[:20],
    }
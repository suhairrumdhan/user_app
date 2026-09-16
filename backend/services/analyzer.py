from typing import List, Dict
from rapidfuzz import fuzz

import re

from services.normalization import (
    normalize_text, extract_strength, extract_dosage_form,
)
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
    # Do not let an n-gram join the end of one OCR/PDF line to the next item.
    source_lines = [(line.strip(), normalize_text(line)) for line in text.splitlines()]
    source_lines = [(raw, cleaned) for raw, cleaned in source_lines if cleaned]
    cleaned_lines = [cleaned for _, cleaned in source_lines]
    cleaned = "\n".join(cleaned_lines)
    candidate_lines = {}
    for line_index, line in enumerate(cleaned_lines):
        for candidate in generate_candidates(line, max_n=5):
            candidate_lines.setdefault(candidate, line_index)
    candidates = list(candidate_lines)

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

    # One OCR/PDF line represents one medicine item. Competing fuzzy matches
    # for the same line are suggestions, not extra medicines to order.
    best_per_line = {}
    for med in medicines:
        line_index = candidate_lines[med["rawText"]]
        existing = best_per_line.get(line_index)
        best_per_line[line_index] = (
            med if existing is None else _pick_better_match(existing, med)
        )
    medicines = _post_process_matches(list(best_per_line.values()), max_results=15)

    matched_lines = {
        candidate_lines[med["rawText"]] for med in medicines
        if med["rawText"] in candidate_lines
    }
    unmatched_lines = []
    for line_index, (raw, line) in enumerate(source_lines):
        if line_index in matched_lines:
            continue
        strength = extract_strength(line)
        form = extract_dosage_form(line)
        if not strength and not form:
            continue
        name = re.split(
            r'\b(?:tab|tabs|tablet|cap|capsule|syrup|susp|drop|cream|gel|spray|vial|amp|inj)\b'
            r'|\b\d+(?:[.,]\d+)?\s*(?:mg|gm|g|mcg|ml|iu)\b',
            raw, maxsplit=1, flags=re.I,
        )[0].strip(' :;,-\"')
        if len(name) < 3 or name.lower() in {"name", "age", "rx", "doctor"}:
            continue
        unmatched_lines.append({
            "rawText": raw,
            "name": name,
            "strength": strength,
            "dosageForm": form,
        })

    return {
        "cleanedText": cleaned,
        "medicines": medicines,
        "unmatchedLines": unmatched_lines[:15],
        "rejectedCandidates": rejected[:20],
    }

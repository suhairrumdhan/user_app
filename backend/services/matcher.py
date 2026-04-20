from typing import List, Dict, Optional
from rapidfuzz import fuzz

from services.normalization import (
    normalize_text,
    clean_brand_name,
    extract_strength,
    extract_dosage_form,
)

MIN_CANDIDATE_LEN = 4
MATCH_THRESHOLD = 80
HIGH_CONFIDENCE = 90
MAX_RELEVANT_RESULTS = 300
MAX_CANDIDATES = 40

STOPWORDS = {
    "and", "or", "with", "for", "the", "of", "to", "in"
}


def is_medicine_like(candidate: str) -> bool:
    candidate = normalize_text(candidate)
    if len(candidate) < MIN_CANDIDATE_LEN:
        return False

    brand = clean_brand_name(candidate)
    if len(brand) < 3:
        return False

    return True


def clean_candidate(candidate: str) -> str:
    tokens = candidate.split()

    while tokens and tokens[0] in STOPWORDS:
        tokens.pop(0)

    while tokens and tokens[-1] in STOPWORDS:
        tokens.pop()

    return " ".join(tokens).strip()


def trim_candidate_tail(candidate: str) -> str:
    tokens = candidate.split()
    if not tokens:
        return candidate

    dosage_forms = {
        "tab", "cap", "syrup", "susp", "drop",
        "cream", "ointment", "gel", "spray",
        "vial", "amp", "inj",
    }

    for i, tok in enumerate(tokens):
        if tok in dosage_forms:
            return " ".join(tokens[:i + 1]).strip()

    return candidate


def has_suspicious_connector(candidate: str) -> bool:
    tokens = candidate.split()
    connectors = {"and", "or", "with"}
    return any(tok in connectors for tok in tokens)


def generate_candidates(text: str, max_n: int = 3) -> List[str]:
    text = normalize_text(text)
    tokens = text.split()

    candidates = []
    seen = set()

    for i in range(len(tokens)):
        for n in range(1, max_n + 1):
            if i + n > len(tokens):
                continue

            phrase = " ".join(tokens[i:i + n]).strip()
            phrase = clean_candidate(phrase)
            phrase = trim_candidate_tail(phrase)

            if not phrase:
                continue

            if has_suspicious_connector(phrase):
                continue

            if len(phrase) < MIN_CANDIDATE_LEN:
                continue

            if len(phrase.split()) > 4:
                continue

            if not is_medicine_like(phrase):
                continue

            generic_tokens = {"mg", "ml", "tab", "cap", "syrup", "drop", "cream", "gel"}

            if phrase in generic_tokens:
                continue


            if phrase not in seen:
                seen.add(phrase)
                candidates.append(phrase)

    candidates.sort(key=lambda x: (-len(x.split()), x))
    return candidates[:MAX_CANDIDATES]


def _add_items(results: List[Dict], seen_ids: set, items: List[Dict]) -> bool:
    for med in items:
        med_id = med.get("id")
        if med_id in seen_ids:
            continue

        seen_ids.add(med_id)
        results.append(med)

        if len(results) >= MAX_RELEVANT_RESULTS:
            return True

    return False


def get_relevant_meds(candidate: str, search_index: Dict[str, Dict[str, List[Dict]]]) -> List[Dict]:
    candidate_norm = normalize_text(candidate)
    candidate_brand = clean_brand_name(candidate)
    candidate_strength = extract_strength(candidate) or ""
    candidate_form = extract_dosage_form(candidate) or ""

    full_name_index = search_index["full_name_index"]
    brand_index = search_index["brand_index"]
    token_index = search_index["token_index"]
    prefix_index = search_index["prefix_index"]
    strength_index = search_index["strength_index"]
    form_index = search_index["form_index"]

    results: List[Dict] = []
    seen_ids = set()

    # 1) exact full
    if _add_items(results, seen_ids, full_name_index.get(candidate_norm, [])):
        return results

    # 2) exact brand
    if candidate_brand:
        if _add_items(results, seen_ids, brand_index.get(candidate_brand, [])):
            return results

    # 3) token matches from full normalized text
    for tok in candidate_norm.split():
        tok = tok.strip()
        if len(tok) >= 2:
            if _add_items(results, seen_ids, token_index.get(tok, [])):
                return results
        if len(tok) >= 3:
            if _add_items(results, seen_ids, prefix_index.get(tok[:3], [])):
                return results

    # 4) token matches from brand name
    for tok in candidate_brand.split():
        tok = tok.strip()
        if len(tok) >= 2:
            if _add_items(results, seen_ids, token_index.get(tok, [])):
                return results
        if len(tok) >= 3:
            if _add_items(results, seen_ids, prefix_index.get(tok[:3], [])):
                return results

    # 5) strength / form support
    if candidate_strength:
        if _add_items(results, seen_ids, strength_index.get(candidate_strength, [])):
            return results

    if candidate_form:
        if _add_items(results, seen_ids, form_index.get(candidate_form, [])):
            return results

    return results


def _score_candidate(candidate: str, med: Dict) -> Dict:
    candidate_norm = normalize_text(candidate)
    candidate_brand = clean_brand_name(candidate)
    candidate_strength = extract_strength(candidate)
    candidate_form = extract_dosage_form(candidate)

    med_full = med.get("normalized_full") or ""
    med_brand = med.get("brand_name") or ""

    full_score = fuzz.ratio(candidate_norm, med_full)
    brand_score = fuzz.ratio(candidate_brand, med_brand) if candidate_brand and med_brand else 0
    token_score = fuzz.token_set_ratio(candidate_norm, med_full)

    score = (
        0.40 * brand_score +
        0.30 * full_score +
        0.30 * token_score
    )

    candidate_tokens = set(candidate_norm.split())
    med_tokens = set(med_full.split())
    overlap = len(candidate_tokens & med_tokens)
    score += overlap * 2.5

    if candidate_strength and med.get("strength"):
        if candidate_strength == med["strength"]:
            score += 8
        else:
            score -= 7

    if candidate_form and med.get("dosage_form"):
        if candidate_form == med["dosage_form"]:
            score += 5
        else:
            score -= 4

    match_type = "fuzzy"

    if candidate_norm == med_full:
        score += 8
        match_type = "exact_full"
    elif candidate_brand and candidate_brand == med_brand:
        score += 6
        match_type = "exact_brand"
    elif (
        candidate_brand and candidate_strength and
        candidate_brand == med_brand and candidate_strength == med.get("strength")
    ):
        score += 9
        match_type = "exact_brand_strength"

    final_score = max(0.0, min(score, 100.0))

    return {
        "medicine": med,
        "score": round(final_score, 2),
        "match_type": match_type,
    }


def find_best_matches(candidate: str, relevant: List[Dict], top_k: int = 3) -> List[Dict]:
    scored = [_score_candidate(candidate, med) for med in relevant]
    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:top_k]


def select_final_match(
    candidate: str,
    dictionary: List[Dict],
    index: Dict[str, Dict[str, List[Dict]]],
) -> Optional[Dict]:
    relevant = get_relevant_meds(candidate, index)

    if not relevant:
        return None

    top = find_best_matches(candidate, relevant, top_k=3)
    if not top:
        return None

    best = top[0]
    second = top[1] if len(top) > 1 else None

    if best["score"] < MATCH_THRESHOLD:
        return None

    ambiguous = second is not None and (best["score"] - second["score"] < 3)

    med = best["medicine"]

    return {
        "candidate": candidate,
        "raw_name": med["raw_name"],
        "parsedBrandName": med["brand_name"] or None,
        "parsedScientificName": None,
        "strength": med.get("strength"),
        "dosageForm": med.get("dosage_form"),
        "normalizedText": normalize_text(candidate),
        "confidence": round(best["score"] / 100.0, 2),
        "matchType": best["match_type"],
        "needsReview": best["score"] < HIGH_CONFIDENCE or ambiguous,
        "alternatives": [
            {
                "name": item["medicine"]["raw_name"],
                "confidence": round(item["score"] / 100.0, 2),
            }
            for item in top[1:]
            if item["score"] >= MATCH_THRESHOLD - 3
        ],
    }
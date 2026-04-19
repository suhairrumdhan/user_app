from typing import List, Dict, Optional
from rapidfuzz import fuzz

from services.normalization import (
    normalize_text,
    clean_brand_name,
    extract_strength,
    extract_dosage_form,
)


MIN_CANDIDATE_LEN = 4
MATCH_THRESHOLD = 86
HIGH_CONFIDENCE = 93

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

    # remove stopwords from start
    while tokens and tokens[0] in STOPWORDS:
        tokens.pop(0)

    # remove stopwords from end
    while tokens and tokens[-1] in STOPWORDS:
        tokens.pop()

    return " ".join(tokens)

def clean_candidate(candidate: str) -> str:
    tokens = candidate.split()

    while tokens and tokens[0] in STOPWORDS:
        tokens.pop(0)

    while tokens and tokens[-1] in STOPWORDS:
        tokens.pop()

    return " ".join(tokens)


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


def generate_candidates(text: str, max_n: int = 6) -> List[str]:
    text = normalize_text(text)
    tokens = text.split()

    candidates = []

    for i in range(len(tokens)):
        for n in range(1, max_n + 1):
            if i + n <= len(tokens):
                phrase = " ".join(tokens[i:i+n]).strip()
                phrase = clean_candidate(phrase)
                phrase = trim_candidate_tail(phrase)

                if not phrase:
                    continue

                if has_suspicious_connector(phrase):
                    continue

                if is_medicine_like(phrase):
                    candidates.append(phrase)

    candidates = list(set(candidates))
    candidates.sort(key=lambda x: (-len(x.split()), x))
    return candidates



def _score_candidate(candidate: str, med: Dict) -> Dict:
    candidate_norm = normalize_text(candidate)
    candidate_brand = clean_brand_name(candidate)
    candidate_strength = extract_strength(candidate)
    candidate_form = extract_dosage_form(candidate)

    full_score = fuzz.ratio(candidate_norm, med["normalized_full"])
    partial_score = fuzz.partial_ratio(candidate_norm, med["normalized_full"])
    brand_score = fuzz.ratio(candidate_brand, med["brand_name"]) if candidate_brand and med["brand_name"] else 0
    token_score = fuzz.token_set_ratio(candidate_norm, med["normalized_full"])

    score = (
        0.35 * brand_score +
        0.25 * full_score +
        0.20 * partial_score +
        0.20 * token_score
    )

    if candidate_strength and med["strength"]:
        if candidate_strength == med["strength"]:
            score += 8
        else:
            score -= 7

    if candidate_form and med["dosage_form"]:
        if candidate_form == med["dosage_form"]:
            score += 5
        else:
            score -= 4

    match_type = "fuzzy"

    if candidate_norm == med["normalized_full"]:
        score += 8
        match_type = "exact_full"
    elif candidate_brand and candidate_brand == med["brand_name"]:
        score += 6
        match_type = "exact_brand"
    elif candidate_brand and candidate_strength and candidate_brand == med["brand_name"] and candidate_strength == med["strength"]:
        score += 9
        match_type = "exact_brand_strength"

    final_score = max(0.0, min(score, 100.0))

    return {
        "medicine": med,
        "score": round(final_score, 2),
        "match_type": match_type,
    }

def trim_candidate_tail(candidate: str) -> str:
    tokens = candidate.split()
    if not tokens:
        return candidate

    dosage_forms = {
        "tab", "cap", "syrup", "susp", "drop",
        "cream", "ointment", "gel", "spray",
        "vial", "amp", "inj", "ear drop", "eye drop"
    }

    # cut after first complete dosage form if extra tokens continue
    for i, tok in enumerate(tokens):
        if tok in dosage_forms:
            return " ".join(tokens[:i + 1]).strip()

    return candidate


def find_best_matches(candidate: str, dictionary: List[Dict], top_k: int = 3) -> List[Dict]:
    scored = [_score_candidate(candidate, med) for med in dictionary]
    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:top_k]


def select_final_match(candidate: str, dictionary: List[Dict]) -> Optional[Dict]:
    top = find_best_matches(candidate, dictionary, top_k=3)
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
        "strength": med["strength"],
        "dosageForm": med["dosage_form"],
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
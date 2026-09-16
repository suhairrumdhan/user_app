"""Name recognition, not clinical substitution.

A spelling score is a suggestion only. Missing or conflicting product details
must never be repaired by choosing a different catalog product.
"""
from typing import List, Dict, Optional
from rapidfuzz import fuzz
from services.normalization import (
    normalize_text, clean_brand_name, extract_strength,
    extract_dosage_form, strip_posology,
)

MATCH_THRESHOLD = 80
MAX_RELEVANT_RESULTS = 300


def generate_candidates(text: str, max_n: int = 5) -> List[str]:
    # Whole lines preserve PLUS/XR and all components of a combination.
    candidate = normalize_text(strip_posology(text))
    return [candidate] if len(clean_brand_name(candidate)) >= 3 else []


def get_relevant_meds(candidate: str, search_index: Dict) -> List[Dict]:
    brand = clean_brand_name(candidate)
    exact = search_index["brand_index"].get(brand, [])
    if exact:
        return exact
    found = {}
    for token in brand.split():
        if len(token) < 3:
            continue
        for med in search_index["prefix_index"].get(token[:3], []):
            found[med["id"]] = med
            if len(found) >= MAX_RELEVANT_RESULTS:
                return list(found.values())
    return list(found.values())


def _brands(med: Dict) -> set:
    return {med.get("brand_name", ""), *med.get("name_aliases", [])} - {""}


def _compatible(candidate: str, med: Dict) -> bool:
    for source, key in [(extract_strength(candidate), "strength"),
                        (extract_dosage_form(candidate), "dosage_form")]:
        if source and med.get(key) and source != med[key]:
            return False
    return True


def find_best_matches(candidate: str, relevant: List[Dict], top_k: int = 3) -> List[Dict]:
    brand = clean_brand_name(candidate)
    strength = extract_strength(candidate)
    form = extract_dosage_form(candidate)
    scored = []
    for med in relevant:
        if not _compatible(candidate, med):
            continue
        exact = brand in _brands(med)
        score = max((fuzz.ratio(brand, name) for name in _brands(med)), default=0)
        details = int(bool(strength and med.get("strength") == strength))
        details += int(bool(form and med.get("dosage_form") == form))
        scored.append({"medicine": med, "score": score, "exact": exact,
                       "details": details,
                       "match_type": "exact_identity" if exact else "spelling_suggestion"})
    scored.sort(key=lambda x: (x["exact"], x["details"], x["score"],
                              not x["medicine"].get("review_only", False),
                              x["medicine"].get("source_quality") == "official"), reverse=True)
    return scored[:top_k]


def select_final_match(candidate: str, dictionary: List[Dict], index: Dict) -> Optional[Dict]:
    relevant = get_relevant_meds(candidate, index)
    top = find_best_matches(candidate, relevant)
    if not top or top[0]["score"] < MATCH_THRESHOLD:
        return None
    best = top[0]
    med = best["medicine"]
    strength = extract_strength(candidate)
    form = extract_dosage_form(candidate)
    reasons = []
    if not best["exact"]:
        reasons.append("spelling_suggestion")
    if strength and not med.get("strength"):
        reasons.append("unverified_strength")
    if form and not med.get("dosage_form"):
        reasons.append("unverified_form")
    compatible = [m for m in relevant if _compatible(candidate, m)]
    if not strength and any(m.get("strength") for m in compatible):
        reasons.append("missing_strength")
    if not form and any(m.get("dosage_form") for m in compatible):
        reasons.append("missing_form")
    if med.get("review_only"):
        reasons.append("reference_catalog_only")
    ingredients = {m.get("ingredient_key") for m in compatible
                   if m.get("ingredient_key") and clean_brand_name(candidate) in _brands(m)}
    if len(ingredients) > 1:
        reasons.append("ambiguous_ingredients")
    suggestions = [{
        "name": item["medicine"]["raw_name"],
        "catalogId": item["medicine"]["id"],
        "source": item["medicine"].get("source"),
        "market": item["medicine"].get("market"),
        "similarity": round(item["score"] / 100, 2),
    } for item in top if item["score"] >= MATCH_THRESHOLD]
    return {
        "candidate": candidate, "raw_name": med["raw_name"],
        "parsedBrandName": clean_brand_name(candidate),
        "parsedScientificName": None,
        # Never fill missing prescription details from a catalog.
        "strength": strength, "dosageForm": form,
        "normalizedText": normalize_text(candidate),
        "confidence": 1.0 if not reasons else min(round(best["score"] / 100, 2), 0.89),
        "matchType": best["match_type"], "needsReview": bool(reasons),
        "reviewReasons": reasons, "alternatives": suggestions,
        "catalogId": med["id"], "source": med.get("source"), "market": med.get("market"),
    }

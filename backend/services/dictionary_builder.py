import csv
from typing import List, Dict

from services.normalization import (
    normalize_text,
    extract_strength,
    extract_dosage_form,
    clean_brand_name,
)


def _read_csv_lines(csv_path: str) -> List[str]:
    encodings = ["utf-8-sig", "utf-8", "cp1256", "latin1"]

    last_error = None
    for enc in encodings:
        try:
            with open(csv_path, "r", encoding=enc, newline="") as f:
                reader = csv.reader(f)
                rows = list(reader)

            values = []
            for row in rows:
                if not row:
                    continue
                first_col = str(row[0]).strip()
                if first_col:
                    values.append(first_col)

            return values
        except Exception as e:
            last_error = e

    raise ValueError(f"Could not read CSV file: {csv_path}. Last error: {last_error}")


def _is_header_like(value: str) -> bool:
    lowered = value.strip().lower()
    return lowered in {
        "name dosage form strength",
        "اسم الصنف",
        "إسم الصنف",
    }


def build_dictionary_from_csvs(csv_paths: List[str]) -> List[Dict]:
    all_records = []
    global_seen = set()
    current_id = 1

    for source_index, csv_path in enumerate(csv_paths, start=1):
        lines = _read_csv_lines(csv_path)

        for raw_value in lines:
            raw_name = str(raw_value).strip()
            if not raw_name:
                continue

            if _is_header_like(raw_name):
                continue

            normalized_full = normalize_text(raw_name)
            brand_name = clean_brand_name(raw_name)
            strength = extract_strength(raw_name)
            dosage_form = extract_dosage_form(raw_name)

            if not brand_name and not normalized_full:
                continue

            unique_key = (normalized_full, strength, dosage_form)
            if unique_key in global_seen:
                continue
            global_seen.add(unique_key)

            all_records.append({
                "id": f"med_{current_id}",
                "raw_name": raw_name,
                "normalized_full": normalized_full,
                "brand_name": brand_name,
                "strength": strength,
                "dosage_form": dosage_form,
                "source": f"csv_{source_index}",
            })
            current_id += 1

    return all_records


def build_search_index(dictionary: List[Dict]) -> Dict[str, Dict[str, List[Dict]]]:
    full_name_index: Dict[str, List[Dict]] = {}
    brand_index: Dict[str, List[Dict]] = {}
    token_index: Dict[str, List[Dict]] = {}
    prefix_index: Dict[str, List[Dict]] = {}
    strength_index: Dict[str, List[Dict]] = {}
    form_index: Dict[str, List[Dict]] = {}

    def add(index_dict: Dict[str, List[Dict]], key: str, med: Dict) -> None:
        if not key:
            return
        index_dict.setdefault(key, []).append(med)

    for med in dictionary:
        normalized_full = (med.get("normalized_full") or "").strip()
        brand_name = (med.get("brand_name") or "").strip()
        strength = (med.get("strength") or "").strip()
        dosage_form = (med.get("dosage_form") or "").strip()

        # exact indexes
        add(full_name_index, normalized_full, med)
        add(brand_index, brand_name, med)
        add(strength_index, strength, med)
        add(form_index, dosage_form, med)

        # token + prefix indexes from full name
        for tok in normalized_full.split():
            tok = tok.strip()
            if len(tok) >= 2:
                add(token_index, tok, med)
            if len(tok) >= 3:
                add(prefix_index, tok[:3], med)

        # token + prefix indexes from brand name
        for tok in brand_name.split():
            tok = tok.strip()
            if len(tok) >= 2:
                add(token_index, tok, med)
            if len(tok) >= 3:
                add(prefix_index, tok[:3], med)

    return {
        "full_name_index": full_name_index,
        "brand_index": brand_index,
        "token_index": token_index,
        "prefix_index": prefix_index,
        "strength_index": strength_index,
        "form_index": form_index,
    }
import pandas as pd
from typing import List, Dict

from services.normalization import (
    normalize_text,
    extract_strength,
    extract_dosage_form,
    clean_brand_name,
)


def build_dictionary_from_excel(excel_path: str) -> List[Dict]:
    df = pd.read_excel(excel_path, header=None)

    records = []
    seen = set()

    for idx, row in df.iterrows():
        raw_value = row.iloc[0]

        if pd.isna(raw_value):
            continue

        raw_name = str(raw_value).strip()
        if not raw_name:
            continue

        normalized_full = normalize_text(raw_name)
        brand_name = clean_brand_name(raw_name)
        strength = extract_strength(raw_name)
        dosage_form = extract_dosage_form(raw_name)

        if not brand_name and not normalized_full:
            continue

        unique_key = (normalized_full, strength, dosage_form)
        if unique_key in seen:
            continue
        seen.add(unique_key)

        records.append({
            "id": f"med_{idx+1}",
            "raw_name": raw_name,
            "normalized_full": normalized_full,
            "brand_name": brand_name,
            "strength": strength,
            "dosage_form": dosage_form,
        })

    return records
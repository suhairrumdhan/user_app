"""Build a conservative, provenance-tracked US reference snapshot, offline at runtime.

Only current single-strength ordinary oral tablets/capsules are imported.
No brand/generic aliases or international equivalences are inferred.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.normalization import normalize_text, extract_strength

SOURCE = "https://lhncbc.nlm.nih.gov/MOR/RxTerms/"


def convert_rows(rows, version):
    result = []
    for row in rows:
        if row.get("SUPPRESS_FOR") or row.get("IS_RETIRED"):
            continue
        if row.get("TTY") not in {"SCD", "SBD"}:
            continue
        form = {"Oral Tablet": "tab", "Oral Capsule": "cap"}.get(row.get("RXN_DOSE_FORM"))
        strength_text = row.get("STRENGTH", "").strip()
        # Combinations, packs, modified release and non-oral forms need a
        # dedicated importer; dropping their extra information is not safe.
        if not form or not re.fullmatch(r"\d+(?:\.\d+)?\s*(?:mcg|mg|g)", strength_text, re.I):
            continue
        name = row.get("DISPLAY_NAME", "").split(" (", 1)[0].strip()
        strength = extract_strength(strength_text)
        if not name or not strength:
            continue
        raw_name = f"{name} {strength_text} {form}"
        result.append({
            "id": "rxterms:" + row["RXCUI"],
            "raw_name": raw_name,
            "brand_name": normalize_text(name),
            "normalized_full": normalize_text(raw_name),
            "strength": strength, "dosage_form": form,
            "ingredient_key": row.get("GENERIC_RXCUI") or row["RXCUI"],
            "source_id": row["RXCUI"], "source_version": version,
        })
    return sorted(result, key=lambda record: record["id"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="NLM release YYYYMM")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{6}", args.version):
        parser.error("version must be YYYYMM")
    filename = f"RxTerms{args.version}.zip"
    url = "https://data.lhncbc.nlm.nih.gov/public/rxterms/release/" + filename
    with urllib.request.urlopen(url, timeout=60) as response:
        archive = response.read(25_000_001)
    if len(archive) > 25_000_000:
        raise ValueError("Unexpectedly large archive")
    with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
        name = f"RxTerms{args.version}.txt"
        if zipped.getinfo(name).file_size > 100_000_000:
            raise ValueError("Unexpectedly large source file")
        rows = csv.DictReader(io.StringIO(zipped.read(name).decode("utf-8-sig")), delimiter="|")
        records = convert_rows(rows, args.version)
    if not records:
        raise ValueError("Empty reference catalog; existing snapshot was not changed")
    root = Path(__file__).resolve().parents[1] / "data"
    payload = "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in records)
    target = root / "rxterms_reference.jsonl"
    target.write_text(payload, encoding="utf-8", newline="\n")
    receipt = {
        "source": SOURCE, "download": url, "version": args.version,
        "archive_sha256": hashlib.sha256(archive).hexdigest(),
        "output_sha256": hashlib.sha256(payload.encode()).hexdigest(),
        "record_count": len(records),
        "scope": "Current ordinary oral single-strength tablets/capsules only; US reference, not Libya availability.",
    }
    (root / "rxterms_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()

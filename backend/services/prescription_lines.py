"""Separate English medication entries from OCR document metadata.

An unknown short line is not automatically a medicine. It needs medication
context (Rx section, a medicine list, or an explicit single manual name).
"""
import re

from services.normalization import source_identity

ARABIC = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+")
LATIN_NAME = re.compile(r"[A-Za-z]{2,}")
RX_ONLY = re.compile(r"^(?:r\s*/?\s*x|℞|medications?|medicines?|treatment|prescription)\s*[:.\-]?\s*$", re.I)
RX_PREFIX = re.compile(r"^(?:r\s*/?\s*x|℞)\s*[:.\-]?\s+", re.I)
FIELD = re.compile(
    r"^(?:name|age|patient(?:\s+name)?|patient\s*id|dob|date(?:\s+of\s+birth)?|"
    r"sex|gender|address|phone|tel|telephone|mobile|email|diagnosis|"
    r"allergies|weight|height|blood\s+pressure)\b", re.I)
FOOTER = re.compile(
    r"^(?:dr[.\s:]|doctor\b|prescriber\b|signature\b|signed\b|consultant\b)|"
    r"\b(?:specialist|urologist|physician|surgeon|m\.?\s*d\.?)\s*[.,]?$", re.I)
AGE = re.compile(r"^(?:\d+\s*)?(?:years?\s*old|yrs?(?:\s*old)?|y\s*/?\s*o)\s*[.,]?$", re.I)
INSTITUTION = re.compile(r"\b(?:hospital|clinic|medical\s+cent(?:er|re)|health\s+cent(?:er|re))\b", re.I)
INSTRUCTIONS = re.compile(
    r"^(?:take\b|use\b|apply\b|after\s+meals?\b|before\s+meals?\b|"
    r"follow\s*up\b|next\s+visit\b|every\s+\d|once\s+daily\b|twice\s+daily\b|"
    r"\d+\s*[x×]\s*\d|\d+\s*(?:days?|weeks?|months?)\b)", re.I)
NON_NAMES = {"mg", "mcg", "g", "ml", "iu", "rx", "tab", "cap", "years", "old"}


def english_part(raw: str) -> str:
    # Keep Latin product names on mixed lines; do not transliterate Arabic.
    text = ARABIC.sub(" ", raw)
    text = re.sub(r"[\u200e\u200f\u202a-\u202e\u2066-\u2069]", "", text)
    return re.sub(r"[ \t]+", " ", text).strip(" :;,-")


def medication_lines(text: str, index: dict, *, manual_input: bool = False) -> list[tuple[int, str]]:
    lines = [(number, english_part(raw)) for number, raw in enumerate(text.splitlines()) if raw.strip()]
    prepared = []
    in_rx = False
    in_footer = False
    field_value_pending = False
    has_document_metadata = False
    for number, raw in lines:
        if not raw:
            continue
        if RX_ONLY.fullmatch(raw):
            in_rx, in_footer, field_value_pending = True, False, False
            has_document_metadata = True
            continue
        inline_rx = RX_PREFIX.match(raw)
        if inline_rx:
            raw = raw[inline_rx.end():].strip()
            in_rx, in_footer, field_value_pending = True, False, False
            has_document_metadata = True
        field = FIELD.match(raw)
        if field:
            field_value_pending = not raw[field.end():].strip(" :.-")
            has_document_metadata = True
            continue
        if FOOTER.search(raw):
            in_footer, in_rx = True, False
            has_document_metadata = True
            continue
        if AGE.fullmatch(raw) or INSTITUTION.search(raw) or INSTRUCTIONS.search(raw):
            has_document_metadata = True
            continue
        if not LATIN_NAME.search(raw):
            # Dates (including broken "2023/"), digits and punctuation only.
            continue
        identity = source_identity(raw)
        name = identity["name"]
        if not LATIN_NAME.search(name) or name.lower() in NON_NAMES:
            continue
        exact_name = bool(index.get("brand_index", {}).get(name))
        strong = bool(identity["strength"] or identity["dosageForm"] or exact_name)
        # A separate patient/age value must not enter the medication list.
        if field_value_pending and not (identity["strength"] or identity["dosageForm"]):
            field_value_pending = False
            continue
        field_value_pending = False
        if in_footer:
            continue
        prepared.append((number, raw, strong, in_rx))
    anchors = [number for number, _, strong, _ in prepared if strong]
    first = min(anchors) if anchors else -1
    last = max(anchors) if anchors else -1
    single_name = len(lines) == 1 and not has_document_metadata
    selected = []
    for number, raw, strong, rx_context in prepared:
        if strong or rx_context or manual_input or single_name or first < number < last:
            # Retain unknown product names in a real medicine region, not prose.
            if strong or len(source_identity(raw)["name"].split()) <= 5:
                selected.append((number, raw))
    return selected

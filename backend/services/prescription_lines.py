"""Classify document rows before catalog matching, independently of templates.

Rx location alone is not evidence. Bare unknown text stays in a separate review
tray; names with a strength/form remain reviewable medicine candidates.
"""
import re
from services.normalization import FORMS, normalize_text, source_identity

ARABIC = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+")
LATIN_NAME = re.compile(r"[A-Za-z]{2,}")
RX_ONLY = re.compile(r"^(?:r\s*/?\s*x|℞|medications?|medicines?|treatment|prescription)\s*[:.\-]?\s*$", re.I)
RX_PREFIX = re.compile(r"^(?:r\s*/?\s*x|℞)\s*[:.\-]?\s+", re.I)
FIELD = re.compile(
    r"^(?:name|age|patient(?:\s+name)?|patient\s*id|dob|date(?:\s+of\s+birth)?|"
    r"sex|gender|address|phone|tel|telephone|mobile|email|diagnosis|"
    r"allergies|weight|height|blood\s+pressure|page)\b", re.I)
FOOTER = re.compile(
    r"^(?:(?:assistant|associate)\s+)?(?:prof(?:essor)?\.?\b|dr[.\s:]|doctor\b|"
    r"prescriber\b|signature\b|signed\b|consultant\b)|"
    r"\b(?:specialist|urologist|physician|surgeon|m\.?\s*d\.?)\s*[.,]?$", re.I)
AGE = re.compile(r"^(?:\d+\s*)?(?:years?\s*old|yrs?(?:\s*old)?|y\s*/?\s*o)\s*[.,]?$", re.I)
INSTITUTION = re.compile(r"\b(?:hospital|clinic|medical\s+cent(?:er|re)|health\s+cent(?:er|re))\b", re.I)
INSTRUCTION_START = re.compile(
    r"^(?:take|use|apply|swallow|repeat|avoid|increase|reduce|continue|stop|"
    r"follow\s*up|next\s+visit)\b", re.I)
# Full-word grammar vocabulary: Thenex and Dailycare are NOT stopwords.
INSTRUCTION_WORDS = set("""
at bed time bedtime night morning evening noon before after with without food
meal meals breakfast lunch dinner sleep then and or for every once twice daily
nightly weekly monthly as needed necessary directed when if pain orally oral po
bid tid qid od bd tds qhs hs prn per day days week weeks month months hour hours
min mins minute minutes x one two three half tablet tablets capsule capsules
""".split()) | FORMS | {"mg", "mcg", "g", "ml", "iu"}
NON_NAMES = INSTRUCTION_WORDS | {"rx", "years", "old"}
QUOTED_MAKER = re.compile(r'^[“"][A-Za-z][^"”]*["”]$')


def english_part(raw: str) -> str:
    text = ARABIC.sub(" ", raw)
    text = re.sub(r"[\u200e\u200f\u202a-\u202e\u2066-\u2069]", "", text)
    return re.sub(r"[ \t]+", " ", text).strip(" :;,-")


def instruction_only(raw: str) -> bool:
    if INSTRUCTION_START.match(raw.lstrip(" .,-")):
        return True
    words = re.findall(r"[a-z]+", normalize_text(raw))
    return bool(words) and all(word in INSTRUCTION_WORDS for word in words)


def _has_name(identity: dict) -> bool:
    name = identity["name"]
    return bool(LATIN_NAME.search(name)) and name.lower() not in NON_NAMES


def _strong(identity: dict, index: dict) -> bool:
    return _has_name(identity) and (
        bool(index.get("brand_index", {}).get(identity["name"])) or
        bool(identity["strength"] or identity["dosageForm"]) and
        len(identity["name"].split()) <= 6
    )


def classify_prescription_lines(text: str, index: dict, *, manual_input=False,
                                document_input=False) -> dict:
    # Empty rows/pages prevent attaching a dose from another region to a name.
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    prepared = []
    in_footer = False
    field_value_pending = False
    has_metadata = False
    for number, original in enumerate(lines):
        if "\f" in original:
            in_footer, field_value_pending = False, False
            continue
        raw = english_part(original)
        if not raw:
            continue
        if RX_ONLY.fullmatch(raw):
            in_footer, field_value_pending, has_metadata = False, False, True
            continue
        inline_rx = RX_PREFIX.match(raw)
        if inline_rx:
            raw = raw[inline_rx.end():].strip()
            in_footer, field_value_pending, has_metadata = False, False, True
        field = FIELD.match(raw)
        if field:
            field_value_pending = not raw[field.end():].strip(" :.-")
            has_metadata = True
            continue
        if FOOTER.search(raw.lstrip(" .,-")):
            in_footer, field_value_pending, has_metadata = True, False, True
            continue
        if AGE.fullmatch(raw) or INSTITUTION.search(raw):
            has_metadata = True
            continue
        identity = source_identity(raw)
        # Keep standalone strengths for adjacency checks, not as medicines.
        details_only = bool(identity["strength"]) and not _has_name(identity)
        if (instruction_only(raw) or not LATIN_NAME.search(raw)) and not details_only:
            continue
        if field_value_pending and not _strong(identity, index):
            field_value_pending = False
            continue
        field_value_pending = False
        if in_footer:
            if not _strong(identity, index):
                continue
            in_footer = False
        prepared.append((number, raw))

    selected, uncertain = [], []
    single_legacy_name = (not document_input and not has_metadata and
                          sum(bool(line.strip()) for line in lines) == 1)
    cursor = 0
    while cursor < len(prepared):
        number, raw = prepared[cursor]
        identity = source_identity(raw)
        # Wrapped name / optional quoted maker / strength: adjacent rows only.
        if _has_name(identity) and not identity["strength"] and len(identity["name"].split()) <= 6:
            next_cursor = cursor + 1
            if next_cursor < len(prepared):
                next_number, next_raw = prepared[next_cursor]
                if next_number == number + 1 and QUOTED_MAKER.fullmatch(next_raw):
                    next_cursor += 1
                if next_cursor < len(prepared):
                    next_number, next_raw = prepared[next_cursor]
                    details = source_identity(next_raw)
                    if (next_number == number + next_cursor - cursor and
                            details["strength"] and not _has_name(details)):
                        raw = raw + " " + next_raw
                        identity = source_identity(raw)
                        cursor = next_cursor
        cursor += 1
        if not _has_name(identity) or instruction_only(raw):
            continue
        if _strong(identity, index) or manual_input or single_legacy_name:
            selected.append((number, raw))
        else:
            uncertain.append({"text": raw, "sourceLine": number,
                              "reason": "no_medication_evidence"})
    return {"medicationLines": selected, "uncertainText": uncertain}


def medication_lines(text: str, index: dict, *, manual_input=False) -> list[tuple[int, str]]:
    """Compatibility accessor; new callers should also retain uncertainText."""
    return classify_prescription_lines(text, index, manual_input=manual_input)["medicationLines"]

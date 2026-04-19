import re
from typing import Optional


DOSAGE_FORMS = [
    "tab", "tabs", "tablet", "tablets",
    "cap", "caps", "capsule", "capsules",
    "syrup", "syp", "susp", "suspension",
    "drop", "drops",
    "cream", "ointment", "oint", "gel", "spray",
    "vial", "amp", "ampoule", "inj", "injection",
    "ear drop", "eye drop",
]


FORM_ALIASES = {
    "tabs": "tab",
    "tablet": "tab",
    "tablets": "tab",
    "caps": "cap",
    "capsule": "cap",
    "capsules": "cap",
    "syp": "syrup",
    "suspension": "susp",
    "drops": "drop",
    "oint": "ointment",
    "ampoule": "amp",
    "injection": "inj",
}


NOISE_WORDS = {
    "syria", "turkey", "uk", "svitz", "akmus", "bp", "free",
    "sugar", "paediatric", "pediatric", "exp", "expectorant",
}


def normalize_text(text: str) -> str:
    if not text:
        return ""

    text = str(text).strip().lower()

    text = text.replace("×", "x")
    text = text.replace("_", " ")
    text = text.replace("-", " ")

    # spacing around slash but keep ratios readable
    text = re.sub(r"\s*/\s*", "/", text)

    # 500mg -> 500 mg
    text = re.sub(r"(\d+(?:\.\d+)?)(mg|ml|mcg|g|kg|iu)\b", r"\1 \2", text, flags=re.I)

    # tab500 -> tab 500 / ampiclox500 -> ampiclox 500
    text = re.sub(r"([a-zA-Z])(\d)", r"\1 \2", text)
    text = re.sub(r"(\d)([a-zA-Z])", r"\1 \2", text)

    # remove punctuation except useful chars
    text = re.sub(r"[^\w\s/+.%]", " ", text)

    # unify spaces
    text = re.sub(r"\s+", " ", text).strip()

    # normalize dosage form aliases token by token
    tokens = []
    for tok in text.split():
        tokens.append(FORM_ALIASES.get(tok, tok))

    return " ".join(tokens).strip()


def extract_strength(text: str) -> Optional[str]:
    if not text:
        return None

    text = normalize_text(text)

    patterns = [
        r"\b\d+(?:\.\d+)?\s?(?:mg|ml|mcg|g|iu)\s*/\s*\d+(?:\.\d+)?\s?(?:ml|mg|g)\b",
        r"\b\d+(?:\.\d+)?\s?(?:mg|ml|mcg|g|iu)\b",
        r"\b\d+(?:\.\d+)?\s?%\b",
    ]

    for pattern in patterns:
        m = re.search(pattern, text, flags=re.I)
        if m:
            val = re.sub(r"\s+", " ", m.group(0)).strip()
            val = val.replace(" / ", "/")
            return val

    return None


def extract_dosage_form(text: str) -> Optional[str]:
    if not text:
        return None

    text = normalize_text(text)

    multi_word_forms = ["ear drop", "eye drop"]
    for form in multi_word_forms:
        if form in text:
            return form

    tokens = text.split()
    for tok in tokens:
        if tok in FORM_ALIASES:
            tok = FORM_ALIASES[tok]
        if tok in {
            "tab", "cap", "syrup", "susp", "drop",
            "cream", "ointment", "gel", "spray",
            "vial", "amp", "inj",
        }:
            return tok

    return None


def clean_brand_name(text: str) -> str:
    text = normalize_text(text)

    strength = extract_strength(text)
    if strength:
        text = text.replace(strength, " ")

    dosage_form = extract_dosage_form(text)
    if dosage_form:
        text = re.sub(rf"\b{re.escape(dosage_form)}\b", " ", text)

    # remove pack counts like 50tab / 20 tabs after spacing normalization
    text = re.sub(r"\b\d+\s?(tab|cap)\b", " ", text, flags=re.I)

    tokens = []
    for tok in text.split():
        if tok in NOISE_WORDS:
            continue
        if re.fullmatch(r"\d+", tok):
            continue
        tokens.append(tok)

    text = " ".join(tokens)
    text = re.sub(r"\s+", " ", text).strip()
    return text
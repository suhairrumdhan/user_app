import re
from decimal import Decimal
from typing import Optional

DOSAGE_FORMS = [
    'tab', 'tabs', 'tablet', 'tablets',
    'cap', 'caps', 'capsule', 'capsules',
    'syrup', 'syp', 'susp', 'suspension',
    'drop', 'drops',
    'cream', 'ointment', 'oint', 'gel', 'spray',
    'vial', 'amp', 'ampoule', 'inj', 'injection',
    'ear drop', 'eye drop',
]

FORM_ALIASES = {
    'tabs': 'tab',
    'tablet': 'tab',
    'tablets': 'tab',
    'caps': 'cap',
    'capsule': 'cap',
    'capsules': 'cap',
    'syp': 'syrup',
    'suspension': 'susp',
    'drops': 'drop',
    'oint': 'ointment',
    'ampoule': 'amp',
    'injection': 'inj',
}

NOISE_WORDS = {
    'syria', 'turkey', 'uk', 'svitz', 'akmus', 'bp', 'free',
    'sugar', 'paediatric', 'pediatric', 'exp', 'expectorant',
}

GENERIC_STOPWORDS = {
    'and', 'or', 'with', 'for', 'the', 'of', 'to', 'in', 'by', 'a', 'an'
}


def normalize_text(text: str) -> str:
    if not text:
        return ''

    text = str(text).strip().lower()
    text = text.replace('×', 'x')
    text = text.replace('_', ' ')
    text = text.replace('-', ' ')
    text = re.sub(r'(\d+(?:\.\d+)?)\s*gm\b', r'\1 g', text, flags=re.I)
    text = re.sub(r'\s*/\s*', '/', text)
    text = re.sub(r'(\d+(?:\.\d+)?)(mg|ml|mcg|g|kg|iu)\b', r'\1 \2', text, flags=re.I)
    text = re.sub(r'([a-zA-Z])(\d)', r'\1 \2', text)
    text = re.sub(r'(\d)([a-zA-Z])', r'\1 \2', text)
    text = re.sub(r'[^\w\s/+.%]', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()

    tokens = []
    for tok in text.split():
        tokens.append(FORM_ALIASES.get(tok, tok))

    return ' '.join(tokens).strip()


def extract_strength(text: str) -> Optional[str]:
    if not text:
        return None

    text = normalize_text(text)
    patterns = [
        r'\b\d+(?:\.\d+)?\s?(?:mg|ml|mcg|g|iu)\s*/\s*\d+(?:\.\d+)?\s?(?:ml|mg|g)\b',
        r'\b\d+(?:\.\d+)?\s?(?:mg|ml|mcg|g|iu)\b',
        r'\b\d+(?:\.\d+)?\s?%\b',
    ]

    for pattern in patterns:
        match = re.search(pattern, text, flags=re.I)
        if match:
            value = re.sub(r'\s+', ' ', match.group(0)).strip()
            value = value.replace(' / ', '/')
            # 1 g and 1000 mg describe the same strength, unlike 500 mg.
            simple_grams = re.fullmatch(r'(\d+(?:\.\d+)?)\s?g', value)
            if simple_grams:
                milligrams = Decimal(simple_grams.group(1)) * 1000
                return f'{milligrams.normalize():f} mg'
            return value

    return None


def extract_dosage_form(text: str) -> Optional[str]:
    if not text:
        return None

    text = normalize_text(text)

    for form in ['ear drop', 'eye drop']:
        if form in text:
            return form

    for tok in text.split():
        tok = FORM_ALIASES.get(tok, tok)
        if tok in {
            'tab', 'cap', 'syrup', 'susp', 'drop',
            'cream', 'ointment', 'gel', 'spray',
            'vial', 'amp', 'inj',
        }:
            return tok

    return None


def clean_brand_name(text: str) -> str:
    text = normalize_text(text)

    strength = extract_strength(text)
    if strength:
        text = text.replace(strength, ' ')

    dosage_form = extract_dosage_form(text)
    if dosage_form:
        text = re.sub(rf'\b{re.escape(dosage_form)}\b', ' ', text)

    text = re.sub(r'\b\d+\s?(tab|cap)\b', ' ', text, flags=re.I)

    tokens = []
    for tok in text.split():
        if tok in NOISE_WORDS:
            continue
        if tok in GENERIC_STOPWORDS:
            continue
        if re.fullmatch(r'\d+', tok):
            continue
        tokens.append(tok)

    cleaned = ' '.join(tokens)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned if len(cleaned) >= 3 else ''


def tokenize_text(text: str) -> list[str]:
    normalized = normalize_text(text)
    return [tok for tok in normalized.split() if tok and tok not in GENERIC_STOPWORDS]

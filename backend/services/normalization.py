"""Lexical normalization only. Never infer ingredients, strengths or substitutes."""
import re
from decimal import Decimal
from typing import Optional

FORM_ALIASES = {
    'tabs': 'tab', 'tablet': 'tab', 'tablets': 'tab',
    'caps': 'cap', 'capsule': 'cap', 'capsules': 'cap',
    'syp': 'syrup', 'syrp': 'syrup', 'suspension': 'susp',
    'drops': 'drop', 'oint': 'ointment', 'ampoule': 'amp',
    'ampoules': 'amp', 'injection': 'inj', 'injectable': 'inj',
    'sachet': 'sach', 'sachets': 'sach', 'suppository': 'supp',
    'suppositories': 'supp', 'solution': 'sol', 'patches': 'patch',
}
FORMS = {'tab', 'cap', 'syrup', 'susp', 'drop', 'cream', 'ointment',
         'gel', 'spray', 'vial', 'amp', 'inj', 'sach', 'supp', 'sol',
         'inhaler', 'patch', 'lotion', 'powder'}
ROUTES = {'iv', 'im'}
NUMBER = r'(?:\d+(?:\.\d+)?|\.\d+)'
UNIT = r'(?:mcg|mg|g|iu|%)'
# Compare every component, not only the first strength in a combination.
DOSE_RE = re.compile(
    rf'(?<![\w.,]){NUMBER}(?:\s*/\s*{NUMBER})*\s*{UNIT}'
    rf'(?:\s*/\s*(?:{NUMBER}\s*)?(?:ml|mg|g))?(?!\w)', re.I)
GLUED_UNIT_SCHEDULE_RE = re.compile(
    r'(?<=\d)(mcg|mg|ml|iu|g)(?=\d+\s*[x×]\s*\d+)', re.I)


def normalize_text(text: str) -> str:
    text = str(text or '').strip().lower().replace('×', 'x').replace('µ', 'u').replace('μ', 'u')
    # 50,000 could be a thousands separator or a decimal in another market.
    # Retain ambiguous notation instead of guessing a clinically different dose.
    text = re.sub(r'(\d+),(\d+)', lambda m: m.group() if len(m[2]) == 3 and m[1] != '0'
                  else m[1] + '.' + m[2], text)
    text = text.replace('_', ' ').replace('-', ' ')
    # PDF extraction can glue a dosage unit to the following schedule.
    # Split only a known unit followed by a numeric x-schedule, not brand digits.
    text = GLUED_UNIT_SCHEDULE_RE.sub(r'\1 ', text)
    text = re.sub(r'\b(?:micrograms?|ug)\b', 'mcg', text)
    text = re.sub(r'\bmilligrams?\b', 'mg', text)
    text = re.sub(r'\bmillilit(?:er|re)s?\b', 'ml', text)
    text = re.sub(r'(?<=\d)(?=[a-z])', ' ', text)
    text = re.sub(r'\bgm\b', 'g', text)
    text = re.sub(r'[^\w\s/+.,%]', ' ', text)
    text = re.sub(r'\s*/\s*', '/', text)
    return ' '.join(FORM_ALIASES.get(token, token) for token in text.split())


def _number(value: Decimal) -> str:
    return f'{value.normalize():f}'


def _canonical_dose(value: str) -> str:
    match = re.fullmatch(
        rf'({NUMBER}(?:/{NUMBER})*)\s*({UNIT})'
        rf'(?:/(?:({NUMBER})\s*)?(ml|mg|g))?', value)
    if not match:
        return value
    amounts, unit, denominator, denominator_unit = match.groups()
    factor = Decimal(1000) if unit == 'g' else Decimal(1)
    if unit == 'g':
        unit = 'mg'
    values = [Decimal(n) * factor for n in amounts.split('/')]
    if denominator_unit:
        divisor = Decimal(denominator or '1')
        if divisor == 0:
            return value
        if denominator_unit == 'g':
            divisor *= 1000
            denominator_unit = 'mg'
        values = [n / divisor for n in values]
    suffix = f'/{denominator_unit}' if denominator_unit else ''
    return ' + '.join(f'{_number(n)} {unit}{suffix}' for n in values)


def extract_strength(text: str) -> Optional[str]:
    values = [_canonical_dose(m.group()) for m in DOSE_RE.finditer(normalize_text(text))]
    return ' + '.join(values) if values else None


def extract_dosage_form(text: str) -> Optional[str]:
    return next((form for token in normalize_text(text).split()
                 if (form := token.strip('.,')) in FORMS), None)


def strip_posology(text: str) -> str:
    """Drop instructions only at explicit boundaries; preserve the source name."""
    text = re.sub(r'^\s*(?:\d+[.)]|[•*])\s*', '', str(text or '').strip())
    text = GLUED_UNIT_SCHEDULE_RE.sub(r'\1 ', text)
    patterns = [
        r'\b\d+(?:\.\d+)?\s*(?:cc|ml)\s*[x×]\s*\d+',
        r'\b\d+\s*[x×]\s*(?:wk|week)(?=[x×\s]|$)',
        r'\b\d+\s*[x×]\s*\d+(?:\s*[x×]\s*\d+)?',
        r'\b\d+\s*/\s*(?:every|day|week)',
        r'\b(?:every|once|twice|daily|nightly|after meals|before meals|for \d+|po|bid|tid|qid|od)\b',
        r'\b(?:then|at\s+(?:bed\s*time|night)|(?:with|after|before)\s+(?:food|meals?|breakfast|dinner))\b',
        r'\bx\s*\d+\s*(?:days?|weeks?|months?)\b',
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.I)
        if match and match.start() > 0:
            text = text[:match.start()]
    return text.strip(' :;,-')


def clean_brand_name(text: str) -> str:
    text = normalize_text(strip_posology(text))
    has_strength = extract_strength(text) is not None
    text = DOSE_RE.sub(' ', text)
    text = re.sub(r'/\s*(?=\d+\s*(?:tab|cap)\b)', ' ', text)
    text = re.sub(rf'(?<!\w){NUMBER}\s*ml\b', ' ', text)
    # Bare numbers can belong to a product name. Only remove explicit pack
    # counts next to a form; preserve decimal numbers without stated units.
    forms = '|'.join(sorted(FORMS, key=len, reverse=True))
    if has_strength:
        text = re.sub(rf'(?<![\w.])\d+\s+({forms})\b', r'\1', text)
        text = re.sub(rf'\b({forms})\s+\d+(?:\s+\d+)*(?![\w.])', r'\1', text)
    tokens = [t for t in text.split() if t.strip('.,') not in FORMS | ROUTES]
    return ' '.join(tokens).strip(' /.')


def source_identity(text: str) -> dict:
    cleaned = strip_posology(text)
    return {'name': clean_brand_name(cleaned), 'strength': extract_strength(cleaned),
            'dosageForm': extract_dosage_form(cleaned), 'text': cleaned}


def tokenize_text(text: str) -> list[str]:
    return normalize_text(text).split()

import os
from flask import Flask, request, jsonify
from flask_cors import CORS

from services.dictionary_builder import build_dictionary_from_csvs, build_search_index
from services.analyzer import analyze_text

app = Flask(__name__)

DEFAULT_CORS_ALLOWED_ORIGINS = (
    "http://localhost:3000",
    "http://localhost:5173",
    "http://localhost:8080",
)


def load_cors_allowed_origins() -> list[str]:
    configured_origins = os.getenv("CORS_ALLOWED_ORIGINS", "")
    origins = (
        configured_origins.split(",")
        if configured_origins.strip()
        else DEFAULT_CORS_ALLOWED_ORIGINS
    )

    allowed_origins = []
    for origin in origins:
        normalized_origin = origin.strip().rstrip("/")
        if not normalized_origin:
            continue
        if normalized_origin == "*":
            raise ValueError(
                "CORS_ALLOWED_ORIGINS must contain explicit origins; '*' is not allowed."
            )
        if not normalized_origin.startswith(("http://", "https://")):
            raise ValueError(
                "Each CORS_ALLOWED_ORIGINS entry must start with http:// or https://."
            )
        allowed_origins.append(normalized_origin)

    if not allowed_origins:
        raise ValueError("CORS_ALLOWED_ORIGINS must contain at least one origin.")

    return allowed_origins


CORS_ALLOWED_ORIGINS = load_cors_allowed_origins()

CORS(
    app,
    resources={r"/*": {"origins": CORS_ALLOWED_ORIGINS}},
    methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
    supports_credentials=False,
    max_age=600,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")

CSV_PATHS = [
    os.path.join(DATA_DIR, "medItems1.csv"),
    os.path.join(DATA_DIR, "medItems2.csv"),
]

MEDICINE_DICTIONARY = []
MEDICINE_INDEX = {}


def load_medicine_data() -> None:
    global MEDICINE_DICTIONARY, MEDICINE_INDEX

    MEDICINE_DICTIONARY = build_dictionary_from_csvs(CSV_PATHS)
    MEDICINE_INDEX = build_search_index(MEDICINE_DICTIONARY)

    print(f"Loaded medicines: {len(MEDICINE_DICTIONARY)}")
    print(f"Index tokens: {len(MEDICINE_INDEX)}")


@app.get("/")
def root():
    return jsonify({
        "service": "medicine-search-api",
        "status": "running",
    })


@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "dictionaryCount": len(MEDICINE_DICTIONARY),
        "indexTokenCount": len(MEDICINE_INDEX),
    })


@app.post("/analyze-prescription")
def analyze_prescription():
    data = request.get_json(silent=True) or {}
    text = str(data.get("text", "")).strip()

    if not text:
        return jsonify({"error": "text is required"}), 400

    result = analyze_text(
        text=text,
        dictionary=MEDICINE_DICTIONARY,
        index=MEDICINE_INDEX,
    )

    return jsonify({
        "status": "success",
        "cleanedText": result["cleanedText"],
        "medicines": result["medicines"],
        "rejectedCandidates": result["rejectedCandidates"],
    })


@app.post("/analyze-manual")
def analyze_manual():
    data = request.get_json(silent=True) or {}
    text = str(data.get("text", "")).strip()

    if not text:
        return jsonify({"error": "text is required"}), 400

    result = analyze_text(
        text=text,
        dictionary=MEDICINE_DICTIONARY,
        index=MEDICINE_INDEX,
    )

    return jsonify({
        "status": "success",
        "medicines": result["medicines"][:5],
    })

load_medicine_data()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)

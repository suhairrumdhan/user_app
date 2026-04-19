from flask import Flask, request, jsonify

from services.dictionary_builder import build_dictionary_from_excel
from services.analyzer import analyze_text

app = Flask(__name__)
EXCEL_PATH = "data/medicines.xlsx"
MEDICINE_DICTIONARY = []




@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "dictionaryCount": len(MEDICINE_DICTIONARY),
    })


@app.post("/analyze-prescription")
def analyze_prescription():
    data = request.get_json(silent=True) or {}
    text = data.get("text", "")

    if not text or not str(text).strip():
        return jsonify({"error": "text is required"}), 400

    result = analyze_text(str(text), MEDICINE_DICTIONARY)

    return jsonify({
        "status": "success",
        "cleanedText": result["cleanedText"],
        "medicines": result["medicines"],
        "rejectedCandidates": result["rejectedCandidates"],
    })


@app.post("/analyze-manual")
def analyze_manual():
    data = request.get_json(silent=True) or {}
    text = data.get("text", "")

    if not text or not str(text).strip():
        return jsonify({"error": "text is required"}), 400

    result = analyze_text(str(text), MEDICINE_DICTIONARY)

    return jsonify({
        "status": "success",
        "medicines": result["medicines"][:5],
    })


if __name__ == "__main__":
    MEDICINE_DICTIONARY = build_dictionary_from_excel(EXCEL_PATH)
    print(f"Loaded medicines: {len(MEDICINE_DICTIONARY)}")
    app.run(host="0.0.0.0", port=5000, debug=True)
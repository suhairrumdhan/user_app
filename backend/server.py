# server.py
from flask import Flask, request, jsonify
import requests
import json
import re

app = Flask(__name__)

OLLAMA_URL = "http://localhost:11434/api/generate"  # Ollama local
OLLAMA_MODEL = "llama3"  # غيّر لاسم الموديل اللي نازله عندك

def fallback_parse(text):
    """Simple regex fallback (لو الـ Ollama مش شغّال)"""
    results = []
    # نبحث عن أنماط: Name ... number unit
    pattern = re.compile(r'([A-Za-z][A-Za-z0-9\s\-]{1,40}?)\s+(\d+)\s*(mg|ml|g|tab|cap|cream|drop)', re.I)
    for m in pattern.finditer(text):
        name = m.group(1).strip()
        dosage = f"{m.group(2)} {m.group(3)}".lower()
        results.append({"name": name, "dosage": dosage, "route": None, "frequency": None, "duration": None})
    return results

@app.route("/analyze", methods=["POST"])
def analyze_text():
    payload = request.get_json(force=True)
    text = payload.get("text", "")
    if not text:
        return jsonify({"medicines": []})

    prompt = f"""
You are an assistant that extracts medication information from a prescription text.
Return ONLY a JSON array of objects, each object must have these keys:
name (string), dosage (string), route (string or null), frequency (string or null), duration (string or null).

Example output:
[
  {{"name": "Suprax Cap", "dosage": "400 mg", "route": "oral", "frequency": "1 daily", "duration": "5 days"}},
  {{"name": "Nipcare Cream", "dosage": "40 ml", "route": "local", "frequency": "1 daily", "duration": "10 days"}}
]

Now extract from this text (do not add extra commentary):
\"\"\"{text}\"\"\"
"""

    try:
        resp = requests.post(
            OLLAMA_URL,
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False
            },
            timeout=20
        )
        resp.raise_for_status()
        data = resp.json()
        raw_output = data.get("response", "") or data.get("output", "") or ""
        raw_output = raw_output.strip()

        # try parse raw output as JSON
        try:
            medicines = json.loads(raw_output)
        except json.JSONDecodeError:
            # حاول نقتطع مصفوفة JSON من النص
            m = re.search(r'\[.*\]', raw_output, re.S)
            if m:
                try:
                    medicines = json.loads(m.group(0))
                except:
                    medicines = []
            else:
                medicines = []

        # تأكد من تنسيق الناتج
        if not isinstance(medicines, list):
            medicines = []

        return jsonify({"medicines": medicines})
    except Exception as e:
        # لو فشلت الـ Ollama أو اتصلت غلط -> استخدم fallback بسيط
        print("OLLAMA ERROR:", e)
        medicines = fallback_parse(text)
        return jsonify({"medicines": medicines, "note": "fallback used, ollama failed", "error": str(e)})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

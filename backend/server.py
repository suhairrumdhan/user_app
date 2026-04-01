from flask import Flask, request, jsonify
import requests
import json
import re
import sqlite3

app = Flask(__name__)

# -------------------------------------------
# إعدادات Ollama
# -------------------------------------------
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "llama3:latest"

# -------------------------------------------
# دالة الاتصال بالمودل
# -------------------------------------------
def call_ollama(prompt, timeout=300):
    resp = requests.post(
        OLLAMA_URL,
        json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False},
        timeout=timeout
    )
    resp.raise_for_status()
    return resp.json()

# -------------------------------------------
# جلب أسماء الأدوية من قاعدة البيانات
# -------------------------------------------
def get_known_drug_names(limit=300):
    conn = sqlite3.connect('medicines.db')
    cursor = conn.cursor()
    cursor.execute("SELECT drug_name, trade_name FROM drugs LIMIT ?", (limit,))
    names = []
    for row in cursor.fetchall():
        for n in row:
            if n:
                names.append(n.strip())
    conn.close()
    return list(set(names))

# -------------------------------------------
# نقطة تحليل النصوص
# -------------------------------------------
@app.route("/analyze", methods=["POST"])
def analyze_text():
    payload = request.get_json(force=True)
    text = payload.get("text", "")
    if not text:
        return jsonify({"medicines": []})

    known_drugs = get_known_drug_names()
    drug_list_text = ", ".join(known_drugs)

    # ----------------------------------------------------------
    # البرومبت الجديد (مُدمَج بالكامل + آمن)
    # ----------------------------------------------------------
    prompt = f"""
You are an assistant specialized in extracting medical prescriptions from messy OCR text.

Your task:
- Extract ONLY medicines and their information from the following text: "{text}"
- Ignore doctor info, names, dates, age, titles, وغيرها.
- Even if the text contains noise or formatting issues, extract medicines correctly.

For every medicine, extract the following fields:
- name: (medicine name only)
- dosage: (e.g., 500 mg, 0.4 mg — return null if missing)
- route: (tablet, capsule, injection, syrup — infer if possible)

Known drug names for reference: {drug_list_text}

Output must be in this EXACT JSON format:

{{
  "medicines": [
    {{
      "name": "",
      "dosage": "",
      "route": ""
    }}
  ]
}}

Rules:
- Do NOT include any text outside the JSON.
- If something is unclear, infer based on common prescription patterns.
- Accept cleaned OCR text even if poorly formatted.
- Return empty array if no medicines found.
"""

    try:
        data = call_ollama(prompt)
        raw_output = data.get("response", "") or data.get("output", "") or ""
        raw_output = raw_output.strip()

        # حاول فك JSON مباشرة
        try:
            result = json.loads(raw_output)
            medicines = result.get("medicines", [])
        except json.JSONDecodeError:
            # البحث عن JSON في النص
            match = re.search(r'\{[^{}]*"medicines"[^{}]*\[.*?\]\s*\}', raw_output, re.DOTALL)
            if match:
                try:
                    result = json.loads(match.group(0))
                    medicines = result.get("medicines", [])
                except:
                    medicines = []
            else:
                medicines = []

        if not isinstance(medicines, list):
            medicines = []

        return jsonify({"medicines": medicines})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# -------------------------------------------
# تشغيل السيرفر
# -------------------------------------------
if __name__ == "__main__":
    ip_address = "172.20.10.4"
    port = 5000
    print("🌐 السيرفر يعمل...")
    print(f"📍 http://{ip_address}:{port}")
    app.run(host=ip_address, port=port, debug=True)
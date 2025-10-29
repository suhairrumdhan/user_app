from flask import Flask, request, jsonify
import requests
import json
import re
import sqlite3

app = Flask(__name__)

# -------------------------------------------
# إعدادات Ollama
# -------------------------------------------
OLLAMA_URL = "http://localhost:11434/api/generate"  # رابط السيرفر المحلي لـ Ollama
OLLAMA_MODEL = "llama3:latest"


# -------------------------------------------
# دالة الاتصال بالمودل
# -------------------------------------------
def call_ollama(prompt, timeout=120):
    """يتصل بـ Ollama ويعيد الناتج كنص"""
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
    """ترجع قائمة بأسماء الأدوية المعروفة (اسم علمي + تجاري)"""
    conn = sqlite3.connect('medicines.db')
    cursor = conn.cursor()
    cursor.execute("SELECT drug_name, trade_name FROM drugs LIMIT ?", (limit,))
    names = []
    for row in cursor.fetchall():
        for n in row:
            if n:
                names.append(n.strip())
    conn.close()
    return list(set(names))  # إزالة التكرار


# -------------------------------------------
# صفحة اختبار بسيطة للتأكد أن السيرفر شغال
# -------------------------------------------
@app.route("/", methods=["GET"])
def home():
    return "✅ PharmaConnect Flask server is running"


# -------------------------------------------
# نقطة تحليل النصوص الطبية
# -------------------------------------------
@app.route("/analyze", methods=["POST"])
def analyze_text():
    payload = request.get_json(force=True)
    text = payload.get("text", "")
    if not text:
        return jsonify({"medicines": []})

    # تحميل أسماء الأدوية من قاعدة البيانات
    known_drugs = get_known_drug_names()
    drug_list_text = ", ".join(known_drugs)

    # بناء الـ prompt
    prompt = f"""
You are a medical text analyzer that extracts medication information from prescription text.

Here is a list of known medicines from the database:
{drug_list_text}
if you didnt get the medicines from the list just extract wjhat ever you think that a medicine

When analyzing the text, use this list to identify any medicine names (even if spelled slightly differently).
Return ONLY a JSON array of objects with these keys:
- name (string)
- dosage (string or null)
- route (string or null)
- frequency (string or null)
- duration (string or null)

Text:
\"\"\"{text}\"\"\"
"""

    try:
        # استدعاء المودل
        data = call_ollama(prompt)
        raw_output = data.get("response", "") or data.get("output", "") or ""
        raw_output = raw_output.strip()

        # محاولة تحويل الناتج إلى JSON
        try:
            medicines = json.loads(raw_output)
        except json.JSONDecodeError:
            m = re.search(r'\[.*\]', raw_output, re.S)
            if m:
                try:
                    medicines = json.loads(m.group(0))
                except Exception:
                    medicines = []
            else:
                medicines = []

        if not isinstance(medicines, list):
            medicines = []

        return jsonify({"medicines": medicines})

    except Exception as e:
        print("❌ OLLAMA ERROR:", e)
        return jsonify({"error": str(e)}), 500


# -------------------------------------------
# تشغيل السيرفر
# -------------------------------------------
if __name__ == "__main__":
    try:
        print("🚀 Flask server running on http://192.168.42.131:5000")
        app.run(host="192.168.42.131", port=5000, debug=True)
    except Exception as e:
        print(f"[ERROR] Cannot start server: {e}")

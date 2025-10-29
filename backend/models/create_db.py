# create_db.py
import sqlite3

conn = sqlite3.connect('medicines.db')
cursor = conn.cursor()

# جدول الأدوية الرئيسي
cursor.execute('''
CREATE TABLE IF NOT EXISTS drugs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drug_name TEXT NOT NULL,
    chemical_name TEXT,
    category TEXT,
    trade_name TEXT,
    uses TEXT,
    side_effect TEXT,
    notes TEXT
)
''')

# جدول الأشكال الدوائية لكل دواء
cursor.execute('''
CREATE TABLE IF NOT EXISTS forms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drug_id INTEGER NOT NULL,
    form TEXT NOT NULL,           -- Tab, Syrup, Injection, Drops...
    trade_name TEXT,
    FOREIGN KEY(drug_id) REFERENCES drugs(id) ON DELETE CASCADE
)
''')

# جدول الجرعات لكل شكل دواء
cursor.execute('''
CREATE TABLE IF NOT EXISTS dosages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    form_id INTEGER NOT NULL,
    dose TEXT NOT NULL,           -- 250mg, 500mg, 1g...
    FOREIGN KEY(form_id) REFERENCES forms(id) ON DELETE CASCADE
)
''')

conn.commit()
conn.close()
print("✅ تم إنشاء قاعدة البيانات والجداول بنجاح!")

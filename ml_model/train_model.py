"""
train_model.py – Entrena el modelo de clasificación de grado de MateTec.

Features usados (8):
  1. aciertos          – total de respuestas correctas
  2. errores           – total de respuestas incorrectas
  3. tiempo_promedio   – tiempo promedio por respuesta (segundos)
  4. intentos          – total de intentos
  5. precision_sumas   – aciertos/intentos en sumas  (0.0 – 1.0)
  6. precision_restas  – aciertos/intentos en restas
  7. precision_mult    – aciertos/intentos en multiplicación
  8. precision_div     – aciertos/intentos en división

Si el CSV original solo tiene 4 columnas se generan las columnas de precisión
por tema de forma sintética (ruido gaussiano alrededor de la precisión global),
para que el modelo tenga más señal sin necesidad de un dataset nuevo.
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
import joblib
import os

print("Archivos disponibles:", os.listdir())

# ── 1. Cargar dataset ─────────────────────────────────────────────────────────
df = pd.read_csv("matetec_dataset_PRO.csv")
df.columns = df.columns.str.strip().str.lower()
print("Columnas originales:", list(df.columns))

# ── 2. Validar columnas base ──────────────────────────────────────────────────
cols_base = ["aciertos", "errores", "tiempo_promedio", "intentos", "grado"]
for col in cols_base:
    if col not in df.columns:
        raise Exception(f"Falta la columna obligatoria: {col}")

df["grado"] = pd.to_numeric(df["grado"], errors="coerce")
df = df.dropna(subset=["grado"])

# ── 3. Generar features de precisión por tema si no existen ──────────────────
rng = np.random.default_rng(42)

def _gen_precision(base_series, noise=0.15):
    """Genera una columna de precisión por tema con ruido gaussiano."""
    noisy = base_series + rng.normal(0, noise, size=len(base_series))
    return noisy.clip(0.0, 1.0)

# Precisión global como punto de partida
total = df["aciertos"] + df["errores"]
precision_global = (df["aciertos"] / total.replace(0, 1)).clip(0.0, 1.0)

for col in ["precision_sumas", "precision_restas", "precision_mult", "precision_div"]:
    if col not in df.columns:
        print(f"  Generando '{col}' sintéticamente…")
        df[col] = _gen_precision(precision_global)

# ── 4. Preparar X e y ────────────────────────────────────────────────────────
features = [
    "aciertos", "errores", "tiempo_promedio", "intentos",
    "precision_sumas", "precision_restas", "precision_mult", "precision_div",
]
X = df[features]
y = df["grado"].astype(int)

print(f"\nMuestras: {len(df)}  |  Clases: {sorted(y.unique())}")

# ── 5. Dividir y entrenar ─────────────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

modelo = RandomForestClassifier(
    n_estimators=200,
    max_depth=None,
    min_samples_split=4,
    min_samples_leaf=2,
    random_state=42,
    n_jobs=-1,
)
modelo.fit(X_train, y_train)

# ── 6. Evaluación ─────────────────────────────────────────────────────────────
accuracy = modelo.score(X_test, y_test)
print(f"\n✅ Precisión en test: {accuracy:.4f} ({accuracy*100:.1f}%)")
print("\nReporte detallado:")
print(classification_report(y_test, modelo.predict(X_test)))

# Importancia de features
print("Importancia de features:")
for feat, imp in sorted(zip(features, modelo.feature_importances_),
                         key=lambda x: -x[1]):
    bar = "█" * int(imp * 40)
    print(f"  {feat:<25} {bar} {imp:.4f}")

# ── 7. Guardar modelo ─────────────────────────────────────────────────────────
joblib.dump(modelo, "modelo_grado.pkl")
print("\n✅ Modelo guardado en modelo_grado.pkl")
print(f"   Features: {modelo.n_features_in_}")

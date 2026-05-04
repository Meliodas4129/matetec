import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

# 🔍 Ver archivos (debug)
print("Archivos:", os.listdir())

# 📊 Cargar dataset
df = pd.read_csv("matetec_dataset_PRO.csv")

# 🔧 Limpiar nombres
df.columns = df.columns.str.strip().str.lower()

print("Columnas:", df.columns)

# ✅ Validar columnas necesarias
columnas_necesarias = ["aciertos", "errores", "tiempo_promedio", "intentos", "grado"]

for col in columnas_necesarias:
    if col not in df.columns:
        raise Exception(f"Falta la columna: {col}")

# ❗ Asegurar que grado sea número
df["grado"] = pd.to_numeric(df["grado"], errors="coerce")

# ❗ Eliminar filas inválidas
df = df.dropna(subset=["grado"])

# 🧠 Variables
X = df[["aciertos", "errores", "tiempo_promedio", "intentos"]]
y = df["grado"]

# 🔀 División
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# 🤖 Modelo
modelo = RandomForestClassifier(n_estimators=100)
modelo.fit(X_train, y_train)

# 📈 Evaluación
accuracy = modelo.score(X_test, y_test)
print("Precisión:", accuracy)

# 💾 Guardar modelo
joblib.dump(modelo, "modelo_grado.pkl")

print("✅ Modelo entrenado y guardado correctamente")
from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np

app = Flask(__name__)
CORS(app)  # Permite conexiones desde Flutter Web / móvil

print("🔥 SERVIDOR NUEVO ACTIVO 🔥")  # 👈 para confirmar que sí es este archivo

# Cargar modelo
modelo = joblib.load("modelo_grado.pkl")

# Traducción de grados
mapa_grados = {
    1: "1° de primaria",
    2: "2° de primaria",
    3: "3° de primaria",
    4: "4° de primaria",
    5: "5° de primaria",
    6: "6° de primaria"
}

@app.route("/clasificar", methods=["POST"])
def clasificar():
    try:
        data = request.get_json()

        if not data:
            return jsonify({"error": "No se enviaron datos"}), 400

        entrada = np.array([[
            int(data.get("aciertos", 0)),
            int(data.get("errores", 0)),
            float(data.get("tiempo_promedio", 0)),
            int(data.get("intentos", 0))
        ]])

        # Predicción
        grado_num = int(modelo.predict(entrada)[0])

        return jsonify({
            "grado": grado_num,  # 👈 número (Flutter lo necesita)
            "descripcion": mapa_grados.get(grado_num)
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
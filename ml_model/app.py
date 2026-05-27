"""
MateTec Flask Server v3
=======================
Endpoints:
  POST /clasificar          – IA adaptativa (clasifica nivel del alumno)
  POST /enviar_resumen      – SCRUM-38: resumen semanal por correo
  POST /enviar_verificacion – correo de verificación de cuenta con diseño MateTec
  POST /enviar_reset        – correo de recuperación de contraseña con diseño MateTec

Requisitos de entorno:
  MATETEC_EMAIL   tu cuenta de Gmail para enviar
  MATETEC_PASS    contraseña de aplicación de Gmail (no la normal)

Para emails de auth también se necesita:
  serviceAccountKey.json  en la misma carpeta que este archivo
  (se descarga desde Firebase Console → Configuración del proyecto → Cuentas de servicio)
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np
import smtplib, os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime

app = Flask(__name__)
CORS(app)

print("🔥 SERVIDOR MATETEC v3 ACTIVO 🔥")

# ── Cargar modelo de IA ───────────────────────────────────────────────────────
modelo = joblib.load("modelo_grado.pkl")

# ── Traducción de niveles ─────────────────────────────────────────────────────
mapa_grados = {
    1: "Nivel Inicial",
    2: "Nivel Básico",
    3: "Nivel Intermedio",
    4: "Nivel Avanzado",
    5: "Nivel Superior",
    6: "Nivel Experto",
}

# ── SMTP ──────────────────────────────────────────────────────────────────────
SMTP_USER = os.environ.get("MATETEC_EMAIL", "")
SMTP_PASS = os.environ.get("MATETEC_PASS", "")
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587

# ── Firebase Admin SDK (opcional – para emails de auth) ───────────────────────
ADMIN_OK = False
admin_auth = None

try:
    import firebase_admin
    from firebase_admin import credentials, auth as _admin_auth

    cred_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "serviceAccountKey.json")
    if os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        admin_auth = _admin_auth
        ADMIN_OK = True
        print("✅ Firebase Admin SDK listo")
    else:
        print("⚠️  serviceAccountKey.json no encontrado → /enviar_verificacion y /enviar_reset desactivados")
        print("   Descárgalo: Firebase Console → Configuración → Cuentas de servicio → Generar nueva clave")
except ImportError:
    print("⚠️  firebase-admin no instalado → ejecuta: pip install firebase-admin")
except Exception as e:
    print(f"⚠️  Error al inicializar Firebase Admin: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# Helpers internos
# ─────────────────────────────────────────────────────────────────────────────

def _smtp_check():
    """Devuelve mensaje de error si SMTP no está configurado, o None si está OK."""
    if not SMTP_USER or not SMTP_PASS:
        return ("Correo no configurado. "
                "Define MATETEC_EMAIL y MATETEC_PASS como variables de entorno.")
    return None

def _send_email(destino: str, asunto: str, html: str, texto: str = ""):
    """Envía un correo con cuerpo HTML (y texto plano como fallback)."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = asunto
    msg["From"]    = f"MateTec 📐 <{SMTP_USER}>"
    msg["To"]      = destino

    if texto:
        msg.attach(MIMEText(texto, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
        s.ehlo()
        s.starttls()
        s.login(SMTP_USER, SMTP_PASS)
        s.sendmail(SMTP_USER, [destino], msg.as_string())


def _html_envelope(titulo: str, subtitulo: str, contenido: str) -> str:
    """Plantilla HTML base con el diseño de MateTec."""
    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{titulo}</title>
</head>
<body style="margin:0;padding:0;background:#f0f0f0;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f0f0;padding:32px 16px;">
  <tr><td align="center">
  <table width="560" cellpadding="0" cellspacing="0"
         style="background:#ffffff;border-radius:20px;overflow:hidden;
                box-shadow:0 4px 20px rgba(0,0,0,.12);max-width:560px;width:100%;">

    <!-- ENCABEZADO ROJO -->
    <tr>
      <td style="background:linear-gradient(135deg,#E53935 0%,#C62828 100%);
                 padding:32px 36px;text-align:center;">
        <p style="margin:0 0 4px;color:rgba(255,255,255,.7);font-size:12px;
                  letter-spacing:2px;text-transform:uppercase;">
          Plataforma educativa
        </p>
        <h1 style="margin:0 0 8px;color:#ffffff;font-size:32px;
                   font-weight:800;letter-spacing:-1px;">
          📐 MateTec
        </h1>
        <p style="margin:0;color:rgba(255,255,255,.85);font-size:15px;">
          {subtitulo}
        </p>
      </td>
    </tr>

    <!-- CONTENIDO -->
    <tr>
      <td style="padding:36px 36px 28px;">
        {contenido}
      </td>
    </tr>

    <!-- PIE DE PÁGINA -->
    <tr>
      <td style="background:#fafafa;padding:20px 36px;text-align:center;
                 border-top:1px solid #f0f0f0;">
        <p style="margin:0 0 4px;font-size:12px;color:#999999;">
          Este correo fue generado automáticamente por MateTec.
        </p>
        <p style="margin:0;font-size:11px;color:#bbbbbb;">
          Si no solicitaste este correo, puedes ignorarlo con seguridad.
        </p>
      </td>
    </tr>

  </table>
  </td></tr>
</table>
</body>
</html>"""


def _btn(link: str, texto: str, color: str = "#E53935") -> str:
    """Botón CTA para emails HTML (compatible con clientes de correo)."""
    return f"""
    <table cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td align="center" style="padding:8px 0;">
          <a href="{link}"
             style="display:inline-block;background:{color};color:#ffffff;
                    text-decoration:none;font-size:16px;font-weight:700;
                    padding:16px 40px;border-radius:14px;
                    letter-spacing:.3px;">
            {texto}
          </a>
        </td>
      </tr>
    </table>"""


def _info_box(icono: str, titulo: str, texto: str, color: str = "#E53935") -> str:
    return f"""
    <table cellpadding="0" cellspacing="0" width="100%"
           style="background:{color}0d;border:1px solid {color}33;
                  border-radius:12px;margin:16px 0;">
      <tr>
        <td style="padding:14px 16px;">
          <p style="margin:0 0 4px;font-size:14px;font-weight:700;color:{color};">
            {icono} {titulo}
          </p>
          <p style="margin:0;font-size:13px;color:#555555;line-height:1.5;">
            {texto}
          </p>
        </td>
      </tr>
    </table>"""


def _stat_card(emoji, label, value, color):
    return f"""
    <td width="25%" align="center" style="padding:4px;">
      <div style="background:{color}18;border-radius:12px;padding:14px 8px;">
        <p style="margin:0;font-size:20px;">{emoji}</p>
        <p style="margin:4px 0 0;font-size:18px;font-weight:700;color:{color};">{value}</p>
        <p style="margin:2px 0 0;font-size:11px;color:#888888;">{label}</p>
      </div>
    </td>"""


# ─────────────────────────────────────────────────────────────────────────────
# POST /clasificar
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/clasificar", methods=["POST"])
def clasificar():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No se enviaron datos"}), 400

        aciertos        = int(data.get("aciertos", 0))
        errores         = int(data.get("errores", 0))
        tiempo_promedio = float(data.get("tiempo_promedio", 0))
        intentos        = int(data.get("intentos", 0))
        precision_sumas  = float(data.get("precision_sumas", 0.0))
        precision_restas = float(data.get("precision_restas", 0.0))
        precision_mult   = float(data.get("precision_mult", 0.0))
        precision_div    = float(data.get("precision_div", 0.0))

        n_features = modelo.n_features_in_
        if n_features >= 8:
            entrada = np.array([[
                aciertos, errores, tiempo_promedio, intentos,
                precision_sumas, precision_restas, precision_mult, precision_div
            ]])
        else:
            entrada = np.array([[aciertos, errores, tiempo_promedio, intentos]])

        grado_num = int(modelo.predict(entrada)[0])

        precisiones = {
            "sumas":          precision_sumas,
            "restas":         precision_restas,
            "multiplicación": precision_mult,
            "división":       precision_div,
        }
        tema_debil = min(precisiones, key=precisiones.get) if intentos > 0 else "sumas"

        return jsonify({
            "grado":       grado_num,
            "descripcion": mapa_grados.get(grado_num, f"Nivel {grado_num}"),
            "tema_debil":  tema_debil,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
# POST /enviar_verificacion
# Body: { email, nombre }
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/enviar_verificacion", methods=["POST"])
def enviar_verificacion():
    err = _smtp_check()
    if err:
        return jsonify({"error": err}), 503
    if not ADMIN_OK:
        return jsonify({"error": "Firebase Admin no disponible. Configura serviceAccountKey.json"}), 503

    try:
        data   = request.get_json() or {}
        email  = data.get("email", "").strip()
        nombre = data.get("nombre", "Estudiante").strip() or "Estudiante"

        if not email:
            return jsonify({"error": "Campo 'email' requerido"}), 400

        # Generar link oficial de Firebase
        link = admin_auth.generate_email_verification_link(email)

        contenido = f"""
        <h2 style="margin:0 0 8px;font-size:22px;color:#1a1a1a;font-weight:800;">
          ¡Hola, {nombre}! 👋
        </h2>
        <p style="margin:0 0 24px;font-size:15px;color:#555555;line-height:1.6;">
          Gracias por unirte a <strong>MateTec</strong>. Para activar tu cuenta y
          comenzar a aprender matemáticas, confirma tu correo electrónico.
        </p>

        {_btn(link, "✅ Verificar mi correo")}

        {_info_box("⏰", "El enlace expira en 24 horas",
                   "Si no lo usas a tiempo, puedes pedir uno nuevo desde la aplicación.",
                   "#FF9800")}

        {_info_box("🔒", "¿No creaste una cuenta?",
                   "Puedes ignorar este correo con seguridad. Nadie podrá acceder sin verificar.",
                   "#2196F3")}

        <p style="margin:24px 0 0;font-size:12px;color:#aaaaaa;line-height:1.5;">
          O copia este enlace en tu navegador:<br>
          <span style="color:#E53935;word-break:break-all;">{link}</span>
        </p>"""

        html = _html_envelope(
            "Verifica tu cuenta de MateTec",
            "Confirma tu correo electrónico",
            contenido,
        )

        texto_plano = (
            f"Hola {nombre},\n\n"
            f"Verifica tu cuenta de MateTec haciendo clic en el siguiente enlace:\n\n"
            f"{link}\n\n"
            f"El enlace expira en 24 horas.\n\n"
            f"Si no creaste una cuenta puedes ignorar este mensaje.\n\n"
            f"— El equipo de MateTec"
        )

        _send_email(
            email,
            "Verifica tu cuenta de MateTec 📐",
            html,
            texto_plano,
        )

        return jsonify({"ok": True, "mensaje": f"Correo de verificación enviado a {email}"})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
# POST /enviar_reset
# Body: { email }
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/enviar_reset", methods=["POST"])
def enviar_reset():
    err = _smtp_check()
    if err:
        return jsonify({"error": err}), 503
    if not ADMIN_OK:
        return jsonify({"error": "Firebase Admin no disponible. Configura serviceAccountKey.json"}), 503

    try:
        data  = request.get_json() or {}
        email = data.get("email", "").strip()

        if not email:
            return jsonify({"error": "Campo 'email' requerido"}), 400

        # Generar link oficial de Firebase
        link = admin_auth.generate_password_reset_link(email)

        contenido = f"""
        <h2 style="margin:0 0 8px;font-size:22px;color:#1a1a1a;font-weight:800;">
          Recuperar contraseña 🔑
        </h2>
        <p style="margin:0 0 24px;font-size:15px;color:#555555;line-height:1.6;">
          Recibimos una solicitud para restablecer la contraseña de la cuenta
          asociada a <strong>{email}</strong> en MateTec.
        </p>

        {_btn(link, "🔑 Restablecer contraseña")}

        {_info_box("⏰", "El enlace expira en 1 hora",
                   "Por seguridad, este enlace solo puede usarse una vez.",
                   "#FF9800")}

        {_info_box("🛡️", "¿No solicitaste esto?",
                   "Ignora este correo. Tu contraseña no cambiará a menos que uses el enlace.",
                   "#4CAF50")}

        <p style="margin:24px 0 0;font-size:12px;color:#aaaaaa;line-height:1.5;">
          O copia este enlace en tu navegador:<br>
          <span style="color:#E53935;word-break:break-all;">{link}</span>
        </p>"""

        html = _html_envelope(
            "Recuperar contraseña de MateTec",
            "Restablece tu contraseña",
            contenido,
        )

        texto_plano = (
            f"Recuperar contraseña de MateTec\n\n"
            f"Recibimos una solicitud para restablecer la contraseña de {email}.\n\n"
            f"Haz clic en el siguiente enlace (expira en 1 hora):\n\n"
            f"{link}\n\n"
            f"Si no solicitaste esto, ignora este mensaje.\n\n"
            f"— El equipo de MateTec"
        )

        _send_email(
            email,
            "Recuperar contraseña de MateTec 🔑",
            html,
            texto_plano,
        )

        return jsonify({"ok": True, "mensaje": f"Correo de recuperación enviado a {email}"})

    except admin_auth.UserNotFoundError:
        # Respuesta genérica por seguridad (no revelar si el correo existe)
        return jsonify({"ok": True, "mensaje": "Si existe esa cuenta recibirás un correo."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
# POST /enviar_resumen  (SCRUM-38)
# Body: { destino, nombre, aciertos, errores, racha, puntos, grado, temas }
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/enviar_resumen", methods=["POST"])
def enviar_resumen():
    err = _smtp_check()
    if err:
        return jsonify({"error": err}), 503

    try:
        data     = request.get_json() or {}
        destino  = data.get("destino", "")
        nombre   = data.get("nombre",  "Estudiante")
        aciertos = int(data.get("aciertos", 0))
        errores  = int(data.get("errores",  0))
        racha    = int(data.get("racha",    0))
        puntos   = int(data.get("puntos",   0))
        grado    = str(data.get("grado",    ""))
        temas    = data.get("temas", {})

        if not destino:
            return jsonify({"error": "Campo 'destino' requerido"}), 400

        total = aciertos + errores
        pct   = round(aciertos / total * 100) if total > 0 else 0
        semana = datetime.now().strftime("%-d de %B, %Y")

        nombres_temas = {
            "sumas":          ("➕", "Sumas"),
            "restas":         ("➖", "Restas"),
            "multiplicacion": ("✖️", "Multiplicación"),
            "division":       ("➗", "División"),
        }

        filas = ""
        for clave, (icono, etiqueta) in nombres_temas.items():
            t   = temas.get(clave, {})
            ac  = int(t.get("aciertos", 0))
            int_ = int(t.get("intentos", 0))
            p_t = round(ac / int_ * 100) if int_ > 0 else 0
            color = "#4CAF50" if p_t >= 70 else ("#FF9800" if p_t >= 40 else "#E53935")
            filas += f"""
            <tr style="border-bottom:1px solid #f5f5f5;">
              <td style="padding:10px 12px;font-size:14px;">{icono} {etiqueta}</td>
              <td style="padding:10px 12px;text-align:center;font-size:14px;">{ac}/{int_}</td>
              <td style="padding:10px 12px;">
                <div style="background:#f0f0f0;border-radius:6px;height:8px;width:100%;">
                  <div style="background:{color};border-radius:6px;
                              height:8px;width:{p_t}%;"></div>
                </div>
                <span style="font-size:11px;color:{color};font-weight:700;">{p_t}%</span>
              </td>
            </tr>"""

        estadisticas = f"""
        <table cellpadding="0" cellspacing="0" width="100%" style="margin:20px 0;">
          <tr>
            {_stat_card("🎯", "Aciertos", str(aciertos), "#4CAF50")}
            {_stat_card("📊", "Precisión", f"{pct}%", "#2196F3")}
            {_stat_card("🔥", "Racha", str(racha), "#FF9800")}
            {_stat_card("⭐", "Puntos", str(puntos), "#9C27B0")}
          </tr>
        </table>"""

        nivel_box = f"""
        <table cellpadding="0" cellspacing="0" width="100%"
               style="background:#FFF3E0;border-radius:12px;margin:16px 0;">
          <tr>
            <td style="padding:14px 18px;">
              <p style="margin:0 0 2px;font-size:12px;color:#E65100;">Tu nivel actual</p>
              <p style="margin:0;font-size:17px;font-weight:800;color:#E53935;">{grado}</p>
            </td>
          </tr>
        </table>"""

        tabla_temas = f"""
        <p style="margin:20px 0 8px;font-size:15px;font-weight:700;color:#1a1a1a;">
          Rendimiento por tema
        </p>
        <table cellpadding="0" cellspacing="0" width="100%"
               style="border:1px solid #f0f0f0;border-radius:12px;overflow:hidden;">
          <thead>
            <tr style="background:#fafafa;">
              <th style="padding:10px 12px;text-align:left;font-size:12px;color:#888;">Tema</th>
              <th style="padding:10px 12px;text-align:center;font-size:12px;color:#888;">Resp.</th>
              <th style="padding:10px 12px;text-align:left;font-size:12px;color:#888;">Progreso</th>
            </tr>
          </thead>
          <tbody>{filas}</tbody>
        </table>"""

        contenido = f"""
        <h2 style="margin:0 0 4px;font-size:22px;color:#1a1a1a;font-weight:800;">
          ¡Hola, {nombre}! 👋
        </h2>
        <p style="margin:0 0 20px;font-size:14px;color:#888888;">
          Semana del {semana}
        </p>
        <p style="margin:0 0 20px;font-size:15px;color:#555555;line-height:1.6;">
          Aquí tienes un resumen de tu actividad en MateTec esta semana.
          ¡Sigue así! 💪
        </p>
        {estadisticas}
        {nivel_box}
        {tabla_temas}"""

        html = _html_envelope(
            f"Resumen semanal de {nombre}",
            f"Resumen semanal · {semana}",
            contenido,
        )

        _send_email(destino, f"📐 MateTec – Resumen semanal de {nombre}", html)
        return jsonify({"ok": True, "mensaje": f"Resumen enviado a {destino}"})

    except smtplib.SMTPAuthenticationError:
        return jsonify({"error": "Error de autenticación SMTP. Usa contraseña de aplicación."}), 401
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

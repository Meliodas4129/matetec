# Configuración de correos personalizados — MateTec

## ¿Para qué sirve esto?
En lugar de que Firebase envíe sus correos genéricos (que van al spam),
MateTec puede enviar correos con **diseño propio** desde tu cuenta de Gmail.

Esto aplica a:
- ✅ Correo de verificación de cuenta (al registrarse)
- ✅ Correo de recuperación de contraseña
- ✅ Resumen semanal de estadísticas (SCRUM-38)

---

## Paso 1 — Contraseña de aplicación de Gmail

> ⚠️ No uses tu contraseña normal de Gmail. Necesitas una "contraseña de aplicación".

1. Ve a [myaccount.google.com](https://myaccount.google.com)
2. Seguridad → Verificación en dos pasos (actívala si no la tienes)
3. Seguridad → Contraseñas de aplicaciones
4. Crear nueva → nombre: `MateTec Flask`
5. Copia la contraseña de 16 caracteres que te dá Google

---

## Paso 2 — Service Account de Firebase

Esto es necesario para que Flask pueda generar los links oficiales de verificación
y recuperación de contraseña de Firebase.

1. Ve a [Firebase Console](https://console.firebase.google.com) → tu proyecto MateTec
2. ⚙️ Configuración del proyecto (engrane arriba a la izquierda)
3. Pestaña **Cuentas de servicio**
4. Botón **Generar nueva clave privada**
5. Descarga el archivo JSON
6. **Renómbralo a `serviceAccountKey.json`**
7. **Colócalo en la carpeta `ml_model/`** (junto a `app.py`)

> ⚠️ NUNCA subas este archivo a GitHub. Ya está en `.gitignore`.

---

## Paso 3 — Variables de entorno

Antes de iniciar el servidor Flask, configura en tu terminal:

### Windows (CMD)
```cmd
set MATETEC_EMAIL=tu_correo@gmail.com
set MATETEC_PASS=abcd efgh ijkl mnop
python app.py
```

### Windows (PowerShell)
```powershell
$env:MATETEC_EMAIL = "tu_correo@gmail.com"
$env:MATETEC_PASS  = "abcd efgh ijkl mnop"
python app.py
```

---

## Paso 4 — Instalar dependencias

```cmd
pip install firebase-admin flask flask-cors scikit-learn pandas joblib
```

O usa el script incluido:
```cmd
retrain.bat
```

---

## ¿Funciona sin este setup?

**Sí** — si Flask no está disponible o no está configurado, la app Flutter hace
fallback automático a los correos de Firebase (los genéricos que ya funcionaban).
No hay ningún error visible para el usuario; simplemente recibe el correo de Firebase.

---

## Anti-spam: consejos

1. **Usa Gmail con nombre reconocible** — el correo aparece como "MateTec 📐 <tu@gmail.com>"
2. **Incluye texto plano** — los correos tienen versión HTML y texto, esto ayuda a no ir a spam
3. **Dominio propio (opcional)** — si tienes `@matetec.com`, úsalo como SMTP_USER
   configurando un relay SMTP (ej. Google Workspace, Mailgun, SendGrid)
4. **No uses palabras trampa** — los correos MateTec no dicen "haz clic aquí urgente"
5. **SPF/DKIM** — si usas dominio propio, configura registros SPF y DKIM en tu DNS

---

## Estructura final de ml_model/

```
ml_model/
├── app.py                  ← servidor Flask
├── train_model.py          ← entrenamiento del modelo
├── retrain.bat             ← script para reentrenar
├── modelo_grado.pkl        ← modelo entrenado
├── matetec_dataset_PRO.csv ← dataset
├── serviceAccountKey.json  ← 🔒 NO subir a Git (en .gitignore)
└── SETUP_CORREOS.md        ← este archivo
```

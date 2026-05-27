@echo off
echo ===============================================
echo  MateTec - Reentrenar modelo de IA (8 features)
echo ===============================================
echo.

cd /d "%~dp0"

echo [1/3] Instalando dependencias...
pip install scikit-learn pandas joblib flask flask-cors --quiet

echo.
echo [2/3] Entrenando modelo...
python train_model.py

echo.
echo [3/3] Listo. Reinicia el servidor Flask para aplicar los cambios.
echo   python app.py
echo.
pause

@echo off
chcp 65001 >nul
cd /d "%~dp0app"

call "scripts\ensure_deps.bat" 0
if errorlevel 1 (
    echo.
    echo Falha na verificacao de dependencias.
    pause
    exit /b 1
)

echo ==================================================
echo   AgroCampo MVP (Supabase) iniciado!
echo   Abrindo no navegador: http://localhost:8085
echo   Feche esta janela quando quiser encerrar o app.
echo ==================================================

start "" "http://localhost:8085"
python -m http.server 8085 --directory "build\web"

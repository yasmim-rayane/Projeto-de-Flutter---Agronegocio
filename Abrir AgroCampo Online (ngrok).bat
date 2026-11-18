@echo off
chcp 65001 >nul
cd /d "%~dp0app"

set "PORT=8085"

call "scripts\ensure_deps.bat" 1
if errorlevel 1 (
    echo.
    echo Falha na verificacao de dependencias.
    pause
    exit /b 1
)

echo ==============================================================
echo   Iniciando servidor local na porta %PORT%...
echo ==============================================================
start "AgroCampo Servidor Local" /min cmd /c "python -m http.server %PORT% --bind 127.0.0.1 --directory build\web"

timeout /t 2 /nobreak >nul

echo ==============================================================
echo   Iniciando tunel ngrok para acesso externo (outro Wi-Fi / 4G)
echo   Copie o link "Forwarding" (https://....ngrok-free.app)
echo   e abra no celular ou em outro computador!
echo   Pressione Ctrl+C para encerrar o ngrok quando terminar.
echo ==============================================================
echo.

ngrok http %PORT%

echo.
echo Encerrando servidor local...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
    taskkill /PID %%a /F >nul 2>&1
)
pause

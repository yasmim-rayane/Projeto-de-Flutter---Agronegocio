@echo off
chcp 65001 >nul

set "NEED_NGROK=%~1"
set "SUPABASE_URL=https://gyawsrtbfjsgizbqhikr.supabase.co"
set "SUPABASE_ANON_KEY=sb_publishable_Tke4EmjIwHMBpnhL6Od4pQ_4SyZuZlm"
set "FLUTTER_BIN=C:\src\flutter\bin\flutter.bat"

echo [1/5] Verificando Python...
where python >nul 2>&1
if errorlevel 1 goto install_python
goto check_git

:install_python
echo Python nao encontrado. Instalando Python 3 via winget...
winget install --id Python.Python.3.13 -e --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto fail_python
set "PATH=%LOCALAPPDATA%\Programs\Python\Python313;%LOCALAPPDATA%\Programs\Python\Python313\Scripts;%PATH%"
goto check_git

:fail_python
echo ERRO: Nao foi possivel instalar o Python automaticamente.
echo Instale manualmente em https://www.python.org/downloads/
exit /b 1

:check_git
echo [2/5] Verificando Git...
where git >nul 2>&1
if errorlevel 1 goto install_git
goto check_flutter

:install_git
echo Git nao encontrado. Instalando Git via winget...
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto fail_git
set "PATH=C:\Program Files\Git\cmd;%PATH%"
goto check_flutter

:fail_git
echo ERRO: Nao foi possivel instalar o Git automaticamente.
exit /b 1

:check_flutter
echo [3/5] Verificando Flutter SDK...
where flutter >nul 2>&1
if not errorlevel 1 (
    set "FLUTTER_BIN=flutter"
    goto check_pub
)
if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER_BIN=C:\src\flutter\bin\flutter.bat"
    goto check_pub
)
echo Flutter SDK nao encontrado. Baixando em C:\src\flutter...
if not exist "C:\src" mkdir "C:\src"
git clone --depth 1 -b stable https://github.com/flutter/flutter.git C:\src\flutter
if errorlevel 1 goto fail_flutter
set "FLUTTER_BIN=C:\src\flutter\bin\flutter.bat"
call "%FLUTTER_BIN%" --version
goto check_pub

:fail_flutter
echo ERRO: Falha ao baixar o Flutter SDK.
exit /b 1

:check_pub
echo [4/5] Verificando dependencias do projeto Flutter...
if not exist ".dart_tool\package_config.json" goto run_pub_get
goto check_web_build

:run_pub_get
echo Executando flutter pub get...
call "%FLUTTER_BIN%" pub get
if errorlevel 1 goto fail_pub_get
goto check_web_build

:fail_pub_get
echo ERRO: Falha ao instalar dependencias do pubspec.yaml.
exit /b 1

:check_web_build
if not exist "build\web\index.html" goto run_web_build
goto check_ngrok

:run_web_build
echo Compilando AgroCampo conectado ao Supabase...
call "%FLUTTER_BIN%" build web --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
if errorlevel 1 goto fail_web_build
goto check_ngrok

:fail_web_build
echo ERRO: Falha ao compilar o projeto web.
exit /b 1

:check_ngrok
if not "%NEED_NGROK%"=="1" goto done

echo [5/5] Verificando ngrok...
where ngrok >nul 2>&1
if errorlevel 1 goto install_ngrok
goto check_ngrok_auth

:install_ngrok
echo ngrok nao encontrado. Instalando ngrok via winget...
winget install --id Ngrok.Ngrok -e --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto fail_ngrok
set "PATH=%LOCALAPPDATA%\Microsoft\WindowsApps;%PATH%"
goto check_ngrok_auth

:fail_ngrok
echo ERRO: Nao foi possivel instalar o ngrok automaticamente.
echo Instale manualmente em https://ngrok.com/download
exit /b 1

:check_ngrok_auth
if exist "%LOCALAPPDATA%\ngrok\ngrok.yml" goto done
if exist "%USERPROFILE%\.config\ngrok\ngrok.yml" goto done
echo.
echo O ngrok ainda nao tem um authtoken configurado neste computador.
echo Pegue seu token gratuito em: https://dashboard.ngrok.com/get-started/your-authtoken
set /p "NGROK_TOKEN=Cole seu authtoken do ngrok e pressione Enter: "
if "%NGROK_TOKEN%"=="" goto fail_ngrok_token
ngrok config add-authtoken "%NGROK_TOKEN%"
if errorlevel 1 goto fail_ngrok_token
goto done

:fail_ngrok_token
echo ERRO: Authtoken do ngrok nao configurado.
exit /b 1

:done
echo Todas as dependencias estao prontas!
exit /b 0

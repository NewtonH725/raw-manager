@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo         RAW Manager - Compilazione Release Windows
echo ========================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERRORE] Flutter SDK non trovato nel PATH di sistema.
    echo Assicurati di aver installato Flutter e aggiunto la cartella bin al PATH.
    pause
    exit /b 1
)

echo [1/3] Verifica dipendenze e configurazione...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERRORE] Errore durante 'flutter pub get'.
    pause
    exit /b 1
)

echo.
echo [2/3] Compilazione eseguibile Windows a 64-bit...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERRORE] Compilazione fallita. Assicurati di avere installato:
    echo - Visual Studio 2022 con il carico di lavoro 'Desktop development with C++'
    pause
    exit /b 1
)

echo.
echo [3/3] Creazione pacchetto standalone...
set RELEASE_SRC=build\windows\x64\runner\Release
set DIST_DIR=releases\RAW_Manager_Windows_x64

if not exist "%RELEASE_SRC%\raw_manager.exe" (
    echo [ERRORE] File raw_manager.exe non trovato in %RELEASE_SRC%.
    pause
    exit /b 1
)

if not exist "releases" mkdir releases
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%"

xcopy /E /I /Y "%RELEASE_SRC%\*" "%DIST_DIR%\" >nul
copy /Y "assets\guida_raw_manager.md" "%DIST_DIR%\GUIDA_UTENTE.md" >nul

echo.
echo ========================================================
echo [SUCCESSO] RAW Manager per Windows compilato con successo!
echo.
echo Cartella standalone pronta all'uso:
echo   %DIST_DIR%\raw_manager.exe
echo.
echo Puoi copiare l'intera cartella %DIST_DIR% su qualsiasi PC Windows 10/11!
echo ========================================================
pause

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

echo [1/4] Verifica dipendenze e configurazione...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERRORE] Errore durante 'flutter pub get'.
    pause
    exit /b 1
)

echo.
echo [2/4] Compilazione eseguibile Windows a 64-bit...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERRORE] Compilazione fallita. Assicurati di avere installato:
    echo - Visual Studio 2022 con il carico di lavoro 'Desktop development with C++'
    pause
    exit /b 1
)

echo.
echo [3/4] Creazione pacchetto Portable...
set RELEASE_SRC=build\windows\x64\runner\Release
set DIST_PORTABLE=releases\RAW_Manager_Windows_x64_Portable

if not exist "%RELEASE_SRC%\raw_manager.exe" (
    echo [ERRORE] File raw_manager.exe non trovato in %RELEASE_SRC%.
    pause
    exit /b 1
)

if not exist "releases" mkdir releases
if exist "%DIST_PORTABLE%" rmdir /s /q "%DIST_PORTABLE%"
mkdir "%DIST_PORTABLE%"

xcopy /E /I /Y "%RELEASE_SRC%\*" "%DIST_PORTABLE%\" >nul
copy /Y "assets\guida_raw_manager.md" "%DIST_PORTABLE%\GUIDA_UTENTE.md" >nul

echo [OK] Versione portable creata in %DIST_PORTABLE%

echo.
echo [4/4] Creazione Installer Setup.exe (richiede Inno Setup 6 se installato)...
set ISCC="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist %ISCC% (
    %ISCC% windows\inno_setup.iss
    echo [OK] Installer creato in releases\RAW_Manager_Windows_x64_Setup.exe
) else (
    echo [INFO] Inno Setup 6 non trovato nel percorso predefinito.
    echo Puoi comunque utilizzare direttamente la versione portable in:
    echo   %DIST_PORTABLE%\raw_manager.exe
)

echo.
echo ========================================================
echo [SUCCESSO] Operazione completata!
echo ========================================================
pause

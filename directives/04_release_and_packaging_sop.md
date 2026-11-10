# SOP 04: Compilazione Release, Packaging e Distribuzione Standalone

## 1. Obiettivo
Definire la procedura deterministica di build AOT e impacchettamento degli eseguibili standalone di **RAW Manager** per Windows, Ubuntu Linux e Android, garantendo integrità crittografica e portabilità immediata.

---

## 2. Rilevamento Host e Toolchain
Lo script deterministico `execution/build_releases.py` analizza l'ambiente host:
1. **Rilevamento Sistema Operativo**:
   - `Linux`: Abilita target Linux nativo GTK3. Verifica presenza di `cmake`, `ninja`, `clang`, `pkg-config`, `libgtk-3-dev`.
   - `Windows`: Abilita target Windows Win32 MSVC. Verifica presenza del compilatore C++ Visual Studio.
2. **Rilevamento Toolchain Android**:
   - Verifica `ANDROID_HOME`, `javac` / `java` e `build-tools`.
   - Se l'SDK Android è configurato e le licenze sono accettate, compila automaticamente l'APK di produzione.
3. **Resilienza in assenza di Toolchain**:
   - Se un compilatore (es. C++ Desktop o Android SDK) non è presente o mancano librerie di sistema, lo script non va in crash ma registra istruzioni chiare e comandi di installazione in `.tmp/qa_reports/build_report.txt`, procedendo con i target disponibili.

---

## 3. Comandi di Compilazione e Deliverable

### A. Ubuntu Linux (`RAW_Manager_Ubuntu_x64_Bundle.tar.gz`)
* **Comando di Build**:
  ```bash
  flutter build linux --release
  ```
* **Directory di Output**: `build/linux/x64/release/bundle/`
* **Packaging**:
  - Creazione archivio `.tar.gz` compresso contenente il binario eseguibile `raw_manager`, le librerie condivise `.so` e la cartella `data/`.
  - Destinazione: `releases/RAW_Manager_Ubuntu_x64_Bundle.tar.gz`.

### B. Windows (`RAW_Manager_Windows_x64_Portable.zip`)
* **Comando di Build**:
  ```bash
  flutter build windows --release
  ```
* **Directory di Output**: `build/windows/x64/runner/Release/`
* **Packaging**:
  - Compressione dell'intera cartella (incluso `raw_manager.exe`, `flutter_windows.dll`, plugin DLL e cartella `data/`) in un archivio zip portatile.
  - Destinazione: `releases/RAW_Manager_Windows_x64_Portable.zip`.

### C. Android (`RAW_Manager_Android_arm64.apk`)
* **Comando di Build**:
  ```bash
  flutter build apk --release --split-per-abi
  ```
* **Packaging**:
  - Prelevamento del binario compilato specificamente per architettura 64-bit:
    `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
  - Copia e rinomina in: `releases/RAW_Manager_Android_arm64.apk`.

---

## 4. Manifesto di Integrità SHA-256
Per ogni pacchetto creato nella directory `releases/`:
1. Viene calcolato l'hash crittografico SHA-256.
2. Viene generato o aggiornato il file `releases/SHA256SUMS.txt` nel formato standard:
   ```text
   <hash-sha256>  RAW_Manager_Windows_x64_Portable.zip
   <hash-sha256>  RAW_Manager_Ubuntu_x64_Bundle.tar.gz
   <hash-sha256>  RAW_Manager_Android_arm64.apk
   ```
3. Il report completo di release viene salvato in `.tmp/qa_reports/build_report.txt`.

---

## 5. Note di Auto-Correzione e Vincoli di Compilazione
* **Allineamento `compileSdk = 36` nei Subproject Android**:
  Con Flutter 3.47+ e dipendenze moderne (come `flutter_plugin_android_lifecycle` e `file_picker`), il plugin AAR metadata richiede che tutti i plugin siano compilati almeno con `compileSdk 36`.
  In `android/build.gradle.kts`, configurare:
  ```kotlin
  subprojects {
      if (project.name != "app") {
          project.afterEvaluate {
              project.extensions.findByName("android")?.let { android ->
                  try {
                      val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                      method.invoke(android, 36)
                  } catch (_: Exception) {}
              }
          }
      }
  }
  ```
  Questo evita il blocco `Cannot run Project.afterEvaluate(Action) when the project is already evaluated` su `:app` e forza `compileSdk = 36` su `file_picker` e tutti gli altri subproject.
* **Host Linux Desktop Toolchain**:
  Per compilare il bundle Linux (`RAW_Manager_Ubuntu_x64_Bundle.tar.gz`), l'host richiede i pacchetti di sistema di sviluppo C++ e GTK3:
  `sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev zenity`
* **Host Windows Desktop Toolchain**:
  Per compilare il pacchetto portatile Windows (`RAW_Manager_Windows_x64_Portable.zip`), è necessario eseguire lo script su host Windows con Visual Studio 2022 (carico di lavoro C++ Desktop).

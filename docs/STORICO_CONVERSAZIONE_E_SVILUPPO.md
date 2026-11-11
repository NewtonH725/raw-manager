# RAW Manager - Storico Completo delle Conversazioni, Decisioni e Sviluppo

Questo documento raccoglie in ordine cronologico e tematico tutto lo storico dello sviluppo, le richieste dell'utente, le decisioni architetturali, i bug analizzati e le soluzioni implementate per l'applicazione **RAW Manager**.

---

## 1. Visione del Progetto e Obiettivi Iniziali
- **Scopo:** Creazione di uno strumento ultra-reattivo per fotografi (culling istantaneo con latenza <10ms tra uno scatto e l'altro).
- **Target Principale:** File RAW proprietari Fujifilm `.RAF` (specificamente testato su fotocamera Fujifilm X-T5 da 40.2 MP), con estensione a tutti i formati RAW universali (`.DNG`, `.ARW` Sony, `.NEF` Nikon, `.CR2`/`.CR3` Canon).
- **Piattaforme di Riferimento:**
  - **Linux Desktop (Ubuntu 24.04 x64)** per uso da workstation da campo.
  - **Android (Google Pixel 9 Pro XL / Android 17)** tramite lettore di schede SD esterno connesso via USB-C (USB OTG).
  - **Windows (10/11 x64)** tramite eseguibile standalone portatile e installer guidato.
- **Architettura Master:** Approccio a tre livelli DOE (Directives, Orchestration, Execution):
  - `directives/`: Standard Operating Procedures immutabili per estrazione binaria, caching I/O e QA.
  - `execution/`: Script deterministici Python per dataset sintetici, icone e build.
  - `lib/`: Codice sorgente Flutter multi-piattaforma.

---

## 2. Cronologia delle Richieste dell'Utente e Interventi Eseguiti

### Fase 1: Creazione Core e Motore di Estrazione Binaria (<5ms)
- **Richiesta:** Evitare librerie pesanti o decodifiche complete dei RAW a 40MP per il culling.
- **Implementazione:**
  - Analisi della specifica binaria Fujifilm RAF: lettura dei puntatori diretti a offset `0x54` (offset JPEG) e `0x58` (lunghezza JPEG) all'interno dell'header di 92 byte.
  - Accesso casuale al file (`RandomAccessFile` / `FileChannel`): caricamento dei soli 2-5 MB dell'anteprima JPEG ad alta risoluzione anziché dei 50-80 MB del file RAW completo. Tempo di estrazione misurato: **6.0 ms** su file da 40.2 MP.
  - Fallback automatico per formati TIFF/SubIFD (`0x0201`/`0x0202`) per DNG, ARW, NEF.
  - Finestra di prefetching a scorrimento `[i-2, i+3]` per navigazione istantanea senza attendere l'I/O.

### Fase 2: Gestione Permessi su Android e Pop-up Centrale
- **Richiesta Utente:** *"Sull'applicazione Linux mi compare un banner arancione in alto... è sovrapposto alla notification bar. Creane uno centrale sull'app Android."*
- **Implementazione:**
  - Rimozione del vecchio banner superiore sovrapposto.
  - Implementazione di un pop-up centrale moderno (*Card Material 3*) su sfondo oscurato dedicato ad Android, per la richiesta dell'autorizzazione `MANAGE_EXTERNAL_STORAGE`.

### Fase 3: Debug Critico Scheda SD su Android (USB-C OTG)
- **Problema Segnalato dall'Utente:**
  *"Dall'applicazione Android, seleziono Apri cartella, vado a selezionare la cartella della scheda SD... mi appare un pallino con la i di informazioni con scritto EXIF N/D, ma poi lo schermo è nero e se schiaccio la freccia destra ritorna a 'Nessun file RAW caricato'."*
- **Analisi e Risoluzione a Due Livelli:**
  1. **Bug Riverpod (State Reset):** Nel file `culler_provider.dart`, `cullerProvider` utilizzava `ref.watch(cacheManagerProvider)`. Ogni volta che la cache in background caricava la prima foto e chiamava `notifyListeners()`, Riverpod distruggeva e ricreava il controller con `photos = []`. Risolto passando a `ref.read`.
  2. **Bug Android SAF (Letture parziali su USB OTG):** Nei lettori SD USB-C esterni, `FileChannel.read(buffer)` effettuava letture parziali (solo 8 KB anziché i 2-5 MB del JPEG). L'immagine risultava troncata e visualizzava uno schermo nero. Risolto implementando in Kotlin (`MainActivity.kt`) il loop deterministico `readFully()`.

### Fase 4: Icona Ufficiale del Diaframma Fotografico
- **Richiesta Utente:** *"L'icona del programma, anche su Android, deve essere come l'hai disegnata, circolare, ma deve occupare tutto lo spazio circolare dedicato da Android senza sfondo bianco."*
- **Implementazione:**
  - Estrazione ad alta definizione del glifo ufficiale `Icons.camera_rounded` (`0xf612`) da `MaterialIcons-Regular.otf` in colore ambra `#FFC107`.
  - Configurazione completa di **Adaptive Icons** per Android (`mipmap-anydpi-v26/ic_launcher.xml` e `ic_launcher_round.xml` con sfondo `#181818`), eliminando del tutto la cornice bianca di sistema su Google Pixel.
  - Generazione dell'icona multi-risoluzione `.ico` (16..256px) per Windows e `.png` per Linux.

### Fase 5: Installazione di Sistema su Linux e Repository GitHub
- **Richieste Utente:**
  1. *"Installa su questo pc il programma per linux in modo che mi compaia nel menù dei programmi installati."*
  2. *"Crea repository sul mio account github in modo che possa avere tutto online. Chiama il progetto raw-manager."*
- **Implementazione:**
  - Installazione del bundle nativo in `~/.local/share/raw-manager/`, icona in `~/.local/share/icons/` e creazione di `~/.local/share/applications/raw-manager.desktop` (convalida XDG al 100%).
  - Inizializzazione Git e pubblicazione su GitHub: [https://github.com/NewtonH725/raw-manager](https://github.com/NewtonH725/raw-manager).

### Fase 6: Barra Superiore Material 3 Fissa e Swipe Touch
- **Richiesta Utente:**
  - *"Il riquadro in cui c'è il titolo, logo, tasti e auto advance devono essere una barra superiore che non si va a sovrapporre all'immagine."*
  - *"Su Android abilita anche lo swipe laterale dello schermo per avanzare o arretrare."*
- **Implementazione:**
  - Riprogettazione del layout: la barra comandi è ora un'intestazione solida ancorata in cima (`HudOverlay`), mentre l'immagine occupa interamente l'area sottostante (`Expanded`), garantendo zero sovrapposizione.
  - Implementazione del rilevamento gesture orizzontale touch: swipe a sinistra per foto successiva, swipe a destra per precedente, con disattivazione del panning a zoom 1x per evitare interferenze.

### Fase 7: Eseguibili Windows (Setup Installer & Versione Portable)
- **Richiesta Utente:** *"Mi crei un eseguibile windows installabile? Magari sia la versione portable che la versione installabile."*
- **Implementazione:**
  - Script Inno Setup `windows/inno_setup.iss` per generare `RAW_Manager_Windows_x64_Setup.exe` con interfaccia in italiano, collegamenti desktop/start e disinstallatore.
  - Script batch a un clic `build_windows.bat` per la compilazione locale.
  - Pipeline GitHub Actions `.github/workflows/build_windows.yml` che compila automaticamente su server Windows nel cloud ad ogni push e pubblica entrambe le versioni nella pagina GitHub Releases.

### Fase 8: Documentazione Storica, Guida PDF e Centratura Pixel-Perfect dell'Icona
- **Richieste Utente:**
  1. *"Crea una cartella docs in questo progetto in cui salvi tutto lo storico di quello che ci siamo detti (e lo mantieni aggiornato). Poi crea una guida in pdf con le immagini delle schermate dell'app e aggiungi questa descrizione anche su github."*
  2. *"Nell'icona, centra meglio i petali del diaframma rispetto al cerchio. Al momento sono leggermente decentrati verso l'alto."*
- **Implementazione:**
  - Creazione della cartella `docs/` con il manuale PDF illustrato `RAW_Manager_Guida_Ufficiale.pdf`, gli screenshot ad alta risoluzione e questo storico.
  - Aggiornamento di `README.md` su GitHub e upload diretto del PDF nelle Releases.
  - Analisi del descentramento dell'icona (`13.5px` verso l'alto dovuto alle metriche interne asimmetriche di Pillow `textbbox`) e riscrittura di `execution/generate_app_icon.py` con ritaglio esatto tramite bounding box sui pixel (`Image.getbbox()`) su oversampling 2048px, garantendo una centratura matematica sub-pixel su Android, Linux e Windows.

### Fase 9: Repository Pubblico e Sistema di Auto-Aggiornamento in-App (v1.1.0)
- **Richiesta Utente:** *"Sarebbe possibile creare una funzione che cerchi automaticamente una nuova versione all'avvio dell'app, collegata al repository di github, con pop-up e download automatico del file aggiornato? Opzione 1 (repository pubblico)."*
- **Implementazione:**
  - Cambio visibilità del repository GitHub `NewtonH725/raw-manager` a **Public** per consentire l'accesso nativo senza token all'endpoint ufficiale delle GitHub Releases.
  - Creazione del servizio `lib/services/update_service.dart` per controllo asincrono all'avvio (`releases/latest` con timeout 4-5s per non bloccare l'uso offline sul campo), confronto SemVer e download progressivo mirato per OS (`.apk` su Android, `Setup.exe` su Windows, `.tar.gz` su Linux).
  - Creazione del pop-up Material 3 `lib/ui/widgets/update_dialog.dart` con note di rilascio, confronto versioni e barra di avanzamento download.
  - Supporto nativo Android in `MainActivity.kt` + `AndroidManifest.xml` (`INTERNET`, `REQUEST_INSTALL_PACKAGES`, `FileProvider`) per l'installazione diretta dell'APK scaricato; auto-chiusura e lancio Setup su Windows; aggiornamento automatico `~/.local/share/raw-manager/` su Linux.
  - Pipeline CI dinamica collegata alla versione di `pubspec.yaml` (`1.1.0`).

---

## 3. Riepilogo Stato Artefatti e Repository
- **GitHub Repo:** `https://github.com/NewtonH725/raw-manager`
- **Releases Ufficiali:** `https://github.com/NewtonH725/raw-manager/releases/tag/v1.0.0`
  - `RAW_Manager_Windows_x64_Setup.exe` (Installer Windows)
  - `RAW_Manager_Windows_x64_Portable.zip` (Versione Windows Portatile)
  - `RAW_Manager_Android_arm64.apk` (Pacchetto Android arm64)
  - `RAW_Manager_Ubuntu_x64_Bundle.tar.gz` (Bundle Linux)

# RAW Manager - Guida Installazione ed Esecuzione su Windows 10 / 11

## 1. Come eseguire l'applicazione su Windows
Se hai scaricato o compilato la cartella `RAW_Manager_Windows_x64`:
1. Estrai l'archivio `RAW_Manager_Windows_x64.zip` in una cartella a tua scelta (es. `C:\RAW_Manager`).
2. Fai doppio clic su `raw_manager.exe` per avviare subito l'applicazione.
3. Puoi creare un collegamento sul Desktop cliccando con il tasto destro su `raw_manager.exe` -> *Invia a -> Desktop (crea collegamento)*.

---

## 2. Come compilare direttamente da sorgente sul PC Windows
Se hai trasferito l'intera cartella di questo progetto sul tuo PC Windows:
1. Assicurati di avere installato:
   - **Flutter SDK** (aggiunto al PATH)
   - **Visual Studio 2022** con il carico di lavoro *"Desktop development with C++"* (richiesto da Flutter su Windows).
2. Fai doppio clic sullo script automatico:
   ```cmd
   build_windows.bat
   ```
3. Lo script controllerà l'ambiente, installerà i pacchetti, compilerà la versione ottimizzata a 64-bit e creerà automaticamente la cartella `releases\RAW_Manager_Windows_x64\` pronta all'uso!

---

## 3. Scorciatoie da Tastiera su Windows
- **Spazio**: Seleziona e copia il file RAW nella cartella di destinazione (con auto-advance opzionale).
- **Freccia Destra / J**: Foto successiva.
- **Freccia Sinistra / K**: Foto precedente.
- **Canc / Backspace**: Elimina il file RAW (con conferma o rimozione immediata).
- **Z**: Toggle zoom 100% / Fit to screen.
- **H**: Mostra/nascondi barre e overlay (HUD a schermo intero).
- **I / F1**: Guida e scorciatoie integrate.

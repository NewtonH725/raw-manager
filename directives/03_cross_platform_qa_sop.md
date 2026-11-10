# SOP 03: UX Cross-Platform, Layout Responsive e Quality Assurance (QA)

## 1. Obiettivo
Definire gli standard di interfaccia utente responsive per garantire un'esperienza ottimale sia su laptop da 14" (Dell Latitude 5420 / 7420) sia su workstation desktop con monitor 27" QHD/4K, sia su tablet e smartphone Android, oltre a stabilire i criteri di validazione QA automatizzata.

---

## 2. Principi di Layout Responsive ed Ergonomia Visiva

### Tema e Spazio Visivo
* **Colore di Sfondo Neutro Professionale**: `#121212` (sfondo scuro calibrato per culling fotografico privo di distorsioni visive di contrasto o abbagliamento).
* **Massimizzazione dell'Area Immagine**: L'immagine occupa sempre il 100% dell'area disponibile (`BoxFit.contain`).
* **Qualità di Campionamento**: `FilterQuality.high` obbligatorio sia su desktop che su mobile per preservare la nitidezza dei dettagli e prevenire aliasing nei pattern X-Trans su display ad alta risoluzione (27" HiDPI / 4K).

### HUD Flottante a Scomparsa (Heads-Up Display)
* **Comportamento**:
  - Sovraimpresso in overlay trasparente con sfondo `Colors.black54` e bordi arrotondati.
  - Può essere mostrato o nascosto istantaneamente premendo il tasto `H` da tastiera o con un singolo tap su schermo.
  - Scompare automaticamente su schermi piccoli per non coprire i dettagli della foto.
* **Informazioni Visualizzate nell'HUD**:
  1. Contatore navigazione (es. `42 / 1.250`).
  2. Nome del file `.RAF` corrente.
  3. Badge di stato (`SELEZIONATA ✓` in verde se presente nella cartella destinazione, o badge errore se corrotto).
  4. Metadati EXIF sintetici: Tempo di scatto (es. `1/1000s`), Diaframma (`f/2.8`), ISO (`ISO 400`), Focale (`33mm`).
  5. Stato coda I/O (operazioni in corso e in coda).
  6. Switch rapido "Auto-Advance" (Avanzamento automatico dopo selezione).

---

## 3. Matrice Controlli e Interazioni

| Input / Azione | Desktop (Windows / Ubuntu Linux) | Mobile / Tablet Android |
|---|---|---|
| **Foto Successiva** | Freccia Destra (`RightArrow`) o `J` | Swipe verso sinistra o Pulsante Next (`>`) |
| **Foto Precedente** | Freccia Sinistra (`LeftArrow`) o `K` | Swipe verso destra o Pulsante Prev (`<`) |
| **Seleziona (Copia)** | Barra Spaziatrice (`Space`) | Pulsante circolare verde "Copia" (`✓`) |
| **Elimina Foto** | Tasto `Canc` / `Delete` | Pulsante circolare rosso "Elimina" (`🗑`) |
| **Zoom 100% / Fit** | Tasto `Z` o doppio click mouse | Doppio tap o pinch-to-zoom (`InteractiveViewer`) |
| **Toggle HUD** | Tasto `H` | Singolo tap sullo schermo |
| **Fullscreen** | Tasto `F11` | Modalità immersiva a schermo intero nativa Android |

> **ATTENZIONE GESTIONE TOUCH (SWIPE VS ZOOM)**:
> In modalità zoomata (quando la scala di `InteractiveViewer` è > 1.05x), il gesto dello swipe orizzontale per cambiare foto DEVE essere temporaneamente disabilitato per consentire il panning fluido dell'immagine ingrandita senza cambiare inavvertitamente scatto.

---

## 4. Gestione Permessi su Android
1. Su Android 11+ (API Level 30+), l'accesso alle cartelle DCIM/SD Card con file RAW proprietari richiede `MANAGE_EXTERNAL_STORAGE`.
2. L'app verifica i permessi all'avvio con `permission_handler`. Se non accordati, mostra un banner informativo chiaro che guida l'utente alla schermata di sistema per accordare l'accesso a tutti i file per la gestione RAW.

---

## 5. Procedura di Verifica QA Automatica (`execution/run_verification_suite.py`)
Ogni modifica al codice deve superare la suite di validazione prima di qualunque build:
1. `flutter analyze`: Deve restituire **0 errori** e **0 warning** (`lints: true`).
2. `flutter test`:
   - Esecuzione del test suite su file `.RAF` sintetici validi, corrotti e troncati.
   - Verifica che l'estrazione avvenga in < 10 ms per file.
   - Verifica del corretto accodamento ed esecuzione delle operazioni I/O di copia ed eliminazione.
3. Salvataggio del log completo in `.tmp/qa_reports/latest_report.txt`.

# SOP 02: Gestione Cache in Memoria (Sliding Window), I/O Asincrono e Directory Listing

## 1. Obiettivo
Garantire uno scorrimento a latenza percepita nulla (< 10 ms per transizione immagine) su cartelle contenenti oltre 5.000 file `.RAF`, mantenendo l'impronta di memoria RAM strettamente confinata tra 200 MB e 350 MB su qualsiasi dispositivo (dal Dell Latitude con 24 GB RAM al tablet Android con memoria limitata).

---

## 2. Lazy Directory Listing (Scansione Immediata)
Quando l'utente seleziona una cartella sorgente:
1. **Scansione Shallow Rapida**:
   - Utilizzare `Directory(sourcePath).list(recursive: false, followLinks: false)`.
   - Filtrare unicamente le estensioni case-insensitive: `.toLowerCase().endsWith('.raf')`.
   - Popolare l'elenco dei modelli `RafPhoto` raccogliendo unicamente il path testuale e il nome file, inizializzando `isCopied` a `false` (o controllando se esiste nella cartella di destinazione target) e `jpegBytes` a `null`.
2. **Tempo di Caricamento Iniziale Target**:
   - < 150 ms per 5.000 path di file su SSD NVMe o schede SD UHS-II.
3. **Nessun Decoding Preventivo**:
   - È vietato aprire o parsare i file all'apertura della cartella. Nessun I/O sui file deve avvenire prima della richiesta della finestra visiva.

---

## 3. Sliding Window Memory Cache (`[i-2, i+3]`)

### Definizione della Finestra
Data una collezione di foto e l'indice corrente dell'immagine visualizzata $i$:
* **Indice Corrente**: $i$ (visualizzata a schermo intero)
* **Buffer Precedente (Backward Window)**: $i-1, i-2$ (pronte per ritorno immediato con freccia sinistra)
* **Buffer Successivo (Forward Window)**: $i+1, i+2, i+3$ (pre-caricate in background per scorrimento rapido in avanti)

$$\text{Active Window} = [\max(0, i-2), \min(N-1, i+3)]$$

### Regole Operative di Eviction e Pre-fetching
1. **Eviction Immediata (Zero Memory Leaks)**:
   - Ad ogni cambio di $i$, qualunque immagine memorizzata in RAM il cui indice è fuori dalla finestra $[i-2, i+3]$ viene immediatamente rimossa dalla mappa in memoria (`cacheMap.remove(k)`).
   - Invocare la deallocazione dei buffer `Uint8List` per consentire al Garbage Collector di Dart di reclamare immediatamente i byte.
2. **Pre-fetching Parallelo Asincrono**:
   - All'aggiornamento di $i$, calcolare gli indici mancanti nella finestra.
   - Lanciare l'estrazione binaria per gli indici scoperti in parallelo usando `Future.wait` o coda concorrente con priorità all'immagine corrente $i$, poi a $i+1$, poi a $i-1$, poi $i+2$, $i+3$, $i-2$.
   - Salvare in cache un oggetto contenente: `Uint8List jpegBytes`, `Map<String, dynamic> exifData`.
3. **Deduplicazione delle Richieste in Volo**:
   - Mantenere una mappa di `Map<int, Future<ExtractedRafData>> inFlightRequests`.
   - Se un indice è già in fase di estrazione, riutilizzare lo stesso `Future` per evitare letture I/O duplicate sullo stesso file.

---

## 4. Coda I/O Asincrona Non Bloccante (Copia & Eliminazione)

I file `.RAF` pesano tra i 40 MB e i 60 MB ciascuno. Le operazioni di copia o eliminazione su disco non devono in nessun caso bloccare l'interfaccia utente, la riproduzione video o il passaggio all'immagine successiva.

### A. Operazione di Selezione / Copia (Tasto Spazio o Touch)
1. L'utente preme `Spazio` (o tocca l'icona Seleziona/Copia).
2. La UI aggiorna istantaneamente lo stato visuale:
   - Viene mostrato il badge verde `"SELEZIONATA ✓"`.
   - Se abilitato l'interruttore "Auto-Advance", l'app avanza immediatamente all'immagine $i+1$ senza attendere il completamento della scrittura su disco.
3. Il task di copia viene aggiunto alla `FileOperationsQueue`:
   - Copia in background con buffer streaming `File(src).openRead().pipe(File(dst).openWrite())` o `copy()` asincrono in Isolate.
   - Aggiornamento contatore coda HUD (`Copia in corso: 3 in attesa`).
   - Gestione errori atomica: se il disco si riempie (`disk full`) o permessi falliscono, notifica toast/snackbar di errore con ripristino dello stato a non selezionata.

### B. Operazione di Eliminazione (Tasto Canc o Touch)
1. L'utente preme `Canc` / `Delete` (o tocca l'icona Cestino).
2. Rimozione immediata della foto dall'elenco attivo dell'app e passaggio immediato alla foto successiva ($i$).
3. Accodamento dell'eliminazione:
   - Eliminazione asincrona del file su disco: `File(path).delete()`.
   - In caso di errore I/O, registrazione nel log e avviso all'utente.

---

## 5. Note di Auto-Correzione e Vincoli API Dart/Flutter
* **Creazione Directory Ricorsiva**: In `dart:io`, il parametro per creare directory padre mancanti è `recursive: true` (e non `parents: true` proprio di Python `pathlib.Path.mkdir`).
* **Matrix4 Scaling**: Per il reset e lo scaling dello zoom senza warning di deprecazione su Flutter 3.31+, utilizzare `Matrix4.diagonal3Values(scaleX, scaleY, 1.0)`.
* **Switch Color Property**: In Flutter moderno utilizzare `activeThumbColor` invece di `activeColor`.

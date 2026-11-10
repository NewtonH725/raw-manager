# 🚀 RAW Manager — La Guida Definitiva
### *Scorri, seleziona e organizza migliaia di foto RAW pesantissime alla velocità della luce*

---

Benvenuto nel mondo di **RAW Manager**, l'applicazione progettata per liberare i fotografi dall'incubo più grande del dopo-scatto: **la lentezza estenuante nella selezione delle foto**.

Che tu stia tornando da un matrimonio con 4.000 scatti, da un safari fotografico o da una sessione in studio, sai bene cosa succede aprendo i software tradizionali: le ventole del computer iniziano a urlare, appare la temuta "rotellina che gira" e devi aspettare 2 o 3 secondi per ogni singola immagine solo per capire se il soggetto aveva gli occhi aperti o chiusi.

**Con RAW Manager questo incubo è finito.**
Puoi sfogliare migliaia di immagini RAW da 50 Megabyte l'una a **60 o 120 fotogrammi al secondo**, con una reattività istantanea, senza mai scaldare il computer e senza esaurire la memoria.

---

## 👵 1. Spiegazione "A Prova di Nonna" (Le 4 Grandi Analogie)

Per capire perché RAW Manager è così rivoluzionario, non serve una laurea in ingegneria informatica. Immaginiamo come funzionano le cose nella vita quotidiana:

### 📦 1. Il cassetto dei negativi e il francobollo già pronto
> **I programmi tradizionali** lavorano come una persona che, per guardare una foto, va in soffitta, tira fuori una bacinella di acidi chimici, prende il negativo scuro e si mette a sviluppare l'intera pellicola da zero ogni volta. Ci vogliono tempo, pazienza e tanta fatica.
>
> **RAW Manager fa una cosa geniale:** sa che la tua fotocamera digitale, al momento dello scatto, ha già sviluppato al suo interno una miniatura bellissima e dettagliatissima (un "francobollo" gigante ad altissima risoluzione) e l'ha incollata sulla busta del negativo. RAW Manager prende direttamente quella cartolina già pronta: ci mette meno di 5 millesimi di secondo!

### 🏃‍♂️ 2. Il postino veloce (La memoria leggera)
> Immagina di dover scegliere le foto migliori tra 5.000 stampe giganti. Se il postino decidesse di scaricarti tutti i 5.000 pacchi contemporaneamente sul tavolo della cucina, il tavolo crollerebbe sotto il peso!
> 
> RAW Manager usa un postino intelligente: tiene in mano solo la foto che stai guardando adesso, ne tiene **due nella tasca sinistra** (se vuoi tornare indietro) e **tre pronte nella mano destra** (perché sa che andrai avanti). Tutto il resto rimane ordinato nello scaffale su disco. Il tavolo non trema mai e la memoria del PC o del tablet resta sempre fresca e leggera.

### 🔍 3. La lente d'ingrandimento istantanea
> Sei indeciso se un ritratto è perfettamente a fuoco sulla pupilla? Non serve aspettare caricamenti infiniti. Con un solo tocco o premendo un tasto, tiri fuori la lente d'ingrandimento (Zoom 2.5x) e guardi il dettaglio all'istante; un altro tocco e la rimetti a posto per passare alla foto successiva.

### ⏱️ 4. Lo scatto senza attese (La scatola delle foto buone)
> Quando decidi che una foto ti piace, premi un tasto e la foto viene promossa nella scatola dei "preferiti". Ma non devi aspettare che il postino completi il trasloco del pacco da 50 MB: l'app registra la tua scelta e **gira pagina all'istante**, mentre un aiutante silenzioso si occupa di copiare il file pesante sullo sfondo, senza farti perdere nemmeno un battito di ciglia.

---

## ⚡ 2. Cosa Fa RAW Manager

RAW Manager è uno strumento specializzato di **Culling** (selezione rapida) ultra-veloce cross-platform (Windows, Linux, Android):

* 📂 **Apertura istantanea di cartelle enormi**: Carica cartelle con oltre 5.000 scatti RAW in meno di 150 millisecondi.
* 🏎️ **Sfoglia a 60/120 FPS**: Nessun ritardo percepito tra uno scatto e l'altro (< 10 ms).
* 🎯 **Scelta fulminea con Auto-Advance**: Selezioni con la barra spaziatrice e l'applicazione avanza da sola al fotogramma successivo.
* 🧹 **Pulizia e scarto rapido**: Con il tasto `Canc`, elimini le foto sfocate o malriuscite direttamente dal disco.
* 🛡️ **Zero rischi per i tuoi originali**: I file sorgente non vengono mai alterati o compressi. Le foto scelte vengono copiate in modo intatto e trasparente nella cartella di destinazione che preferisci.

---

## 🧠 3. Il Segreto Tecnico: Come Ragiona sotto il Cofano

Perché RAW Manager riesce dove programmi da centinaia di euro spesso arrancano?

```
┌────────────────────────────────────────────────────────────────────────┐
│                        IL SEGRETO DI RAW MANAGER                       │
├────────────────────────────────────────────────────────────────────────┤
│ File RAW (50 MB)                                                       │
│ ┌──────────────┬───────────────────────────────┬─────────────────────┐ │
│ │ Header (92B) │  JPEG Ultra-HD Incorporato    │ Dati Sensore RAW    │ │
│ │  (Puntatori) │     (4-6 MB, già sviluppato)  │ (45 MB Bayer/XTrans)│ │
│ └──────┬───────┴───────────────┬───────────────┴──────────┬──────────┘ │
│        │                       │                          │            │
│        ▼                       ▼                          ▼            │
│  Lettura binaria        Estratto in 5ms!           IGNORATO!           │
│  (RandomAccessFile)    Pronto a schermo a 120 FPS  (Zero calcoli CPU)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 🚫 Niente demosaicizzazione lenta (Zero spreco di CPU)
I file RAW memorizzano i dati grezzi raccolti dal sensore (matrice Bayer o Fujifilm X-Trans). Per visualizzarli normalmente servono complessi calcoli matematici (demosaicizzazione, bilanciamento del bianco software, riduzione del rumore). 
RAW Manager **non tocca i dati grezzi**. Utilizza un puntatore binario ad accesso casuale (`RandomAccessFile`), legge i primi 92 byte di intestazione per individuare l'esatta posizione dell'anteprima JPEG Ultra-HD (generata dal processore d'immagine dedicato della macchina fotografica con colori e nitidezza nativi) ed estrae solo quella in pochissimi millisecondi.

### 🪟 La Finestra che Scorre (Sliding Window `[i-2, i+3]`)
Se caricassimo in memoria centinaia di file RAW, esauriremmo rapidamente tutti i Gigabyte di RAM a disposizione del sistema operativo.
RAW Manager adotta l'algoritmo deterministico della **Sliding Window**:

$$\text{Finestra Attiva} = [i-2,\; i+3]$$

* **Foto Corrente ($i$)**: Visualizzata a schermo intero con metadati e zoom.
* **Buffer Precedente ($i-1, i-2$)**: Mantenute calde in RAM per tornare indietro istantaneamente senza rileggere il disco.
* **Buffer Successivo ($i+1, i+2, i+3$)**: Pre-estratte in background mentre osservi la foto attuale.
* **Eviction Immediata**: Non appena l'indice si sposta, qualunque foto al di fuori della finestra viene immediatamente deallocata e spazzata via dalla RAM.

> [!NOTE]
> Grazie a questa tecnica, l'impronta di memoria RAM rimane rigorosamente confinata tra **200 MB e 350 MB**, sia che tu stia scorrendo 50 foto su un tablet portatile, sia che tu stia selezionando 10.000 file su una workstation desktop!

---

## 🛠️ 4. Lo Stack Tecnologico: Motore da Formula 1

RAW Manager è stato costruito combinando il meglio delle tecnologie moderne ad altissima prestazione:

### 🎨 Flutter & Dart a 60 / 120 FPS
Il framework grafico di Google garantisce un rendering fluido e nativo su **Windows**, **Linux (Ubuntu)** e **Android**. L'interfaccia risponde al tocco, al mouse e alla tastiera senza il minimo micro-scatto.

### 👷 Gli "Operai Isolati" (Isolates Multi-Thread)
In molti programmi l'interfaccia si blocca per qualche secondo quando si apre un file pesante. In Dart e Flutter, l'interfaccia gira sul thread principale; RAW Manager delega tutta la lettura fisica dei file e l'analisi dei metadati EXIF a lavoratori separati (`Isolate.run()`). 
L'interfaccia grafica e i comandi restano sempre liberi e reattivi, garantendo 120 fotogrammi al secondo costanti.

### 📥 Coda I/O Asincrona Non Bloccante (`FileOperationsQueue`)
Quando decidi di promuovere una foto, copiare 50 Megabyte su una scheda SD o su un hard disk meccanico richiede una frazione di secondo fisico. RAW Manager non ti fa aspettare:
1. Accende all'istante il badge verde **"SELEZIONATA ✓"**.
2. Salta subito alla foto successiva (se hai l'Auto-Advance attivo).
3. Inserisce il lavoro in una coda asincrona di sottofondo, che copia i file uno dopo l'altro senza togliere potenza alla visualizzazione.

### 🏛️ L'Architettura DOE (Direttive, Regia, Esecuzione)
L'applicazione è strutturata secondo un'architettura rigorosa e modulare:
1. **Direttive (Directives/SOP)**: Procedure standard deterministiche che stabiliscono con precisione le regole matematiche di estrazione dei byte, la gestione della memoria e i flussi di packaging.
2. **Regia (Providers / State Management con Riverpod)**: Il centro di controllo intelligente che governa lo stato dell'app, l'indice corrente e la sincronizzazione della cache.
3. **Esecuzione (Services & UI)**: I motori operativi che comunicano con il disco, estraggono i file ed eseguono il rendering dei controlli a schermo.

---

## ⌨️ 5. Guida Pratica ai Comandi e alle Scorciatoie

L'interfaccia di RAW Manager è pulita, minimale e studiata per farti lavorare alla velocità del pensiero:

| Comando da Tastiera | Tocco / Schermo Touch | Azione Eseguita | Perché è Fondamentale |
|---|---|---|---|
| <kbd>Spazio</kbd> | Tasto Verde Seleziona | **Seleziona e Copia** | Aggiunge la foto alla cartella dei preferiti e attiva il badge verde. |
| <kbd>→</kbd> oppure <kbd>J</kbd> | Swipe verso sinistra | **Foto Successiva** | Avanza in avanti nell'album in tempo zero. |
| <kbd>←</kbd> oppure <kbd>K</kbd> | Swipe verso destra | **Foto Precedente** | Torna indietro all'immagine precedente. |
| <kbd>Z</kbd> | Doppio Tap sullo schermo | **Lente di Ingrandimento** | Ingrandisce istantaneamente al 250% per verificare gli occhi o il fuoco. |
| <kbd>H</kbd> | Singolo Tap sullo sfondo | **Mostra / Nascondi HUD** | Nasconde scritte, barre e pulsanti per godersi la foto a tutto schermo. |
| <kbd>Canc</kbd> o <kbd>Backspace</kbd> | Tasto Cestino Rosso | **Elimina File** | Rimuove subito lo scatto sfocato dal disco e passa avanti. |

### 🚀 Il Pilota Automatico: Auto-Advance
In alto a destra nell'interfaccia trovi l'interruttore **"Auto-Advance"**:
* Quando è **ATTIVO**: ti basta premere la barra spaziatrice per selezionare lo scatto buono e RAW Manager salta istantaneamente al fotogramma successivo da solo!
* Con questa funzione attiva, passare in rassegna centinaia di scatti a raffica diventa un gioco ritmico che richiede solo pochi minuti.

### 📁 Configurare le Cartelle in Due Clic
1. **Cartella Sorgente** (Icona Cartella Arancione): seleziona dove si trovano le foto scattate (es. la scheda SD o la cartella della giornata).
2. **Cartella Destinazione** (Icona Cartella Verde): seleziona dove desideri salvare solo le foto promosse (es. `Scatti_Scelti`).

---

## 📷 6. Supporto Universale per Tutti i Formati RAW

RAW Manager include un motore di scansione ed estrazione universale in grado di leggere le anteprime native incorporate nei formati di tutti i maggiori marchi fotografici mondiali:

* 🟢 **Fujifilm (`.RAF`)**: Algoritmo proprietario a lettura diretta dei puntatori Big-Endian in < 5ms.
* 🟠 **Sony (`.ARW`)**: Decodifica ad accesso diretto dell'anteprima TIFF/IFD.
* 🟡 **Nikon (`.NEF`)**: Estrazione rapida del JPEG incorporato da struttura TIFF Nikon.
* 🔴 **Canon (`.CR2` e `.CR3`)**: Supporto per standard TIFF CR2 e container moderno ISO-BMFF CR3.
* 🔵 **Adobe / DNG Universale (`.DNG`)**: Compatibilità con qualsiasi file Digital Negative (inclusi droni DJI e smartphone).
* 🟣 **Altri formati**: Supporto per `.RW2` (Panasonic Lumix), `.ORF` (Olympus / OM System) e `.PEF` (Pentax).

---

## 💡 7. Il Flusso di Lavoro Perfetto (Workflow del Fotografo Pro)

Ecco come completare la selezione di un intero evento in 15 minuti:

1. **Inserisci la scheda SD** nel PC o nel tablet.
2. Apri **RAW Manager**.
3. Clicca su **Cartella Sorgente** e scegli la cartella della scheda di memoria.
4. Clicca su **Cartella Destinazione** e seleziona una cartella sul tuo SSD (es. `Migliori_Foto`).
5. Attiva la levetta **Auto-Advance**.
6. Premi `H` per togliere ogni distrazione visiva: ora hai lo schermo intero dedicato solo alla tua arte.
7. **Inizia la corsa**:
   - Foto buona? Premi <kbd>Spazio</kbd> (la foto viene accodata e la pagina gira da sola).
   - Foto da scartare? Premi <kbd>→</kbd> o <kbd>J</kbd>.
   - Foto palesemente rovinata o mossa? Premi <kbd>Canc</kbd>.
   - Dubbio sul fuoco? Premi <kbd>Z</kbd> o fai doppio tap, verifica la nitidezza, premi di nuovo <kbd>Z</kbd>.
8. Finito! Nella cartella `Migliori_Foto` trovi già tutti i file RAW originali pronti per essere importati nel tuo programma di fotoritocco preferito, senza aver perso nemmeno un secondo!

---

## 🌟 Riepilogo

RAW Manager dimostra che non serve un supercomputer per lavorare in modo professionale con fotografie ad altissima risoluzione. Con una progettazione intelligente, l'accesso binario mirato e il rispetto della memoria del dispositivo, la tecnologia torna ad essere ciò che dovrebbe sempre essere: **invisibile, velocissima e al servizio della tua creatività!** 📸✨

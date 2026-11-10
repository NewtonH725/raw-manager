# SOP 01: Procedura Operativa Standard per l'Estrazione Binaria Fujifilm .RAF

## 1. Obiettivo e Principi Architetturali
Questa procedura standard definisce le regole deterministiche per estrarre in meno di 10 millisecondi l'anteprima JPEG ad alta risoluzione incorporata nei file RAW proprietari Fujifilm (`.RAF` da 40-60 MB generati dalla Fujifilm X-T5 e corpi compatibili).

> **REGOLA ARCHITETTURALE FONDAMENTALE**: 
> È severamente vietato l'uso di librerie di demosaicizzazione RAW pesanti (come LibRaw, rawpy o decoding software completo dei dati bayer). I file `.RAF` contengono un JPEG nativo completo generato dall'ISP della fotocamera. L'estrazione deve essere puramente binaria via puntatori I/O ad accesso casuale (`RandomAccessFile`), azzerando l'overhead di CPU e RAM.

---

## 2. Specifica del Formato Binario Fujifilm .RAF

La struttura dell'header e della tabella puntatori del formato Fujifilm CCD/CMOS RAW è definita come segue:

| Offset (Byte) | Lunghezza | Tipo Dato | Descrizione |
|---|---|---|---|
| `0x00` - `0x0F` (0-15) | 16 byte | ASCII String | Magic String: `"FUJIFILMCCD-RAW "` (16 caratteri esatti) |
| `0x10` - `0x53` (16-83) | 68 byte | Binary Data | Metadati fotocamera, versioning header, padding |
| `0x54` - `0x57` (84-87) | 4 byte | `Uint32` Big-Endian | `jpegOffset`: Offset del primo byte dell'immagine JPEG incorporata |
| `0x58` - `0x5B` (88-91) | 4 byte | `Uint32` Big-Endian | `jpegLength`: Dimensione esatta in byte dell'immagine JPEG |
| `jpegOffset` | `jpegLength` byte | Binary Data | Stream JPEG standard (inizia con `0xFF 0xD8`, termina con `0xFF 0xD9`) |
| Fine JPEG -> Fine file | Variabile | Binary Data | Dati RAW del sensore CFA (X-Trans / Bayer) |

---

## 3. Algoritmo Deterministico di Estrazione (Dart/Isolate)

1. **Apertura File ad Accesso Casuale**:
   Aprire il file in sola lettura con `File(path).open(mode: FileMode.read)`.
2. **Lettura Header Primario (92 byte)**:
   Leggere un buffer fisso di 92 byte (`Uint8List(92)`).
3. **Validazione Magic Header**:
   Confrontare i byte `0..15` con la stringa ASCII `"FUJIFILMCCD-RAW "`. Se non corrispondono, sollevare `RafHeaderException`.
4. **Lettura Puntatori Big-Endian**:
   Utilizzare un `ByteData.sublistView(headerBytes)`:
   - `jpegOffset = byteData.getUint32(0x54, Endian.big)`
   - `jpegLength = byteData.getUint32(0x58, Endian.big)`
5. **Verifica Limiti e Integrità**:
   - Calcolare `fileLength = await raf.length()`.
   - Se `jpegOffset + jpegLength > fileLength` o `jpegLength == 0`, sollevare `RafCorruptedException`.
6. **Estrazione JPEG Stream**:
   - Posizionare la testina di lettura: `await raf.setPosition(jpegOffset)`.
   - Leggere esattamente `jpegLength` byte: `final jpegBytes = await raf.read(jpegLength)`.
7. **Verifica Marcatori JPEG**:
   - I primi 2 byte del buffer devono essere `0xFF 0xD8` (SOI - Start of Image).
   - Gli ultimi 2 byte devono essere `0xFF 0xD9` (EOI - End of Image).
8. **Estrazione Metadati EXIF**:
   - Parsing leggero con libreria `exif` sul buffer `jpegBytes` in memoria (senza rileggere il file su disco).
   - Campi estratti: Tempo di scatto (Shutter Speed), Diaframma (F-Number), Sensibilità (ISO), Lunghezza focale, Modello fotocamera, Timestamp.
9. **Chiusura File**:
   Garantire sempre la chiusura di `RandomAccessFile` nel blocco `finally`.

---

## 4. Matrice dei Casi Limite ed Eccezioni

| Caso Limite | Condizione Rilevata | Azione Correttiva / Risposta |
|---|---|---|
| **File Troppo Breve** | `fileLength < 92` byte | Lancia `RafInvalidHeaderException("File troppo piccolo per contenere l'header RAF standard")` |
| **Magic String Errata** | Byte 0-15 != `"FUJIFILMCCD-RAW "` | Lancia `RafInvalidHeaderException("Magic bytes non validi: non è un file Fujifilm RAF")` |
| **Puntatore Offset Non Valido** | `jpegOffset < 92` oppure `jpegOffset >= fileLength` | Lancia `RafCorruptedException("Offset JPEG non valido o corrotto")` |
| **Troncamento Dati** | `jpegOffset + jpegLength > fileLength` | Lancia `RafTruncatedException("Lunghezza JPEG eccede la dimensione fisica del file")` |
| **Marcatori SOI/EOI Mancanti** | Buffer JPEG non inizia con `0xFF 0xD8` o non finisce con `0xFF 0xD9` | Lancia `RafCorruptedException("Stream JPEG non valido o privo di marker SOI/EOI")` |
| **Permessi File Negati** | `FileSystemException` (EACCES) | Tracciamento errore nel modello `RafPhoto(hasError: true)` e notifica UI |

---

## 5. Esecuzione Concorrente su Isolate
Tutte le chiamate di estrazione devono essere eseguite tramite `Isolate.run()` per isolare completamente l'I/O binario e il parsing EXIF dal thread principale della UI di Flutter, garantendo un framerate costante a 60/120 fps durante lo scorrimento veloce.

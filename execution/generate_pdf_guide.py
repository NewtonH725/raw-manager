#!/usr/bin/env python3
"""
execution/generate_pdf_guide.py
Genera una guida utente completa in formato PDF (docs/RAW_Manager_Guida_Ufficiale.pdf)
con impaginazione moderna, grafica curata, spiegazioni passo-passo,
tabelle di scorciatoie e screenshot ad alta risoluzione.
"""

import subprocess
import base64
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DOCS_DIR = BASE_DIR / "docs"
IMAGES_DIR = DOCS_DIR / "images"

def get_base64_image(image_path: Path) -> str:
    with open(image_path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")
    return f"data:image/png;base64,{data}"

def main():
    print("=== Generazione Guida Utente PDF Ufficiale ===")
    
    img_logo = get_base64_image(BASE_DIR / "assets" / "app_icon.png")
    img_screen1 = get_base64_image(IMAGES_DIR / "01_schermata_iniziale.png")
    img_screen2 = get_base64_image(IMAGES_DIR / "02_schermata_culling.png")
    img_screen3 = get_base64_image(IMAGES_DIR / "03_foto_selezionata.png")
    img_screen4 = get_base64_image(IMAGES_DIR / "04_dialog_informazioni.png")

    html_content = f"""<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>RAW Manager - Manuale Utente e Guida Operativa</title>
<style>
  @page {{
    size: A4 portrait;
    margin: 18mm 16mm 20mm 16mm;
    @bottom-right {{
      content: "Pagina " counter(page) " di " counter(pages);
      font-size: 9pt;
      color: #888888;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    color: #222222;
    background-color: #ffffff;
    line-height: 1.55;
    font-size: 10.5pt;
  }}

  /* Copertina e Header */
  .cover-header {{
    display: flex;
    align-items: center;
    gap: 20px;
    border-bottom: 3px solid #FFC107;
    padding-bottom: 18px;
    margin-bottom: 25px;
  }}
  .cover-logo {{
    width: 64px;
    height: 64px;
    border-radius: 50%;
  }}
  .cover-title-group h1 {{
    margin: 0;
    font-size: 26pt;
    font-weight: 800;
    color: #181818;
    letter-spacing: -0.5px;
  }}
  .cover-title-group .subtitle {{
    margin-top: 4px;
    font-size: 12pt;
    color: #666666;
    font-weight: 500;
  }}

  .page-break {{
    page-break-before: always;
  }}

  h2 {{
    font-size: 16pt;
    color: #181818;
    border-left: 4px solid #FFC107;
    padding-left: 10px;
    margin-top: 24px;
    margin-bottom: 12px;
  }}
  h3 {{
    font-size: 12pt;
    color: #333333;
    margin-top: 16px;
    margin-bottom: 8px;
  }}
  p {{
    margin-bottom: 10px;
    color: #333333;
  }}

  /* Callout box */
  .callout {{
    background-color: #F8F9FA;
    border-left: 4px solid #FFC107;
    padding: 12px 16px;
    margin: 14px 0;
    border-radius: 0 8px 8px 0;
    font-size: 10pt;
  }}
  .callout-success {{
    background-color: #F1F8E9;
    border-left-color: #4CAF50;
  }}

  /* Figure e Screenshot */
  .figure-card {{
    margin: 16px 0;
    text-align: center;
  }}
  .figure-img {{
    width: 100%;
    max-height: 280px;
    object-fit: contain;
    border-radius: 8px;
    box-shadow: 0 4px 14px rgba(0,0,0,0.15);
    border: 1px solid #E0E0E0;
  }}
  .figure-caption {{
    font-size: 9pt;
    color: #777777;
    margin-top: 6px;
    font-style: italic;
  }}

  /* Tabelle */
  table.shortcut-table {{
    width: 100%;
    border-collapse: collapse;
    margin: 14px 0;
    font-size: 9.5pt;
  }}
  table.shortcut-table th {{
    background-color: #181818;
    color: #FFC107;
    text-align: left;
    padding: 8px 12px;
    font-weight: 600;
  }}
  table.shortcut-table td {{
    padding: 8px 12px;
    border-bottom: 1px solid #EAEAEA;
    color: #333333;
  }}
  table.shortcut-table tr:nth-child(even) {{
    background-color: #FAFAFA;
  }}
  .key {{
    display: inline-block;
    background: #EFEFEF;
    border: 1px solid #D0D0D0;
    padding: 2px 7px;
    border-radius: 4px;
    font-family: monospace;
    font-weight: bold;
    color: #181818;
    font-size: 9pt;
  }}

  /* Grid features */
  .grid-2 {{
    display: flex;
    gap: 16px;
    margin: 14px 0;
  }}
  .feature-box {{
    flex: 1;
    background: #F9F9F9;
    padding: 14px;
    border-radius: 8px;
    border: 1px solid #EEEEEE;
  }}
  .feature-box h4 {{
    margin: 0 0 6px 0;
    color: #181818;
    font-size: 11pt;
  }}

  .badge-tag {{
    display: inline-block;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 8.5pt;
    font-weight: bold;
    color: #ffffff;
  }}
  .tag-gold {{ background-color: #D4AC0D; color: #181818; }}
  .tag-green {{ background-color: #2E7D32; }}
</style>
</head>
<body>

  <!-- INTESTAZIONE -->
  <div class="cover-header">
    <img src="{img_logo}" class="cover-logo" alt="Logo">
    <div class="cover-title-group">
      <h1>RAW Manager</h1>
      <div class="subtitle">Guida Utente e Manuale Operativo Ufficiale (v1.2.2)</div>
    </div>
  </div>

  <h2>1. Cos'è RAW Manager</h2>
  <p>
    <b>RAW Manager</b> è un'applicazione fotografica multi-piattaforma concepita specificamente per il <b>culling ultra-rapido</b> dei file RAW (selezione, scarto e archiviazione istantanea sul campo). Sviluppata per fotografi esigenti che lavorano con fotocamere ad altissima risoluzione (come la <b>Fujifilm X-T5 da 40.2 MP</b>) o formati RAW universali (<b>Ricoh GR III/GR IIIx .DNG, Adobe .DNG, .ARW Sony, .NEF Nikon, .CR2/.CR3 Canon</b>).
  </p>

  <div class="callout callout-success">
    <b>⚡ Prestazioni Estreme (&lt;10 ms):</b> A differenza dei pesanti software di sviluppo RAW (che impiegano secondi per elaborare la matrice di demosaicizzazione per ogni foto), RAW Manager sfrutta un <b>motore di estrazione binaria proprietario</b>. Legge direttamente l'anteprima JPEG incorporata a piena risoluzione memorizzata all'interno dell'header binario del file RAW, caricandola sul display in meno di <b>6 millisecondi</b>.
  </div>

  <div class="grid-2">
    <div class="feature-box">
      <h4>🔒 Integrità Assoluta dei File</h4>
      <p style="font-size: 9pt; margin: 0;">I file RAW originali non vengono mai modificati, riscritti o alterati. La selezione consiste in una copia asincrona non bloccante nella cartella di destinazione.</p>
    </div>
    <div class="feature-box">
      <h4>🚀 Prefetching Intelligente</h4>
      <p style="font-size: 9pt; margin: 0;">Un algoritmo a finestra scorrevole [i-2, i+3] precarica in memoria RAM le foto adiacenti: il passaggio alla foto successiva o precedente è istantaneo.</p>
    </div>
  </div>

  <h2>2. Primo Avvio e Schermata Iniziale</h2>
  <p>
    All'apertura dell'applicazione compare la schermata principale pulita, dotata di una <b>barra superiore solida ancorata in cima</b> e dell'icona ufficiale del diaframma dorato.
  </p>

  <div class="figure-card">
    <img src="{img_screen1}" class="figure-img" alt="Schermata Iniziale">
    <div class="figure-caption">Figura 1: Schermata iniziale di RAW Manager con la barra comandi superiore non sovrapposta.</div>
  </div>

  <p><b>Passaggi per iniziare:</b></p>
  <ol style="margin-left: 20px; font-size: 10pt; line-height: 1.6;">
    <li>Clicca su <b>"Apri Cartella RAW"</b> (oppure <i>"Apri Sorgente"</i> in alto).</li>
    <li>Seleziona la cartella contenente i tuoi file fotografici (es. la scheda SD della fotocamera <code>DCIM/101_FUJI</code>).</li>
    <li>(Opzionale ma raccomandato) Clicca sul pulsante dorato <b>"Seleziona Target"</b> in alto per impostare la cartella dove verranno salvate le foto selezionate.</li>
  </ol>

  <div class="page-break"></div>

  <h2>3. La Schermata di Culling e Visualizzazione</h2>
  <p>
    Una volta aperta la cartella, RAW Manager ordina cronologicamente i file ed estrae istantaneamente la prima anteprima.
  </p>

  <div class="figure-card">
    <img src="{img_screen2}" class="figure-img" alt="Schermata di Culling">
    <div class="figure-caption">Figura 2: Modalità di culling attiva con barra dati EXIF, contatore scatti e barra di controllo rapido.</div>
  </div>

  <p><b>Elementi della Schermata:</b></p>
  <ul style="margin-left: 20px; font-size: 10pt; line-height: 1.6;">
    <li><b>Barra Superiore Material 3:</b> mostra il nome del file (es. <code>DSCF2341.RAF</code>), il contatore (es. <code>1 / 148</code>), e i comandi per cambiare cartella sorgente/destinazione. La barra è fissa e <u>non copre mai</u> la sommità della foto.</li>
    <li><b>Riquadro Metadati EXIF:</b> indica immediatamente modello fotocamera, tempo di posa, diaframma, sensibilità ISO e lunghezza focale (es. <i>FUJIFILM X-T5 • 1/500s • f/2.8 • ISO 160 • 50mm</i>).</li>
    <li><b>Pulsante INFO:</b> apre la guida sintetica a comparsa direttamente a schermo.</li>
    <li><b>Interruttore Auto-Advance:</b> se attivo, fa avanzare automaticamente la visualizzazione alla foto successiva non appena premi Spazio per selezionare.</li>
  </ul>

  <h2>4. Selezione delle Foto e Gestione Scarti</h2>

  <div class="figure-card">
    <img src="{img_screen3}" class="figure-img" alt="Foto Selezionata">
    <div class="figure-caption">Figura 3: Foto confermata con badge verde "SELEZIONATA ✓" e cornice di evidenziazione.</div>
  </div>

  <ul style="margin-left: 20px; font-size: 10pt; line-height: 1.6;">
    <li><b>Come Selezionare una Foto:</b> premi la barra <span class="key">Spazio</span> o tocca il pulsante verde con la spunta <span class="badge-tag tag-green">✓</span>. La foto riceve il badge verde <b>SELEZIONATA ✓</b> e viene inviata alla coda di copia in background.</li>
    <li><b>Verifica Fuoco e Nitidezza (Zoom 100%):</b> premi <span class="key">Z</span> o fai <b>Doppio Tocco</b> per ingrandire al 100% l'immagine a risoluzione piena per controllare occhi, ciglia e micro-dettagli.</li>
    <li><b>Eliminazione Scarti:</b> premi <span class="key">Canc</span> o tocca il cestino rosso per eliminare fisicamente dal supporto il file non riuscito e liberare spazio.</li>
  </ul>

  <div class="page-break"></div>

  <h2>5. Modalità Schermo Intero e Guida Rapida</h2>
  <p>
    Toccando un punto qualsiasi dell'immagine (o premendo il tasto <span class="key">H</span> sulla tastiera), la barra superiore e i controlli scompaiono istantaneamente, lasciando la foto pulita a tutto schermo senza elementi di disturbo visivo. Toccando nuovamente, i comandi riappaiono.
  </p>

  <div class="figure-card">
    <img src="{img_screen4}" class="figure-img" alt="Finestra Guida e Scorciatoie">
    <div class="figure-caption">Figura 4: Finestra modale interattiva di aiuto con tutte le scorciatoie di culling veloce.</div>
  </div>

  <h2>6. Guida alle Piattaforme</h2>

  <h3>📱 Android (Google Pixel, Smartphone e Tablet con USB OTG)</h3>
  <ul>
    <li><b>Lettore di Schede SD USB-C:</b> collega il lettore SD direttamente alla porta USB-C del telefono. Clicca su <i>"Apri Cartella RAW"</i> e seleziona la cartella <code>DCIM/101_FUJI</code> sulla scheda SD tramite il selettore di sistema (SAF).</li>
    <li><b>Swipe Touch Orizzontale:</b> naviga tra le foto scorrendo con il dito verso sinistra (foto successiva) o verso destra (precedente).</li>
    <li><b>Icona Adattiva:</b> l'icona circolare dell'app riempie perfettamente lo spazio delle icone di sistema senza bordi bianchi.</li>
  </ul>

  <h3>🐧 Linux Desktop (Ubuntu, Debian, Fedora)</h3>
  <ul>
    <li><b>Menu Applicazioni:</b> installato nativamente come applicazione XDG desktop in <code>~/.local/share/applications/raw-manager.desktop</code>. Avviabile dal lanciatore di Ubuntu.</li>
    <li><b>Supporto SD:</b> le schede SD montate in <code>/run/media/utente/...</code> o <code>/media/...</code> sono accessibili all'istante senza sandbox o vincoli di permessi Snap.</li>
  </ul>

  <h3>🪟 Windows (Windows 10 / 11 a 64-bit)</h3>
  <ul>
    <li><b>Versione Setup (`RAW_Manager_Windows_x64_Setup.exe`):</b> programma di installazione guidato che aggiunge l'icona sul Desktop, nel Menù Start e include la disinstallazione pulita da Pannello di Controllo.</li>
    <li><b>Versione Portable (`RAW_Manager_Windows_x64_Portable.zip`):</b> eseguibile autonomo senza installazione, utilizzabile direttamente anche da chiavetta USB.</li>
  </ul>

  <h2>7. Tabella Riepilogativa dei Comandi</h2>
  <table class="shortcut-table">
    <thead>
      <tr>
        <th style="width: 25%;">Comando / Gesto</th>
        <th style="width: 35%;">Azione</th>
        <th style="width: 40%;">Descrizione</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><span class="key">Spazio</span> / Tasto <span class="badge-tag tag-green">✓</span></td>
        <td><b>Seleziona e Copia</b></td>
        <td>Copia il file RAW nella cartella Target con auto-advance.</td>
      </tr>
      <tr>
        <td><span class="key">▶</span> / <span class="key">J</span> / Swipe Sinistra</td>
        <td><b>Foto Successiva</b></td>
        <td>Passa istantaneamente al fotogramma successivo (&lt;10ms).</td>
      </tr>
      <tr>
        <td><span class="key">◀</span> / <span class="key">K</span> / Swipe Destra</td>
        <td><b>Foto Precedente</b></td>
        <td>Ritorna allo scatto precedente.</td>
      </tr>
      <tr>
        <td><span class="key">Canc</span> / <span class="key">Backspace</span></td>
        <td><b>Elimina RAW</b></td>
        <td>Elimina il file scartato dal disco per liberare spazio.</td>
      </tr>
      <tr>
        <td><span class="key">Z</span> / Doppio Tap</td>
        <td><b>Zoom 100% / Fit</b></td>
        <td>Ingrandisce a risoluzione 1:1 per verifica fuoco e nitidezza.</td>
      </tr>
      <tr>
        <td><span class="key">H</span> / Singolo Tap</td>
        <td><b>Toggle Schermo Intero</b></td>
        <td>Mostra o nasconde tutte le barre e controlli di interfaccia.</td>
      </tr>
      <tr>
        <td><span class="key">I</span> / <span class="key">F1</span></td>
        <td><b>Guida e Info</b></td>
        <td>Apre la guida interattiva a schermo con scorciatoie.</td>
      </tr>
    </tbody>
  </table>

  <div style="margin-top: 35px; border-top: 1px solid #E0E0E0; padding-top: 12px; font-size: 8.5pt; color: #888888; text-align: center;">
    RAW Manager • Sviluppato con Architettura DOE per Fotografi • Repository Ufficiale: <a href="https://github.com/NewtonH725/raw-manager" style="color: #D4AC0D; text-decoration: none;">github.com/NewtonH725/raw-manager</a>
  </div>

</body>
</html>
"""

    html_file = DOCS_DIR / "guida_utente.html"
    html_file.write_text(html_content, encoding="utf-8")
    print(f"[OK] Creato template HTML: {html_file}")

    pdf_file = DOCS_DIR / "RAW_Manager_Guida_Ufficiale.pdf"
    cmd = [
        "google-chrome",
        "--headless",
        "--no-sandbox",
        "--print-to-pdf-no-header",
        f"--print-to-pdf={pdf_file}",
        str(html_file),
    ]
    subprocess.run(cmd, check=True)
    print(f"[OK] Compilato PDF Ufficiale: {pdf_file}")

if __name__ == "__main__":
    main()

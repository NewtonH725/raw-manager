#!/usr/bin/env python3
"""
execution/generate_screenshot_assets.py
Genera screenshot ad altissima risoluzione (1920x1080) delle schermate dell'applicazione
utilizzando Google Chrome headless per garantire una resa grafica nitida e fedele al 100%.
"""

import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BASE_DIR / "docs" / "images"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

HTML_COMMON_CSS = """
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  body { background-color: #121212; color: #ffffff; width: 1920px; height: 1080px; overflow: hidden; display: flex; flex-direction: column; }
  
  /* Top Bar */
  .top-bar {
    background-color: #1E1E1E;
    border-bottom: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 4px 12px rgba(0,0,0,0.4);
    padding: 12px 24px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    z-index: 10;
  }
  .top-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .brand-group {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .app-logo {
    width: 32px;
    height: 32px;
    background-color: #181818;
    border: 2px solid #FFB300;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #FFC107;
    font-size: 18px;
    font-weight: bold;
  }
  .app-title {
    font-size: 20px;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: #ffffff;
  }
  .badge-info {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background-color: rgba(255, 193, 7, 0.18);
    border: 1px solid rgba(255, 193, 7, 0.7);
    color: #FFC107;
    padding: 4px 10px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.5px;
    cursor: pointer;
  }
  .counter-badge {
    background-color: rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.8);
    padding: 4px 10px;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
  }
  .file-badge {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .file-name {
    font-size: 16px;
    font-weight: 500;
    color: #ffffff;
  }
  .badge-selected {
    background-color: #2E7D32;
    color: #ffffff;
    font-size: 12px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .actions-group {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .btn-outlined {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.24);
    color: #ffffff;
    padding: 6px 14px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .btn-target {
    border-color: #FFC107;
    color: #FFC107;
  }
  .switch-group {
    display: flex;
    align-items: center;
    gap: 8px;
    color: rgba(255, 255, 255, 0.7);
    font-size: 13px;
  }
  .switch-box {
    width: 36px;
    height: 20px;
    background: #FFC107;
    border-radius: 12px;
    position: relative;
  }
  .switch-circle {
    width: 14px;
    height: 14px;
    background: #181818;
    border-radius: 50%;
    position: absolute;
    top: 3px;
    right: 3px;
  }
  .exif-bar {
    display: flex;
    align-items: center;
    gap: 16px;
    font-size: 13px;
    color: rgba(255, 255, 255, 0.7);
  }
  .exif-tag {
    display: flex;
    align-items: center;
    gap: 6px;
    background: rgba(255, 255, 255, 0.06);
    padding: 3px 8px;
    border-radius: 4px;
  }

  /* Main View */
  .main-content {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #121212;
  }
  
  /* Empty State */
  .empty-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 16px;
  }
  .empty-icon {
    font-size: 72px;
    color: rgba(255, 255, 255, 0.2);
  }
  .empty-title {
    font-size: 24px;
    font-weight: 700;
    color: rgba(255, 255, 255, 0.85);
  }
  .empty-subtitle {
    font-size: 15px;
    color: rgba(255, 255, 255, 0.4);
    max-width: 520px;
    line-height: 1.5;
  }
  .btn-primary {
    background-color: #FFC107;
    color: #121212;
    border: none;
    padding: 12px 28px;
    border-radius: 8px;
    font-size: 15px;
    font-weight: 700;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    box-shadow: 0 4px 12px rgba(255, 193, 7, 0.3);
  }

  /* Photo Preview View */
  .photo-frame {
    width: 1500px;
    height: 850px;
    background: linear-gradient(180deg, #1A2634 0%, #111B24 100%);
    border-radius: 12px;
    box-shadow: 0 16px 40px rgba(0,0,0,0.6);
    border: 1px solid rgba(255, 255, 255, 0.08);
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  .photo-frame.selected {
    border: 3px solid #4CAF50;
    box-shadow: 0 0 30px rgba(76, 175, 80, 0.3);
  }
  .photo-bg-mountains {
    position: absolute;
    bottom: 0;
    width: 100%;
    height: 380px;
    background: radial-gradient(circle at 50% 100%, #203A43, #0F2027);
    clip-path: polygon(0% 100%, 0% 60%, 20% 30%, 40% 50%, 65% 20%, 85% 45%, 100% 25%, 100% 100%);
    opacity: 0.85;
  }
  .photo-badge-watermark {
    position: absolute;
    top: 24px;
    left: 24px;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.15);
    padding: 8px 16px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    color: #FFC107;
  }

  /* Bottom Control Bar */
  .bottom-bar {
    position: absolute;
    bottom: 24px;
    background: rgba(30, 30, 30, 0.92);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 36px;
    padding: 8px 24px;
    display: flex;
    align-items: center;
    gap: 16px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.5);
    z-index: 20;
  }
  .control-btn {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }
  .btn-select {
    background: #2E7D32;
    color: #ffffff;
    width: 48px;
    height: 48px;
    font-size: 22px;
    box-shadow: 0 4px 12px rgba(46, 125, 50, 0.4);
  }
  .btn-delete {
    color: #FF5252;
  }

  /* Info Modal */
  .modal-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.75);
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
  }
  .modal-card {
    width: 620px;
    background: #222222;
    border-radius: 16px;
    border: 1px solid rgba(255, 193, 7, 0.4);
    box-shadow: 0 24px 60px rgba(0,0,0,0.8);
    padding: 32px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  .modal-header {
    display: flex;
    align-items: center;
    gap: 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    padding-bottom: 16px;
  }
  .shortcut-table {
    width: 100%;
    border-collapse: collapse;
  }
  .shortcut-table td {
    padding: 10px 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    font-size: 14px;
  }
  .key-badge {
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.25);
    padding: 4px 10px;
    border-radius: 6px;
    font-family: monospace;
    font-weight: bold;
    color: #FFC107;
  }
</style>
"""

def generate_screenshots():
    # 1. Schermata Iniziale
    html_1 = f"""<!DOCTYPE html><html><head><meta charset="utf-8">{HTML_COMMON_CSS}</head><body>
      <div class="top-bar">
        <div class="top-row">
          <div class="brand-group">
            <div class="app-logo">✹</div>
            <div class="app-title">RAW Manager</div>
            <div class="badge-info">ℹ INFO</div>
          </div>
          <div class="actions-group">
            <button class="btn-outlined">📁 Apri Sorgente</button>
            <button class="btn-outlined btn-target">📂 Seleziona Target</button>
            <div class="switch-group"><span>Auto-Advance</span><div class="switch-box"><div class="switch-circle"></div></div></div>
          </div>
        </div>
      </div>
      <div class="main-content">
        <div class="empty-card">
          <div class="empty-icon">📷</div>
          <div class="empty-title">Nessun file RAW caricato</div>
          <div class="empty-subtitle">Seleziona una cartella contenente file RAW (.RAF Fujifilm, .DNG, .ARW Sony, .NEF Nikon, .CR2/CR3 Canon) per iniziare il culling istantaneo.</div>
          <button class="btn-primary">📁 Apri Cartella RAW</button>
        </div>
      </div>
    </body></html>"""
    
    # 2. Schermata Culling Attivo
    html_2 = f"""<!DOCTYPE html><html><head><meta charset="utf-8">{HTML_COMMON_CSS}</head><body>
      <div class="top-bar">
        <div class="top-row">
          <div class="brand-group">
            <div class="app-logo">✹</div>
            <div class="app-title">RAW Manager</div>
            <div class="badge-info">ℹ INFO</div>
            <div class="counter-badge">1 / 148</div>
          </div>
          <div class="file-badge">
            <div class="file-name">DSCF2341.RAF</div>
          </div>
          <div class="actions-group">
            <button class="btn-outlined">📁 Sorgente: 101_FUJI</button>
            <button class="btn-outlined btn-target">📂 Target: Selezione_RAW</button>
            <div class="switch-group"><span>Auto-Advance</span><div class="switch-box"><div class="switch-circle"></div></div></div>
          </div>
        </div>
        <div class="exif-bar">
          <div class="exif-tag">ℹ FUJIFILM X-T5 • 1/500s • f/2.8 • ISO 160 • 50mm • 40.2 MP</div>
          <div style="color: #4CAF50;">⚡ Estrazione hardware in 5.8 ms</div>
        </div>
      </div>
      <div class="main-content">
        <div class="photo-frame">
          <div class="photo-badge-watermark">FUJIFILM X-T5 • RAW ANTEPRIMA AD ALTA FEDELTÀ</div>
          <div class="photo-bg-mountains"></div>
          <div style="font-size: 28px; font-weight: bold; color: rgba(255,255,255,0.7); z-index: 5;">PAESAGGIO DOLOMITI (DSCF2341.RAF)</div>
          <div style="font-size: 15px; color: rgba(255,255,255,0.4); margin-top: 8px; z-index: 5;">Decodifica a piena risoluzione 40MP senza artefatti di compressione</div>
        </div>
        <div class="bottom-bar">
          <button class="control-btn">◀</button>
          <button class="control-btn btn-delete">🗑</button>
          <button class="control-btn btn-select">✓</button>
          <button class="control-btn">🔍</button>
          <button class="control-btn">▶</button>
        </div>
      </div>
    </body></html>"""

    # 3. Schermata Foto Selezionata
    html_3 = f"""<!DOCTYPE html><html><head><meta charset="utf-8">{HTML_COMMON_CSS}</head><body>
      <div class="top-bar">
        <div class="top-row">
          <div class="brand-group">
            <div class="app-logo">✹</div>
            <div class="app-title">RAW Manager</div>
            <div class="badge-info">ℹ INFO</div>
            <div class="counter-badge">1 / 148</div>
          </div>
          <div class="file-badge">
            <div class="file-name">DSCF2341.RAF</div>
            <div class="badge-selected">SELEZIONATA ✓</div>
          </div>
          <div class="actions-group">
            <button class="btn-outlined">📁 Sorgente: 101_FUJI</button>
            <button class="btn-outlined btn-target">📂 Target: Selezione_RAW</button>
            <div class="switch-group"><span>Auto-Advance</span><div class="switch-box"><div class="switch-circle"></div></div></div>
          </div>
        </div>
        <div class="exif-bar">
          <div class="exif-tag">ℹ FUJIFILM X-T5 • 1/500s • f/2.8 • ISO 160 • 50mm</div>
          <div style="color: #FFC107;">Coda I/O: 1 trasferimento in background</div>
        </div>
      </div>
      <div class="main-content">
        <div class="photo-frame selected">
          <div class="photo-badge-watermark" style="color: #4CAF50; border-color: #4CAF50;">✓ FILE RAW SELEZIONATO PER LA COPIA</div>
          <div class="photo-bg-mountains"></div>
          <div style="font-size: 28px; font-weight: bold; color: #4CAF50; z-index: 5;">ACCODATO IN CARTELLA TARGET</div>
          <div style="font-size: 15px; color: rgba(255,255,255,0.6); margin-top: 8px; z-index: 5;">Copia asincrona ultra-veloce senza bloccare la navigazione delle foto</div>
        </div>
        <div class="bottom-bar">
          <button class="control-btn">◀</button>
          <button class="control-btn btn-delete">🗑</button>
          <button class="control-btn btn-select" style="background: #1B5E20;">✓</button>
          <button class="control-btn">🔍</button>
          <button class="control-btn">▶</button>
        </div>
      </div>
    </body></html>"""

    # 4. Dialog Informazioni e Scorciatoie
    html_4 = f"""<!DOCTYPE html><html><head><meta charset="utf-8">{HTML_COMMON_CSS}</head><body>
      <div class="top-bar">
        <div class="top-row">
          <div class="brand-group">
            <div class="app-logo">✹</div>
            <div class="app-title">RAW Manager</div>
            <div class="badge-info">ℹ INFO</div>
          </div>
        </div>
      </div>
      <div class="main-content">
        <div class="modal-overlay">
          <div class="modal-card">
            <div class="modal-header">
              <div class="app-logo">✹</div>
              <div>
                <div style="font-size: 20px; font-weight: bold; color: #ffffff;">Guida e Scorciatoie di RAW Manager</div>
                <div style="font-size: 13px; color: rgba(255,255,255,0.5);">Culling istantaneo a prova di nonna</div>
              </div>
            </div>
            <table class="shortcut-table">
              <tr><td><span class="key-badge">Spazio</span></td><td><b>Seleziona e Copia:</b> trasferisce il file RAW nella cartella Target con auto-advance.</td></tr>
              <tr><td><span class="key-badge">▶ / J</span></td><td><b>Foto Successiva:</b> avanza istantaneamente allo scatto successivo.</td></tr>
              <tr><td><span class="key-badge">◀ / K</span></td><td><b>Foto Precedente:</b> torna allo scatto precedente.</td></tr>
              <tr><td><span class="key-badge">Canc / Backspace</span></td><td><b>Elimina RAW:</b> elimina il file RAW non riuscito per liberare spazio.</td></tr>
              <tr><td><span class="key-badge">Z / Doppio Tap</span></td><td><b>Zoom 100%:</b> ingrandisce i dettagli al 100% per verificare nitidezza e fuoco.</td></tr>
              <tr><td><span class="key-badge">H / Singolo Tap</span></td><td><b>Schermo Intero:</b> nasconde o mostra le barre per una visione pulita.</td></tr>
              <tr><td><span class="key-badge">Swipe Orizzontale</span></td><td><b>Navigazione Touch:</b> scorri a destra/sinistra su Android.</td></tr>
            </table>
            <div style="text-align: right;">
              <button class="btn-primary" style="padding: 8px 20px;">Ho Capito, Inizia!</button>
            </div>
          </div>
        </div>
      </div>
    </body></html>"""

    screens = [
        ("01_schermata_iniziale.png", html_1),
        ("02_schermata_culling.png", html_2),
        ("03_foto_selezionata.png", html_3),
        ("04_dialog_informazioni.png", html_4),
    ]

    for filename, html_content in screens:
        tmp_html = Path(f"/tmp/{filename}.html")
        tmp_html.write_text(html_content, encoding="utf-8")
        out_png = OUTPUT_DIR / filename
        cmd = [
            "google-chrome",
            "--headless",
            "--no-sandbox",
            "--window-size=1920,1080",
            f"--screenshot={out_png}",
            str(tmp_html),
        ]
        subprocess.run(cmd, check=True)
        print(f"[OK] Generato screenshot: {out_png}")

if __name__ == "__main__":
    generate_screenshots()

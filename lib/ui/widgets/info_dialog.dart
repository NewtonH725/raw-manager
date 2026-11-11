import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class InfoDialog extends StatelessWidget {
  const InfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const InfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.amber, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RAW Manager v${UpdateService.appVersion} — Guida Semplice',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Come funziona, perché è così veloce e come usarlo al meglio',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),

              // Scrollable Content
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionCard(
                      icon: Icons.lightbulb_outline,
                      color: Colors.amber,
                      title: '1. Spiegato a mia Nonna: Il Trucco del Francobollo',
                      content:
                          'Immagina che ogni foto RAW della tua macchina fotografica sia un quadro a olio gigante da 50 Megabyte. '
                          'I programmi tradizionali provano a ridipingere il quadro da capo ogni volta che giri pagina, e per questo il computer si surriscalda e va a scatti.\n\n'
                          'RAW Manager invece fa una cosa furba: sa che la macchina fotografica ha già attaccato dietro al quadro una cartolina a colori nitidissima (il JPEG di anteprima). '
                          'Invece di ridipingere tutto, noi stacchiamo e mostriamo solo quella cartolina in meno di 5 millesimi di secondo!',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.view_carousel_outlined,
                      color: Colors.cyanAccent,
                      title: '2. La Finestra che Scorre (Sliding Window)',
                      content:
                          'Come fa a scorrere 5.000 foto senza finire la memoria del computer o del tablet?\n'
                          'L\'app tiene a mente solo la foto che stai guardando, le 2 prima e le 3 successive. '
                          'Tutte le altre vengono dimenticate istantaneamente. Così il tuo Dell Latitude o il tuo tablet restano freschi e veloci come il primo minuto.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.keyboard_rounded,
                      color: Colors.greenAccent,
                      title: '3. Comandi Fulminei da Tastiera e Touch',
                      content:
                          '• Barra Spazio (o tasto verde): Seleziona la foto e la copia nella cartella dei migliori scatti.\n'
                          '• Auto-Advance: Gira pagina da solo subito dopo aver scelto uno scatto.\n'
                          '• Frecce o J / K (o swipe): Sfoglia avanti e indietro senza attese.\n'
                          '• Tasto Z (o tocco Lente): Ingrandisce al 100% per verificare se gli occhi sono a fuoco.\n'
                          '• Tasto Canc: Getta nel cestino lo scatto venuto male.\n'
                          '• Tasto H: Nasconde tutti i pulsanti per godersi la foto a tutto schermo.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.camera_enhance_outlined,
                      color: Colors.purpleAccent,
                      title: '4. Formati RAW Supportati',
                      content:
                          'Supporto universale ad accesso istantaneo:\n'
                          '• Fujifilm: .RAF (X-T5, X-H2, X-T4, ecc.)\n'
                          '• Adobe: .DNG universale\n'
                          '• Sony: .ARW (Alpha 7, Alpha 9, ecc.)\n'
                          '• Nikon: .NEF (Z6, Z7, Z8, D850, ecc.)\n'
                          '• Canon: .CR2 e .CR3 (EOS R, 5D, ecc.)\n'
                          '• Panasonic / Olympus / Pentax: .RW2, .ORF, .PEF',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      icon: Icons.layers_outlined,
                      color: Colors.blueAccent,
                      title: '5. Dietro le Quinte (Lo Stack Tecnologico)',
                      content:
                          '• Motore Grafico: Flutter (Dart 3) compilato nativamente (AOT) per Linux, Windows e Android con rendering Impeller a 60/120 FPS.\n'
                          '• Operai Multi-thread (Isolates): Il lavoro pesante di lettura da disco avviene su lavoratori separati, così lo schermo non si blocca mai.\n'
                          '• Architettura DOE: Costruita con il metodo Direttive, Orchestrazione ed Esecuzione deterministica per garantire zero errori.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

              // Footer button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ho Capito, Grazie!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

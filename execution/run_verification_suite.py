#!/usr/bin/env python3
"""
execution/run_verification_suite.py
Esegue `flutter analyze` e `flutter test`.
Salva l'output in `.tmp/qa_reports/latest_report.txt`.
Restituisce exit code != 0 se ci sono errori, lints/warnings o test falliti.
"""

import os
import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
REPORTS_DIR = BASE_DIR / ".tmp" / "qa_reports"

def get_flutter_cmd():
    user_flutter = Path.home() / "flutter" / "bin" / "flutter"
    if user_flutter.exists():
        return str(user_flutter)
    return "flutter"

def run_command(cmd, log_file):
    cmd_str = " ".join(cmd)
    print(f"\n[SUITE] Esecuzione: {cmd_str}")
    log_file.write(f"\n=== CMD: {cmd_str} ===\n")
    
    result = subprocess.run(
        cmd,
        cwd=BASE_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    
    print(result.stdout)
    log_file.write(result.stdout)
    log_file.write(f"\nExit Code: {result.returncode}\n")
    return result.returncode

def main():
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_file_path = REPORTS_DIR / "latest_report.txt"
    flutter_bin = get_flutter_cmd()
    
    overall_status = 0
    with open(report_file_path, "w", encoding="utf-8") as rf:
        rf.write("=== RAW Manager QA Verification Report ===\n")
        
        # 1. flutter analyze
        code_analyze = run_command([flutter_bin, "analyze", "--no-fatal-infos"], rf)
        if code_analyze != 0:
            print("[ERRORE] 'flutter analyze' ha riportato errori o avvisi.")
            overall_status = code_analyze
            
        # 2. flutter test
        code_test = run_command([flutter_bin, "test"], rf)
        if code_test != 0:
            print("[ERRORE] 'flutter test' ha riscontrato test falliti.")
            if overall_status == 0:
                overall_status = code_test

    print(f"\nReport QA salvato in: {report_file_path}")
    if overall_status == 0:
        print("[SUCCESSO] Tutti i controlli QA sono passati con 0 errori!")
    else:
        print(f"[FALLIMENTO] La suite QA ha rilevato problemi. Exit code: {overall_status}")
        
    sys.exit(overall_status)

if __name__ == "__main__":
    main()

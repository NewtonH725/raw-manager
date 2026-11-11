#!/usr/bin/env python3
"""
execution/build_releases.py
Rileva le toolchain disponibili, compila le release AOT per Windows, Linux e Android,
crea gli archivi in releases/ e genera il manifesto SHA256SUMS.txt.
"""

import hashlib
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
RELEASES_DIR = BASE_DIR / "releases"
REPORTS_DIR = BASE_DIR / ".tmp" / "qa_reports"
BUILD_REPORT = REPORTS_DIR / "build_report.txt"

def get_app_version() -> str:
    pubspec = BASE_DIR / "pubspec.yaml"
    if pubspec.exists():
        content = pubspec.read_text(encoding="utf-8")
        m = re.search(r'^version:\s*([^\s+]+)', content, re.MULTILINE)
        if m:
            return m.group(1).strip()
    return "1.0.0"

APP_VERSION = get_app_version()

def get_flutter_cmd():
    user_flutter = Path.home() / "flutter" / "bin" / "flutter"
    if user_flutter.exists():
        return str(user_flutter)
    return "flutter"

def calculate_sha256(file_path: Path) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def update_sha256sums(manifest_path: Path, releases_dir: Path):
    entries = []
    for item in sorted(releases_dir.iterdir()):
        if item.is_file() and item.name != "SHA256SUMS.txt":
            sha = calculate_sha256(item)
            entries.append(f"{sha}  {item.name}")
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write("\n".join(entries) + "\n")
    print(f"[OK] Manifesto SHA256 aggiornato con {len(entries)} file.")

def run_build(cmd, log_file, env=None):
    cmd_str = " ".join(cmd)
    print(f"[BUILD] Esecuzione: {cmd_str}")
    log_file.write(f"\n=== BUILD CMD: {cmd_str} ===\n")
    
    current_env = os.environ.copy()
    if env:
        current_env.update(env)
        
    proc = subprocess.run(
        cmd,
        cwd=BASE_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=current_env
    )
    log_file.write(proc.stdout)
    log_file.write(f"\nExit Code: {proc.returncode}\n")
    return proc.returncode == 0

def check_linux_prerequisites():
    """Verifica presenza toolchain desktop Linux: clang, cmake, ninja, pkg-config, gtk3."""
    missing = []
    for tool in ["cmake", "ninja", "pkg-config", "clang"]:
        if shutil.which(tool) is None:
            missing.append(tool)
    return missing

def check_android_prerequisites():
    """Verifica presenza Android SDK e Java."""
    has_java = shutil.which("java") is not None or "JAVA_HOME" in os.environ
    has_sdk = "ANDROID_HOME" in os.environ or (Path.home() / "Android" / "Sdk").exists()
    return has_java and has_sdk

def build_linux(flutter_bin, log_file):
    print("\n--- Compilazione Release Ubuntu Linux ---")
    missing = check_linux_prerequisites()
    if missing:
        msg = (
            f"[AVVISO] Toolchain C++/GTK per Linux incompleta. Mancano: {', '.join(missing)}.\n"
            "Per abilitare la compilazione desktop su Ubuntu, eseguire:\n"
            "sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev zenity\n"
        )
        print(msg)
        log_file.write(msg + "\n")
        return False

    success = run_build([flutter_bin, "build", "linux", "--release"], log_file)
    if not success:
        print("[ERRORE] Compilazione Linux fallita.")
        return False

    bundle_dir = BASE_DIR / "build" / "linux" / "x64" / "release" / "bundle"
    if not bundle_dir.exists():
        print(f"[ERRORE] Directory bundle Linux {bundle_dir} non trovata.")
        return False

    target_archive = RELEASES_DIR / f"RAW_Manager_v{APP_VERSION}_Ubuntu_x64_Bundle.tar.gz"
    print(f"Creazione archivio compresso {target_archive.name}...")
    with tarfile.open(target_archive, "w:gz") as tar:
        tar.add(bundle_dir, arcname="RAW_Manager")
    print(f"[OK] Release Linux creata con successo: {target_archive}")
    return True

def build_windows(flutter_bin, log_file):
    print("\n--- Compilazione Release Windows ---")
    if platform.system() != "Windows":
        msg = f"[INFO] Compilazione Windows saltata: host corrente è {platform.system()} (richiede host Windows con Visual Studio 2022 C++)."
        print(msg)
        log_file.write(msg + "\n")
        return False

    success = run_build([flutter_bin, "build", "windows", "--release"], log_file)
    if not success:
        print("[ERRORE] Compilazione Windows fallita.")
        return False

    runner_dir = BASE_DIR / "build" / "windows" / "x64" / "runner" / "Release"
    if not runner_dir.exists():
        print(f"[ERRORE] Directory build Windows {runner_dir} non trovata.")
        return False

    target_zip = RELEASES_DIR / f"RAW_Manager_v{APP_VERSION}_Windows_x64_Portable.zip"
    print(f"Creazione archivio portatile {target_zip.name}...")
    with zipfile.ZipFile(target_zip, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(runner_dir):
            for file in files:
                p = Path(root) / file
                arcname = p.relative_to(runner_dir)
                zipf.write(p, arcname=f"RAW_Manager/{arcname}")
    print(f"[OK] Release Windows creata con successo: {target_zip}")
    return True

def build_android(flutter_bin, log_file):
    print("\n--- Compilazione Release Android APK ---")
    if not check_android_prerequisites():
        msg = (
            "[AVVISO] Android SDK o Java non configurati. Per abilitare la build Android:\n"
            "Assicurati che ANDROID_HOME sia impostato (es. $HOME/Android/Sdk) e Java JDK 17 sia installato."
        )
        print(msg)
        log_file.write(msg + "\n")
        return False

    # Assicura ANDROID_HOME in env
    env = {}
    if "ANDROID_HOME" not in os.environ and (Path.home() / "Android" / "Sdk").exists():
        env["ANDROID_HOME"] = str(Path.home() / "Android" / "Sdk")

    success = run_build([flutter_bin, "build", "apk", "--release", "--split-per-abi"], log_file, env=env)
    if not success:
        print("[ERRORE] Compilazione APK Android fallita.")
        return False

    arm64_apk = BASE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-arm64-v8a-release.apk"
    if not arm64_apk.exists():
        # Fallback se non splittato o nome alternativo
        alt_apk = BASE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        if alt_apk.exists():
            arm64_apk = alt_apk
        else:
            print("[ERRORE] File APK di output non trovato.")
            return False

    target_apk = RELEASES_DIR / f"RAW_Manager_v{APP_VERSION}_Android_arm64.apk"
    shutil.copy2(arm64_apk, target_apk)
    print(f"[OK] Release Android creata con successo: {target_apk}")
    return True

def main():
    RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    flutter_bin = get_flutter_cmd()

    with open(BUILD_REPORT, "w", encoding="utf-8") as log_file:
        log_file.write("=== RAW Manager Build & Packaging Report ===\n")
        log_file.write(f"Host OS: {platform.system()} ({platform.release()})\n")
        log_file.write(f"Architecture: {platform.machine()}\n\n")

        # 1. Esegui build corrispondenti alla piattaforma
        current_os = platform.system()
        built_any = False

        if current_os == "Linux":
            if build_linux(flutter_bin, log_file):
                built_any = True
        elif current_os == "Windows":
            if build_windows(flutter_bin, log_file):
                built_any = True

        # 2. Android APK
        if check_android_prerequisites():
            if build_android(flutter_bin, log_file):
                built_any = True
        else:
            msg = "[INFO] Android SDK non rilevato, build APK saltata."
            print(msg)
            log_file.write(msg + "\n")

        # 3. Aggiorna manifesto SHA-256
        update_sha256sums(RELEASES_DIR / "SHA256SUMS.txt", RELEASES_DIR)
        
    print(f"\nReport di build salvato in: {BUILD_REPORT}")

if __name__ == "__main__":
    main()

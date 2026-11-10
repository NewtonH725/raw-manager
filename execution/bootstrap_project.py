#!/usr/bin/env python3
"""
execution/bootstrap_project.py
Inizializza lo scaffolding del progetto Flutter `raw_manager`, configura dipendenze pubspec,
branding "RAW Manager", permessi Android in AndroidManifest.xml e ottimizzazioni gradle.properties.
"""

import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

def run_command(cmd, cwd=BASE_DIR):
    print(f"[RUN] {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    res = subprocess.run(cmd, cwd=cwd, shell=isinstance(cmd, str), capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[STDERR] {res.stderr}")
        raise RuntimeError(f"Comando fallito con exit code {res.returncode}: {cmd}")
    return res.stdout

def get_flutter_cmd():
    # Cerca flutter nel PATH o in ~/flutter/bin/flutter
    user_flutter = Path.home() / "flutter" / "bin" / "flutter"
    if user_flutter.exists():
        return str(user_flutter)
    return "flutter"

def init_flutter_project():
    pubspec = BASE_DIR / "pubspec.yaml"
    flutter_bin = get_flutter_cmd()
    if not pubspec.exists():
        print("Inizializzazione progetto Flutter con nome raw_manager...")
        run_command([flutter_bin, "create", "--project-name", "raw_manager", "--platforms=windows,linux,android", "."])
    else:
        print("Progetto Flutter già presente.")

def add_dependencies():
    pubspec_path = BASE_DIR / "pubspec.yaml"
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Dipendenze richieste: flutter_riverpod, file_picker, permission_handler, path, exif
    deps_to_add = {
        "flutter_riverpod": "^2.6.1",
        "file_picker": "^8.3.1",
        "permission_handler": "^11.4.0",
        "path": "^1.9.1",
        "exif": "^3.3.0",
    }

    # Aggiungi a dependencies se non già presenti
    lines = content.splitlines()
    new_lines = []
    in_dependencies = False
    added = set()

    for line in lines:
        new_lines.append(line)
        if line.strip() == "dependencies:":
            in_dependencies = True
            for dep, ver in deps_to_add.items():
                if f"{dep}:" not in content:
                    new_lines.append(f"  {dep}: {ver}")
                    added.add(dep)
        elif in_dependencies and not line.startswith(" ") and line.strip() != "":
            in_dependencies = False

    if added:
        with open(pubspec_path, "w", encoding="utf-8") as f:
            f.write("\n".join(new_lines) + "\n")
        print(f"[OK] Dipendenze aggiunte al pubspec.yaml: {', '.join(added)}")
        flutter_bin = get_flutter_cmd()
        run_command([flutter_bin, "pub", "get"])
    else:
        print("[OK] Tutte le dipendenze sono già registrate.")

def patch_android_manifest():
    manifest_path = BASE_DIR / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.exists():
        print(f"[WARN] {manifest_path} non trovato.")
        return

    # Registra namespace Android
    ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
    ET.register_namespace("tools", "http://schemas.android.com/tools")
    
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    android_ns = "{http://schemas.android.com/apk/res/android}"

    # Imposta label su application
    app_elem = root.find("application")
    if app_elem is not None:
        app_elem.set(f"{android_ns}label", "RAW Manager")
        app_elem.set(f"{android_ns}requestLegacyExternalStorage", "true")

    # Permessi necessari
    required_permissions = [
        "android.permission.MANAGE_EXTERNAL_STORAGE",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_IMAGES",
    ]

    existing_perms = {p.get(f"{android_ns}name") for p in root.findall("uses-permission")}
    for perm in required_permissions:
        if perm not in existing_perms:
            p_elem = ET.SubElement(root, "uses-permission")
            p_elem.set(f"{android_ns}name", perm)

    tree.write(manifest_path, encoding="utf-8", xml_declaration=True)
    print("[OK] AndroidManifest.xml aggiornato con label 'RAW Manager' e permessi storage.")

def patch_linux_window_title():
    for rel_path in ["linux/my_application.cc", "linux/runner/my_application.cc"]:
        cc_path = BASE_DIR / rel_path
        if not cc_path.exists():
            continue
        with open(cc_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Sostituisci il titolo finestra gtk_window_set_title
        new_content = re.sub(
            r'gtk_window_set_title\(window,\s*"[^"]*"\);',
            'gtk_window_set_title(window, "RAW Manager");',
            content
        )
        if new_content != content:
            with open(cc_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"[OK] Titolo finestra Linux aggiornato a 'RAW Manager' in {rel_path}.")

def patch_windows_window_title():
    cpp_path = BASE_DIR / "windows" / "runner" / "main.cpp"
    if not cpp_path.exists():
        return
    with open(cpp_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_content = re.sub(
        r'window\.Create\(L"[^"]*",',
        'window.Create(L"RAW Manager",',
        content
    )
    if new_content != content:
        with open(cpp_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("[OK] Titolo finestra Windows aggiornato a 'RAW Manager'.")

def configure_gradle_properties():
    gradle_props_path = BASE_DIR / "android" / "gradle.properties"
    if gradle_props_path.exists():
        with open(gradle_props_path, "r", encoding="utf-8") as f:
            content = f.read()

        settings_to_apply = {
            "org.gradle.jvmargs": "-Xmx4096m -Dfile.encoding=UTF-8",
            "org.gradle.parallel": "true",
            "android.useAndroidX": "true",
            "android.enableJetifier": "true",
        }

        lines = content.splitlines()
        updated_keys = set()
        new_lines = []

        for line in lines:
            matched = False
            for k, v in settings_to_apply.items():
                if line.startswith(f"{k}="):
                    new_lines.append(f"{k}={v}")
                    updated_keys.add(k)
                    matched = True
                    break
            if not matched:
                new_lines.append(line)

        for k, v in settings_to_apply.items():
            if k not in updated_keys:
                new_lines.append(f"{k}={v}")

        with open(gradle_props_path, "w", encoding="utf-8") as f:
            f.write("\n".join(new_lines) + "\n")
        print("[OK] android/gradle.properties ottimizzato per 24GB RAM (-Xmx4096m e parallel=true).")

    # Assicura compileSdk = 36 per compatibilità Android AAR metadata
    app_gradle_path = BASE_DIR / "android" / "app" / "build.gradle.kts"
    if app_gradle_path.exists():
        with open(app_gradle_path, "r", encoding="utf-8") as f:
            app_gradle = f.read()
        if "compileSdk = flutter.compileSdkVersion" in app_gradle:
            app_gradle = app_gradle.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")
            with open(app_gradle_path, "w", encoding="utf-8") as f:
                f.write(app_gradle)
            print("[OK] android/app/build.gradle.kts configurato con compileSdk = 36.")

def main():
    print("=== BOOTSTRAP PROGETTO RAW MANAGER ===")
    init_flutter_project()
    add_dependencies()
    patch_android_manifest()
    patch_linux_window_title()
    patch_windows_window_title()
    configure_gradle_properties()
    print("=== BOOTSTRAP COMPLETATO CON SUCCESSO ===")

if __name__ == "__main__":
    main()

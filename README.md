# Wachsen & Verflechten

Gewaltfreies 2D-Logikpuzzle als native Android-App, gebaut mit **Godot 4.7** (GDScript).
Spielidee und festgelegte Regeln: siehe `spielidee.md`.

## Projektstruktur

| Pfad | Inhalt |
|---|---|
| `scripts/core/` | Reine Spiellogik ohne Grafik: `LevelData` (Level-Format), `BoardState` (Regeln), `LevelSolver` (Prüfung) |
| `scripts/game/` | Spielansicht: `BoardView` (Spielfeld, Touch, Effekte), `GameScreen` (Kopfzeile, Status, Gewinn-Overlay) |
| `scripts/menu/` | `TreeMenu`: der Lebensbaum als Levelauswahl |
| `scripts/ui/` | `Art` (Farben, Zeichenroutinen), Theme, Knöpfe, Einstellungen |
| `scripts/autoload/` | Globale Dienste: `Progress` (Spielstand), `LevelDB`, `Sound` (prozedurale Klänge), `Haptics` |
| `levels/` | Level als JSON, ein File pro Kapitel; Reihenfolge in `index.json` |
| `tools/`, `tests/` | Entwicklerwerkzeuge, werden nicht exportiert |

## Level-Format

```json
{"id": "1-04", "name": "Der erste Stein", "hint": "optional",
 "grid": ["1..", "ZX.", "..."],
 "solution": {"1": "RRDDLLU"}}
```

- Raster: `.` leer, `X` Stein, `Z` Blüte (Ziel-Knospe), `1`–`6` Startknospen
- `solution`: gewollte Hauptlösung pro Startknospe als Richtungen `U`/`D`/`L`/`R`
- Jede Ranke muss in einer Blüte enden, je eine pro Seite (also höchstens 4 Ranken pro Blüte)
- Mehrere Blüten (ab Stufe 8): bis zu drei `Z` im Raster; jede Ranke darf in jede Blüte, jede Blüte braucht mindestens eine Ranke
- Kreuzungen (ab Stufe 16): `a`–`f` im Raster, die zwei Farben unter `"crossings": {"a": "12"}`

## Befehle

`godot` steht hier für `Godot_v4.7.2-stable_win64_console.exe`.

```sh
# Alle Level prüfen (Format, Hauptlösung, Anzahl Lösungen)
godot --headless --path . --script res://tools/validate_levels.gd

# Neue Level-Kandidaten erzeugen (Python): Breite Höhe Ranken; gibt die
# schwierigsten eindeutigen Level als JSON aus
python tools/generate_levels.py 6 6 3 --stones 5 --attempts 5000
# mit mehreren Blüten; --stream gibt jeden Fund sofort aus
python tools/generate_levels.py 6 7 3 --goals 2 --stones 8 --attempts 25000 --stream

# Regeltests
godot --headless --path . --script res://tests/test_board.gd

# Bildschirmfoto (Level 1-09 gelöst)
godot --path . --resolution 540x960 -- --capture shot.png 0 8 win

# Debug-APK bauen
godot --headless --path . --export-debug "Android" build/wachsen-und-verflechten.apk
```

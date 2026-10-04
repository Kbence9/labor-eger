# Labor Egér

Szívatós labirintusjáték egy kísérleti egérrel, pöttyös papíros stílusban. Nincs jelmagyarázat:
a játékos halálokon keresztül tanul. Mobilra (Android, később iOS) és webre készül, Godot 4.7-ben.

- **Játszható webes prototípus:** `prototype/labor-eger.html` (böngészőben megnyitható)
- **Játékterv:** [docs/GDD.md](docs/GDD.md)
- **Ütemterv:** [docs/ROADMAP.md](docs/ROADMAP.md)
- **Szabályok agenteknek:** [CLAUDE.md](CLAUDE.md)

## Megnyitás

1. Indítsd a **sima** Godotot: `D:\MyProjects\Godot_v4.7.2-stable_win64.exe` (nem a mono/C# verziót).
2. Import → válaszd ki ezt a mappát (`project.godot`).
3. F5: a jelenleg egy helyőrző jelenet indul, ami betölti a `levels/level_01.json`-t.

## Mappák

```
scenes/        Godot jelenetek (.tscn)
scripts/core/  tiszta játéklogika, Node-független (pálya, lépés, megoldó)
scripts/game/  jelenetekhez kötött kód (rajzolás, input, UI, hang)
levels/        pályák JSON-ban (formátum: docs/GDD.md)
assets/        sprite-ok, hangok, betűk
tools/         segédszkriptek (pl. pálya-ellenőrző)
prototype/     a webes prototípus referenciának
docs/          terv és ütemezés
```

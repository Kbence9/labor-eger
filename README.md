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
3. F5: főmenü → **Kísérlet indítása** (játék) vagy **Pályaszerkesztő**.

## Pályaszerkesztő

- **Fal:** húzd az ujjad / egeret pöttytől pöttyig, mint papíron. Ha meglévő falon kezded a húzást, azt törli. Egy szakasz közepére koppintva is váltogathatod.
- **Tégla:** ugyanígy, áttörhető falat rajzol. **Radír:** falat nyit, tárgyat töröl.
- **Tárgyak:** válaszd ki (Start, Kijárat, Kalapács, Víz, Tűz, Repedés, Sajt, Portál A/B), és koppints a cellára. Ugyanoda még egyszer koppintva leveszed. Start és Kijárat csak egy lehet; portálból párosával kettő.
- **Méret:** Szél ± / Mag ± (4–12 × 4–16).
- **Ellenőriz:** a megoldó megmondja, megoldható-e, és zölddel megrajzolja a legrövidebb utat.
- **Teszt:** azonnal kipróbálod; a Vissza gomb a szerkesztőbe visz vissza.
- **Mentés:** a Godot-szerkesztőből futtatva (F5) egyenesen a repó `levels/` mappájába ment, így commitolható. Telefonon/weben az eszközre ment (`user://levels`).
- **Másol:** a pálya JSON-ja a vágólapra kerül, ha telefonról akarod elküldeni.

## Tesztek

```
godot --headless --path . -s tests/test_core.gd     # minden pálya érvényes és megoldható
xvfb-run godot --path . --resolution 720x1280 -s tests/smoke.gd   # végigjátszás + szerkesztő, képernyőképekkel
```

## Mappák

```
scenes/        Godot jelenetek (.tscn) – a UI kódból épül
tests/         headless és füsttesztek
scripts/core/  tiszta játéklogika, Node-független (pálya, lépés, megoldó)
scripts/game/  jelenetekhez kötött kód (rajzolás, input, UI, hang)
levels/        pályák JSON-ban (formátum: docs/GDD.md)
assets/        sprite-ok, hangok, betűk
tools/         segédszkriptek (pl. pálya-ellenőrző)
prototype/     a webes prototípus referenciának
docs/          terv és ütemezés
```

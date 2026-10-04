# Labor Egér

Szívatós labirintusjáték egy kísérleti egérrel, „Labornapló” stílusban (pöttyös füzet, golyóstoll, piros pecsét). Nincs jelmagyarázat:
a játékos halálokon keresztül tanul. Mobilra (Android, később iOS) és webre készül, Godot 4.7-ben.

- **Játszható webes prototípus:** `prototype/labor-eger.html` (böngészőben megnyitható)
- **Játékterv:** [docs/GDD.md](docs/GDD.md)
- **Ütemterv:** [docs/ROADMAP.md](docs/ROADMAP.md)
- **Szabályok agenteknek:** [CLAUDE.md](CLAUDE.md)

## Megnyitás

1. Indítsd a **sima** Godotot: `D:\MyProjects\Godot_v4.7.2-stable_win64.exe` (nem a mono/C# verziót).
2. Import → válaszd ki ezt a mappát (`project.godot`).
3. F5: nyitó animáció (koppintásra átugorható), utána főmenü → **Kísérlet indítása** / **Pályák** / **Pályaszerkesztő**.

## Pályaszerkesztő

Főmenü → **Pályaszerkesztő** → válassz pályát, vagy **Új pálya** / **Beillesztés** (vágólapról).

**Eszközök** (alul, ikonokkal):
- **Fal:** húzd az ujjad / egeret pöttytől pöttyig, mint papíron. Ha meglévő falon kezded a húzást, azt törli. Egy szakasz közepére koppintva is váltogathatod.
- **Tégla:** ugyanígy, áttörhető falat rajzol. **Radír:** falat nyit, tárgyat töröl.
- **Folyosó:** húzd az ujjad cellán át, és kinyitja a falakat az útvonalon. A „Minden él fal” után így vájsz ki egy labirintust.
- **Tárgyak:** Start, Kijárat, Kalapács, Víz, Tűz, Repedés, Sajt, Portál A/B. Koppints a cellára; ugyanoda még egyszer koppintva leveszed. Start és Kijárat csak egy lehet; portálból párosával kettő.

**Felül:** vissza, a pálya neve, **visszavonás / újra** (Ctrl+Z / Ctrl+Y), és a **⋯ menü**:
labirintus generálása (minden nyomásra új), minden él fal / nyitott, másolat készítése, JSON másolása / beillesztése, új üres pálya, törlés.
**Szélesség / Magasság ±:** 4–12 × 4–16.

**Alul:** **Teszt** (azonnal kipróbálod, a Vissza ide hoz), **Ellenőriz** (a megoldó megmondja, megoldható-e, és zölddel megrajzolja a legrövidebb utat), **Mentés** (Ctrl+S; mentéskor is ellenőriz).
- Ha mentetlen változással lépnél ki, rákérdez.
- A Godot-szerkesztőből futtatva (F5) a repó `levels/` mappájába ment, így commitolható. Telefonon/weben az eszközre ment (`user://levels`).
- **Sorrend:** a szerkesztő pályalistájában a ▲▼ nyilakkal (`levels/order.json`).

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
levels/        pályák JSON-ban (formátum: docs/GDD.md) + order.json (sorrend)
assets/        betűk (licencekkel), később hangok
tools/         segédszkriptek (pl. pálya-ellenőrző)
prototype/     a webes prototípus referenciának
docs/          terv és ütemezés
```

# Labor Egér – szabályok agenteknek

- Motor: **Godot 4.7, GDScript** (nem C#: a C# webes exportja 2026 tavaszán még nem támogatott, és a webes build kell a teszteléshez).
- Renderer: GL Compatibility (web + gyengébb Androidok).
- GDScript statikus típusokkal (`var x: int`, `-> void`). Tab behúzás.
- A játékszabályok **csak** a `scripts/core/`-ban élnek, Node-tól függetlenül (`RefCounted`). A jelenetek csak meghívják. Így headless tesztelhető.
- Minden új vagy módosított pályát a megoldó ellenőrizzen: `godot --headless --path . -s tests/test_core.gd` (0-val kell kilépnie).
- UI-változás után futtasd a füsttesztet is (`tests/smoke.gd`, xvfb alatt), és nézd meg a képernyőképeket (`user://shots/`). Az intró videóként: `godot --path . --write-movie /tmp/intro.png --fixed-fps 30 --quit-after 330`.
- A UI kódból épül (`UiKit`), a jelenetfájlok minimálisak. Képernyők: `main.gd` (vezérlés + pályalista), `TitleScreen` (intró + főmenü), `LabGame`, `LabEditor`. Rajzolás: `BoardPainter` (pálya), `Notebook` (füzetlap, pecsét, toll, strigula), `InkBox` (tollal húzott keret), `IconButton` (kódból rajzolt ikonok), `LevelRow`. Haladás: `Progress`.
- Látvány: „Labornapló” (docs/GDD.md). Színek csak a `BoardPainter` konstansaiból, betűk csak a `UiKit`-ből (Kalam, Special Elite, Rubik Dirt). Képfájl helyett kódból rajzolj.
- A `.uid` fájlokat commitold (Godot 4.4+).
- A szabályok forrása a `docs/GDD.md`. Ha a kód eltér tőle, a GDD-t is frissíteni kell ugyanabban a commitban.
- A prototípus (`prototype/labor-eger.html`, logika: `LabLogic` objektum) a viselkedés referenciája, amíg a Godot-verzió el nem éri.
- Git: `main` ág, kis commitok, magyar commit üzenet. Commit-üzenetet mindig adj át Bencének is.

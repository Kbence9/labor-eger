# Labor Egér – szabályok agenteknek

- Motor: **Godot 4.7, GDScript** (nem C#: a C# webes exportja 2026 tavaszán még nem támogatott, és a webes build kell a teszteléshez).
- Renderer: GL Compatibility (web + gyengébb Androidok).
- GDScript statikus típusokkal (`var x: int`, `-> void`). Tab behúzás.
- A játékszabályok **csak** a `scripts/core/`-ban élnek, Node-tól függetlenül (`RefCounted`). A jelenetek csak meghívják. Így headless tesztelhető.
- Minden új vagy módosított pályát a megoldó (`tools/` / `scripts/core/solver.gd`) ellenőrizzen: legyen megoldható.
- A szabályok forrása a `docs/GDD.md`. Ha a kód eltér tőle, a GDD-t is frissíteni kell ugyanabban a commitban.
- A prototípus (`prototype/labor-eger.html`, logika: `LabLogic` objektum) a viselkedés referenciája, amíg a Godot-verzió el nem éri.
- Git: `main` ág, kis commitok, magyar commit üzenet. Commit-üzenetet mindig adj át Bencének is.

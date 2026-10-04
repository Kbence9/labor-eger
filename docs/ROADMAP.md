# Ütemterv

Becslés esti munkára (heti ~6–8 óra). Minden mérföldkő végén legyen valami, amit telefonon ki lehet próbálni.

## M0 – Alap ✅ (2026-10-04)
- Repo, Godot-projekt váz, prototípus és 3 pálya JSON-ban, GDD, ütemterv.

## M1 + M2 – Mag és mechanikák ✅ (2026-10-04)
- `scripts/core/`: `LevelData`, `GameState.step()`, `Solver` – a prototípus logikájának portja, headless teszttel.
- Játék: pöttyös papír, falak, összes elem (kalapács, tégla, víz, tűz, repedés, portálok, sajt), futás + kanyar-puffer, swipe + billentyű, halál/újrakezdés, X-jelölők, számlálók, győzelem.
- **Pályaszerkesztő** (előrehozva M4-ből): falrajzolás pöttytől pöttyig, tárgyak, méret, megoldhatóság-ellenőrzés útvonallal, teszt, mentés, JSON-másolás.
- Füstteszt: mindhárom pálya végigjátszva a megoldóval, halál nélkül.
- Hátra van: webes build telefonra (export sablonok + itch.io / Pages), ez az M5 része lett.

## M3 – Érzés (1–2 hét)
- Animációk (egér futás, halálok), részecskék, kamera-rázás, hangok, rezgés telefonon.
- Halálüzenetek, menü, pályaválasztó, mentés (`user://`).
- **Kész, ha:** egy haver magától, magyarázat nélkül elindul vele.

## M4 – Pályák (2–3 hét)
- 15 pálya növekvő nehézséggel, minden elem előbb biztonságosan jelenik meg, aztán szívat. Bence a szerkesztőben rajzolja őket.
- Szerkesztő-bővítések igény szerint: visszavonás, pálya másolása, pályasorrend állítása.
- **Kész, ha:** 15 pálya, mind megoldható, átlag halálszám mérve.

## M5 – Teszt (most következik)
- Webes export (Godot export sablonok, egyszálas web build), privát itch.io oldalra, link a haveroknak.
- Mérni: hol halnak meg, hol adják fel (halál-heatmap pályánként).

## M6 – Kiadás
- Android: Google Play fejlesztői fiók (egyszeri 25 USD). Új személyes fióknál kötelező zárt teszt: legalább 12 tesztelő, 14 napig.
- Web: itch.io / Poki-jellegű portál.
- iOS később (évi 99 USD, Mac kell vagy felhős build).

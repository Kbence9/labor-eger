# Ütemterv

Becslés esti munkára (heti ~6–8 óra). Minden mérföldkő végén legyen valami, amit telefonon ki lehet próbálni.

## M0 – Alap ✅ (2026-10-04)
- Repo, Godot-projekt váz, prototípus és 3 pálya JSON-ban, GDD, ütemterv.

## M1 – Mag (1–2 hét)
- `scripts/core/level.gd`: JSON betöltés, élek, `edge()`, `step()` – a prototípus `LabLogic` portja.
- `scripts/core/solver.gd` + headless teszt: mindhárom pálya megoldható.
- Rajzolás: pöttyös papír, falak, start/kijárat. Egér mozgás: swipe + billentyű, futás, kanyar-puffer.
- **Kész, ha:** az 1. pálya végigjátszható Godotban, gépen és telefonon (webes build).

## M2 – Mechanikák (1–2 hét)
- Tárgyak és csere, kalapács + tégla, víz + tűz, repedt padló, portálok, sajt.
- Halál, újrakezdés, X-jelölők, idő- és halálszámláló, győzelem képernyő.
- **Kész, ha:** a prototípus mindhárom pályája ugyanúgy működik, mint a weben.

## M3 – Érzés (1–2 hét)
- Animációk (egér futás, halálok), részecskék, kamera-rázás, hangok, rezgés telefonon.
- Halálüzenetek, menü, pályaválasztó, mentés (`user://`).
- **Kész, ha:** egy haver magától, magyarázat nélkül elindul vele.

## M4 – Pályák (2–3 hét)
- 15 pálya növekvő nehézséggel, minden elem előbb biztonságosan jelenik meg, aztán szívat.
- Pályaszerkesztő (legalább gépen) + megoldhatóság-ellenőrzés.
- **Kész, ha:** 15 pálya, mind megoldható, átlag halálszám mérve.

## M5 – Teszt (M2-től folyamatosan)
- Webes build privát itch.io oldalra, link a haveroknak.
- Mérni: hol halnak meg, hol adják fel (halál-heatmap pályánként).

## M6 – Kiadás
- Android: Google Play fejlesztői fiók (egyszeri 25 USD). Új személyes fióknál kötelező zárt teszt: legalább 12 tesztelő, 14 napig.
- Web: itch.io / Poki-jellegű portál.
- iOS később (évi 99 USD, Mac kell vagy felhős build).

# Játékterv (GDD) – élő dokumentum

## Az egy mondat
Kísérleti egér egy kézzel rajzolt labirintusban: semmi magyarázat, sok halál, és minden halál tanít valamit.

## Alapérzés
- Cat Mario / Level Devil-szerű szívatás, de labirintusban, kulcs–zár logikával.
- A halál gyors és vicces, az újrakezdés azonnali. A bolyongás ellenség: a pályák rövidek (20–90 mp, ha tudod a megoldást).
- Labor-téma: alanyok sorszámmal, kísérleti napló, halálüzenetek jegyzetként.

## Irányítás
- Swipe (gépen nyilak/WASD). Egy húzásra az egér végigfut a folyosón.
- Megáll: falnál, kereszteződésnél, tárgyon, portál után, áttörhető fal mellett.
- Futás közbeni húzás puffereződik: a következő lehetséges ponton arra fordul.

## Pálya
- Rács, a falak a cellák közötti éleken (pöttyös papír: pontok a sarkokon, vonalak a falak).
- JSON: `size [C,R]`, nyitott élek `edges` (`"x,y|x,y"`, a szerkesztő ezt menti) és/vagy `paths` (összekötött cellák sorozatai, kézi íráshoz), `breakable` (`"x,y|x,y"`), `objects` (`"x,y": kód`). Minden nem nyitott él fal.
- Pályák: `res://levels/*.json` (beépített, fájlnév szerinti sorrend) + `user://levels/*.json` (eszközön szerkesztett; azonos fájlnévnél felülírja a beépítettet).

| Kód | Elem | Szabály |
|---|---|---|
| S | Start | zöld nyíl |
| E | Kijárat | lila nyíl, belépés = győzelem |
| H | Kalapács | áttöri a téglafalat, nem kopik |
| W | Víz (lombik) | eloltja a tüzet, elfogy |
| F | Tűz | belépés víz nélkül = halál |
| C | Repedt padló | átfutva mögötted beszakad; ha megállsz rajta, 0,45 mp múlva lezuhansz |
| T | Sajt | csapda: belépés = halál |
| A/a, B/b | Portálpár | belépéskor átvisz a párjára, oda-vissza |
| tégla él | Áttörhető fal | kalapáccsal nekimenve eltűnik |

- **Egyszerre egy tárgy.** Tárgyra lépve cserélsz: a régi ott marad.
- Halál: piros X marad a helyén (az adott pályán), a pálya teljesen visszaáll.
- Számlálók: idő (pályánként, halálokon át), halál.
- **Alany sorszáma** globális: az eddigi összes halál + 1 (minden halál egy új alany). A haladás az eszközön: `user://progress.json` (teljesített pályák, legjobb idő, halálok pályánként és összesen).
- Pálya-sorrend: `levels/order.json` (fájlnevek listája); ami nincs benne, a végére kerül név szerint. Telefonon a sorrend `user://levels/order.json`-ba ment.

## Látvány: „Labornapló” (eldöntve, 2026-10-04)
A játék egy kísérletvezető füzete: pöttyös papíron született, ezért a papír maga a stílus. Minden kódból rajzolódik, képfájl nélkül.

| Elem | Érték | Hol |
|---|---|---|
| Füzetoldal | `#e6ebdf` (halvány mérnöki zöld), pöttyök `#b9c3b4`, margó `#d98a82`, lyukasztás | `BoardPainter.BG`, `Notebook.page()` |
| Pályalap | `#f6f7f2`, két sarkán ragasztószalag | `BoardPainter.PAPER`, `draw_tape()` |
| Tinta | `#1e2233` falak és szöveg, `#5d6577` ceruzás megjegyzés | `INK`, `INK_SOFT` |
| Golyóstoll-kék | `#2b3f9e`: gombok, kézzel kitöltött értékek | `PEN` |
| Piros toll | `#c8352e`: halál, X, pecsét, strigulák | `MARK` |
| Szövegkiemelő | `#f5e54b` 85%: a fő gomb, a kijelölt eszköz, a következő pálya | `HIGHLIGHT` |
| Kézírás | Kalam (Regular/Bold): minden gomb, cím, jegyzet | `UiKit.F_HAND`, `F_BOLD` |
| Laborűrlap | Special Elite (írógép): sorszámok, idők, „Kísérlet”, „Alany” | `UiKit.F_TYPE` |
| Pecsét | Rubik Dirt: a cím (LABOR EGÉR) és a SIKERES | `UiKit.F_STAMP` |

Elvek: a merészség egy helyen van (a pecsét); a többi visszafogott tinta a papíron. A gombok keretét tollal húzott, remegő vonal adja (`InkBox`), a kijelölést szövegkiemelő. Halál = piros toll. Új elemhez előbb a meglévő színekből és primitívekből (`BoardPainter`, `Notebook`) építkezz.
A betűk SIL OFL / Apache 2.0 licencűek (`assets/fonts/`), latin + magyar karakterkészletre szűkítve.

## Képernyők
- **Nyitó animáció** (~6 mp, koppintásra átugorható): füzetlap és margó → írógépes fejléc → golyóstoll megrajzolja a labirintust → start/kijárat nyíl, sajt → az egér végigfut és kijut… → a LABOR EGÉR pecsét rácsap, az egér piros lenyomata a pecsét szélén marad → „Alany #0: kijutott. Majdnem.” → előtűnik a menü.
- **Főmenü** ugyanazon a lapon: fejléc (következő kísérlet száma, alany sorszáma), pecsét, a labirintusban bolyongó egér (néha megkóstolja a sajtot: piros X), menü: *Kísérlet indítása/folytatása* (a következő nem teljesített pálya), *Pályák*, *Pályaszerkesztő*; lent az elhunyt alanyok száma (5-től strigulával).
- **Pályák**: tartalomjegyzék sorszámmal, pipával és legjobb idővel; a következő pálya kiemelve.
- **Pályaszerkesztő**: lásd README.
- Vissza: Esc / Android vissza gomb.

## Nyitott kérdések (döntés kell)
1. Végleges név (munkanév: Labor Egér).
2. ~~Látvány~~ → eldöntve: „Labornapló” (lásd fent).
3. Legyen-e „köd” (korlátozott látótér) a későbbi pályákon?
4. Bevétel: kozmetikai karakterek + hirdetésért tipp, vagy fizetős prémium?
5. Kredit / bolt: mi vehető, és mi nem (a „magadtól jössz rá” élmény ne sérüljön).

## Ötletpad (még nem eldöntött elemek)
- Kapcsoló + ajtó, időzített ajtó, csúszós jég, egyirányú forgóajtó, sötét pálya zseblámpával.
- Rejtett troll-elemek: hamis kijárat, láthatatlan fal, „biztonságos” sajt egyszer.
- Új karakterek eltérő képességgel (hörcsög: lassabb, de nem zuhan; csiga: …).

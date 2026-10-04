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

## Nyitott kérdések (döntés kell)
1. Végleges név (munkanév: Labor Egér).
2. Látvány: marad-e a kézzel rajzolt papír stílus a végleges verzióban is? (javaslat: igen, olcsó és egyedi)
3. Legyen-e „köd” (korlátozott látótér) a későbbi pályákon?
4. Bevétel: kozmetikai karakterek + hirdetésért tipp, vagy fizetős prémium?
5. Kredit / bolt: mi vehető, és mi nem (a „magadtól jössz rá” élmény ne sérüljön).

## Ötletpad (még nem eldöntött elemek)
- Kapcsoló + ajtó, időzített ajtó, csúszós jég, egyirányú forgóajtó, sötét pálya zseblámpával.
- Rejtett troll-elemek: hamis kijárat, láthatatlan fal, „biztonságos” sajt egyszer.
- Új karakterek eltérő képességgel (hörcsög: lassabb, de nem zuhan; csiga: …).

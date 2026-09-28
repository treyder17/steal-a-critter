# Steal a Critter – Roblox-Spiel

Ein Spiel im Stil von "Steal a Brainrot" und Tycoon-Spielen:

- **Laufband:** Critters laufen vorbei, du kaufst sie mit In-Game-Cash (Taste E).
- **Basis:** 8 Sockel, dazu 4 VIP-Sockel. Jeder Critter bringt jede Sekunde Cash.
- **Klauen:** Du gehst in eine fremde Basis und hältst E bei "Steal". Dann bringst du den Critter in deine eigene Basis.
- **Slap:** Wenn du einen Dieb schlägst, kommt der Critter zum Besitzer zurück.
- **Lock:** Deine Basis ist dann 60 Sekunden gesperrt, danach gibt es 30 Sekunden Cooldown. Das geht über den roten Knopf in der Basis oder den LOCK-Button.
- **Verkaufen:** Bei deinem eigenen Critter hältst du E und bekommst 50 % des Preises.
- 14 Critters in 7 Seltenheiten, von Common bis Secret. Sie werden aus Parts gebaut, du brauchst also keine Assets.
- Die Spielstände werden im DataStore gespeichert.

## Monetarisierung (Robux)

| Typ | Name | Wirkung | Preis-Vorschlag |
|---|---|---|---|
| Gamepass | 2x Cash | doppeltes Einkommen für immer | 199 R$ |
| Gamepass | VIP Base | +4 Sockel | 299 R$ |
| Gamepass | Speed Runner | schneller laufen, beim Tragen nicht langsamer | 149 R$ |
| Product | Cash Bag / Chest / Vault | 10 / 60 / 300 Minuten Einkommen (mit Mindestbetrag) | 29 / 99 / 349 R$ |
| Product | Server Luck (15 min) | mehr seltene Spawns für den **ganzen Server**, wird allen angekündigt | 149 R$ |
| Product | Instant Lock (2 min) | sperrt die Basis sofort, auch während des Cooldowns | 19 R$ |

Die Cash-Pakete wachsen mit deinem Einkommen mit. Deshalb bleiben sie auch später im Spiel interessant.
Die Kaufabwicklung (`ProcessReceipt`) zählt jeden Kauf nur einmal. Jeder Beleg wird gespeichert.
Das Spiel zeigt die Chancen im ODDS-Fenster offen an. Roblox verlangt das bei Zufallsmechaniken.

## Loslegen

1. **Roblox Studio** installieren: https://create.roblox.com
2. `StealACritter.rbxlx` doppelklicken, dann öffnet sie sich in Studio.
3. **Play** drücken. Die Map wird beim Start per Code gebaut, im Edit-Modus ist sie also leer.
4. **Klauen testen:** Test → Clients and Servers → 2 Players → Start.
5. **Kaufen testen:** Solange eine ID `0` ist, simuliert Studio Käufe kostenlos. Du kannst also alles ausprobieren.

## Veröffentlichen und Geld verdienen

1. In Studio: **File → Publish to Roblox**
2. **Game Settings → Security → Enable Studio Access to API Services** aktivieren (für das Speichern)
3. **Game Settings → Places → Max Players = 8**, weil es 8 Basen gibt
4. Auf https://create.roblox.com → dein Spiel → **Monetization**:
   - **Passes:** 3 Gamepasses anlegen (2x Cash, VIP Base, Speed Runner) und "For Sale" + Preis setzen
   - **Developer Products:** 5 Produkte anlegen
5. Die IDs trägst du in `ReplicatedStorage > Shared > Config` ein, bei `Config.GamePasses` und `Config.Products` jeweils in `Id = ...`.
   Wenn du über die Quelldateien arbeitest: `src/shared/Config.luau` bearbeiten und danach `python build.py` ausführen.
6. Erneut publishen und das Spiel auf **Public** stellen.

**Wichtig zum Auszahlen (DevEx):** Du musst mindestens 13 Jahre alt sein und ein verifiziertes Roblox-Konto haben. Außerdem brauchst du mindestens 30.000 verdiente Robux.
Roblox behält ca. 30 % jedes Kaufs ein.
Zusätzlich zahlt Roblox **Premium Payouts**, abhängig von der Spielzeit von Premium-Spielern.

## Icon und Thumbnail (Prompts für Higgsfield oder einen anderen Bildgenerator)

- **Icon (512×512):** `cartoon 3D roblox style game icon, a cute goofy toast-crocodile creature with big googly eyes being carried by a sneaky roblox character over their head, bright saturated colors, bold "STEAL A CRITTER" text, glossy, high contrast, centered`
- **Thumbnail (1920×1080):** `roblox style 3D scene, colorful bases around a glowing conveyor belt full of silly cartoon creatures, a golden legendary pizza-kraken creature with a crown glowing on the belt, players running and slapping each other, dramatic lighting, vibrant, fun chaotic energy`

## Projektstruktur

```
src/shared/   Config (Critters, Preise, Produkte), Util, CritterFactory
src/server/   Main + DataService, MapService, BaseService, ConveyorService,
              StealService, CharacterService, CombatService, IncomeService,
              MonetizationService
src/client/   Main.client (HUD, Shop, Odds, Benachrichtigungen)
build.py      baut StealACritter.rbxlx aus src/
default.project.json   für Rojo (optional)
```

## Ideen für Updates (halten Spieler länger im Spiel)

- Rebirth-System (Neustart mit einem dauerhaften Einkommens-Multiplikator)
- Tägliche Belohnungen und Gruppen-Belohnung ("Join group for +10 % cash")
- Private Server verkaufen (Game Settings → Monetization)
- Wöchentliche Events mit neuen Limited-Critters

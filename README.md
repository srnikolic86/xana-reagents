# XanaReagents

Hover over a crafting reagent and its tooltip shows which professions use it and
what it makes:

```
Reagent for Alchemy, Cooking, First Aid, Herbalism
  Minor Arcane Elixir
  Peace Tea
  Minor Healing Potion
  Incense Candle
  Elixir of Minor Spirit
  ...and 8 more
```

It lists at most five products, taking turns between the professions, and names
are colored by item quality. It works for every recipe in the game, whether or not
your character knows it.

## The full list

Bind a key under Options > Keybindings > AddOns > XanaReagents. Press it while a
reagent's tooltip is showing to open a window with every recipe that uses it, grouped
by profession. Each row shows the recipe's icon, name, reagents and the skill at which
it stops giving skill-ups.

- Scroll with the mouse wheel or the bar on the right, and drag the title to move it.
- Hover over a row for that item's normal tooltip. Pressing the key there jumps to it
  if it's a reagent too.
- Press the key again, or click X, to close the window.

`/xreagents` reports the data's game build, the number of reagents and the key.

## Updating the data

The recipes are read from the game's own files. After a game patch, run this from
the folder that contains the addons, then run `deploy.bat`:

```
python -I tools\build_reagent_data.py build
```

This rewrites `tools\recipes.json` (the readable master list) and
`XanaReagents\Data.lua` (what the game loads, since addons can't read JSON).

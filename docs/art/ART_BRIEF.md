# Art brief: Elite Mob Visuals end pieces

## What this is for

Elite Mob Visuals is a World of Warcraft addon (for WoW Forever). It marks
elite, rare and boss monsters by decorating their health bar. These health
bars are the nameplates above monsters' heads and the target frame at the top
of the screen.

We need **end pieces**: ornaments that attach to the end of a horizontal
health bar and wrap around it, so the bar looks like part of an ornate
frame. Players choose to show them on the left end, the right end or both,
and set their size.

## What we need

**Three end piece designs**, each delivered as described below. Ideas we'd
like explored (one per design, or your own):

- **Dragon:** a dragon's head biting or gripping the bar's end, with horns and
  wings. The classic WoW "elite" look.
- **Winged:** a jewel or crest on the end with a wing sweeping up and its
  mirror sweeping down.
- **Clasp:** a heavy metal clasp or bracket gripping the end, with rivets,
  spikes and a gem.

## Hard rules

These come from how the addon draws the art, so please don't bend them.

1. **Left end only.** Draw the piece for the bar's **left** end, extending
   outward to the left. The right end is made by mirroring it.
2. **Symmetrical top to bottom.** The piece must be the same above and below
   the bar's centre line, mirrored. It's fine to draw only the top half; we
   mirror it. The one exception is anything that would look wrong doubled,
   such as a single eye. Put that on its own layer (see Layers).
3. **Light from directly above**, not from the side, so the mirrored right end
   still looks right.
4. **Use the template.** `end-piece-template.svg` (and `.png`) has the guides:
   - **bar end** (the attach line): the piece sits left of it;
   - **bar top and bottom edges**, at a reference bar height of 128 px;
   - **the mirror line**;
   - **max overlap**: the piece may cover the bar by up to 32 px (a quarter
     of the bar's height), no more, so the bar stays readable;
   - **safe area**: keep everything inside it.
5. **It must read when small.** In game the bar is often only **10 to 30 px
   tall**, so the whole piece may be 30 to 60 px. Design for that: a strong,
   chunky silhouette; no lines thinner than about 4 px at template size; few
   fine details. Shrink your design to 25% and check it still reads.
6. **Original art only.** Use Blizzard's style as a reference, but don't copy
   or trace their textures.

## Style

It should look at home in WoW's own interface:

- Hand-painted metal (silver or gold), lit from above: bright tops, darker
  undersides. Painted, not photographic; no noise or grain.
- A dark outline in the metal's own darkest tone, not pure black.
- Chunky, slightly exaggerated shapes over fine filigree.
- Gems should be faceted, with a bright highlight.

**References:**

- WoW's elite target frame: the gold dragon round the portrait.
- The rare (silver) version of the same frame.
- Dragonflight's unit frame borders and boss frames.
- The small elite and rare icons on WoW nameplates.

`../reference/blizzard/` in this repo has the classic elite, rare and
rare-elite dragons for reference, kept locally because they are Blizzard's art
(download links in the repo README).

## Colour: greyscale, so the addon can tint it

The addon tints each piece per monster type: gold for elite, silver for rare,
icy blue for rare elite, red for boss. It does this by **multiplying** the
art's colours, so:

- Paint the **metal in greyscale**: highlights near white, mid-tones around
  light grey, shadows dark grey. White takes the tint fully; black stays
  black.
- Please also send one **gold-coloured version** of each design, used only
  for previews and the store page.

## Layers

Deliver each as a separate image, all the same canvas size and position:

| Layer | Contents | Colour |
| --- | --- | --- |
| `metal` | The body of the piece | Greyscale (tinted by the addon) |
| `accent` | Gems, eyes, glowing details | Greyscale or colour, your choice; say which |
| `glow` (optional) | A soft glow behind gems or eyes | White on transparent, soft edges |
| `single` (optional) | Anything that must not be mirrored, such as one eye | As above |

## Tall frames (optional, but valuable)

Target frames are 40 to 80 px tall, much taller than nameplates. A piece that
only scales up gets huge. If the design allows it, please also supply a
**three-part version** that stretches instead:

- **top cap:** the top of the piece, down to just past the bar's top edge;
- **middle:** a plain strip that can be stretched vertically without looking
  distorted (straight metal, no ornaments);
- the bottom cap is the top cap mirrored, so it isn't needed.

## Files to send

- **Preferred:** layered **SVG**, one file per design with the layers as named
  groups.
- **Or:** **PNG** at **1024 × 1024** (twice the template), one file per layer,
  transparent background.
- **Plus** one preview image per design: the piece on both ends of a dark bar
  at three sizes (16 px, 24 px and 64 px bar height), on a dark background.

Name files like `emv-end-dragon-metal.png`, `emv-end-dragon-accent.png`,
`emv-end-dragon-preview.png`.

We'll convert the files to the game's texture format (TGA), so you don't need
to.

## Process

1. Rough sketches of the three ideas, at template size, shown on the bar. We
   pick and give notes.
2. Finished art, as above.

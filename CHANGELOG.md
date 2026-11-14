# Changelog

## 0.1.0 (unreleased)

First version, for WoW Forever (Interface 16001).

- Target badge beside elite, rare, rare elite and boss nameplates: 13 styles,
  9 positions, mirrored pairs, size, offsets, opacity, tint, glow and
  animations.
- Overhead marker above marked mobs, with an optional text label.
- Four visuals, each set up on its own: a badge and a marker on the
  nameplate, and a badge and a marker on the target frame (EllesmereUI's or
  Blizzard's, also ElvUI and Shadowed Unit Frames, or a free, draggable
  position).
- Visibility page: tick each visual, choose which nameplates the nameplate
  ones show on, and let each target frame one step in when its nameplate
  counterpart isn't showing (nameplates off, out of range, or turned off).
- Style per classification for each visual; the target frame visuals follow
  their nameplate counterpart unless set.
- Options window with a sidebar, and a preview of what the selected page
  edits.
- Animations move the art only; a background stays still behind it.
- Test mode shows the badge on every nameplate, whatever "Show on" says, and
  says when there is nothing it can show. `/emv debug` prints what the addon
  sees on each plate and on the target frame.
- Per-classification on/off and colour.
- Backgrounds: a rectangle behind each visual's art, with its own width,
  height, offset, colour, opacity and optional border, which can take the
  classification colour.
- Hides EllesmereUI's own Rare/Elite icon on mobs this addon marks (option,
  on by default), so the Blizzard icon style isn't shown twice.
- Blizzard styles are drawn by atlas name, at the badge's size and position.
- Filters: only mobs you can attack, only in combat, hidden on dead mobs.
- Options window with a live preview and test mode (`/emv test`).
- Settings page in the game's Settings (AddOns) with the everyday switches
  (`/emv settings`).
- Works with EllesmereUI Nameplates: the visuals ride its own plates. They
  sit beside its health bar and above its name, scale and fade with its
  plates, and draw over its auras.
- Visuals attach to the health bar and name by default, instead of
  Blizzard's nameplate frame (the click box).
- Two logos: the full one with wings (options, Settings page, CurseForge),
  and a compact, padded icon without them (minimap button, addon list,
  compartment), which minimap button bags no longer crop.
- Minimap button that button bags and drawers can collect
  (`LibDBIcon10_EliteMobVisuals`), also published to LibDataBroker for broker
  displays when one is installed. `/emv minimap` shows or hides it.

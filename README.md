# ReaKeys

**ReaKeys** is a lightweight, scale-locked typing keyboard for **REAPER**.  
It lets you play MIDI notes using your computer keyboard, snapped to a chosen musical scale, with octave control, velocity, optional portamento (if supported), and a visual piano reference.

The primary goal of this project was to create a keyboard for people who aren't music theory boffins, but still want to create coherent melodies/hooks easily. Think of it as bumper bowling for the piano.

![ReaKeys in action](https://raw.githubusercontent.com/protbox/ReaKeys/refs/heads/main/Screenshot.png "ReakKeys")
---

## Features

- FL-style typing keyboard layout  
- Scale locking (major, modes, exotic scales, etc.)
- Root note selection
- Octave control
- Velocity slider (default: 90)
- Optional portamento *(if supported by the instrument)*
- Transport shortcuts:
  - **Ctrl + Enter** to Record
  - **Ctrl + Space** to Play / Stop
- Visual 3-octave piano (read-only learning aid)

---

## Requirements

- **REAPER** (duh!)
- **ReaPack**
- **ReaImGui**

---

## Installation

### 1. Install ReaPack
If you don’t already have it: https://reapack.com/

### 2. Install ReaImGui
In REAPER:
1. Open **Extensions → ReaPack → Browse Packages**
2. Search for **ReaImGui**
3. Install the latest version

### 3. Install ReaKeys
1. Download [reakeys.lua](https://raw.githubusercontent.com/protbox/ReaKeys/refs/heads/main/reakeys.lua)
2. In REAPER, go to Options -> Show REAPER resource path in explorer/finder
3. Drop reakeys.lua into the Scripts folder

You're basically done at that point, but to make life easier I like to bind it to a key, ie: ctrl+k
If you'd like to do this, go to Actions -> Show Action List then click "New action" -> Load ReaScript
This will add it into your action list. From there you can treat it as you would any other action and assign it to a key.

## Usage

1. Arm a track with a virtual instrument
2. Right-Click Arm button -> Input: MIDI -> All MIDI Inputs
3. Run **ReaKeys** from the Action List (or bind it to a shortcut as described above)
4. Click the ReaKeys window to focus it
5. Play notes using your typing keyboard
6. Change:
- **Root**
- **Scale**
- **Octave**
- **Velocity**
7. (Optional) Enable **Portamento**  
> Works only on instruments that support MIDI mono/legato portamento

For an easier workflow, you can automate step 1 and 2 by doing it once and creating a track template.

### Transport Shortcuts

I've added a couple of keybinds to ReaKeys so you don't need to leave the window to record or playback

- **Ctrl + Enter** → Record
- **Ctrl + Space** → Play / Stop

---

## Notes on Portamento

Portamento is implemented using standard MIDI CC messages (Mono Mode, Legato, Portamento On, Portamento Time).  
Not all instruments respond to these messages.

If portamento does nothing:
- Enable mono / legato inside the instrument itself

---

## License

WTFPL

```
Copyright © 2026 brad h <brad@sadhat.org>
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar.
```
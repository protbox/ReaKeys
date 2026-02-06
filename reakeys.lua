-- @description ReaKeys
-- @version 0.1
-- @author poltergasm
-- @about Virtual keyboard with scale lock, configurable root key/octave, portamento and velocity controls.

-- Requirements: ReaPack + ReaImgGui

local ctx = reaper.ImGui_CreateContext('ReaKeys')

local NOTE_NAMES = { 'C','C#','D','D#','E','F','F#','G','G#','A','A#','B' }

local SCALES = {
    Ionian        = {2,2,1,2,2,2,1},
    Dorian        = {2,1,2,2,2,1,2},
    Phrygian      = {1,2,2,2,1,2,2},
    Lydian        = {2,2,2,1,2,2,1},
    Mixolydian    = {2,2,1,2,2,1,2},
    Aeolian       = {2,1,2,2,1,2,2},
    Locrian       = {1,2,2,1,2,2,2},
    HarmonicMinor = {2,1,2,2,1,3,1},
    MelodicMinor  = {2,1,2,2,2,2,1},
    PhrygianDom   = {1,3,1,2,1,2,2},
    MinorBlues    = {3,2,1,1,3,2},
    Chinese       = {4,2,1,4,1},
    Romanian      = {2,1,3,1,2,1,2},
    MajorBeBop    = {2,2,1,2,1,1,2,1},
    MinorBebop    = {2,1,1,1,2,2,1,2},
    Mystic        = {2,2,2,2,1,2,1}, -- discovered this one on a handpan!
}

local KEYBOARD_LAYOUT = {
    'z','x','c','v','b','n','m',',','.','/',
    'a','s','d','f','g','h','j','k','l',';',"'",'#',
    'q','w','e','r','t','y','u','i','o','p','[',']',
    '1','2','3','4','5','6','7','8','9','0','-','='
}

-- map layout chars to ImGui key enums
local KEY_ENUM = {
    a = reaper.ImGui_Key_A(), b = reaper.ImGui_Key_B(), c = reaper.ImGui_Key_C(), d = reaper.ImGui_Key_D(),
    e = reaper.ImGui_Key_E(), f = reaper.ImGui_Key_F(), g = reaper.ImGui_Key_G(), h = reaper.ImGui_Key_H(),
    i = reaper.ImGui_Key_I(), j = reaper.ImGui_Key_J(), k = reaper.ImGui_Key_K(), l = reaper.ImGui_Key_L(),
    m = reaper.ImGui_Key_M(), n = reaper.ImGui_Key_N(), o = reaper.ImGui_Key_O(), p = reaper.ImGui_Key_P(),
    q = reaper.ImGui_Key_Q(), r = reaper.ImGui_Key_R(), s = reaper.ImGui_Key_S(), t = reaper.ImGui_Key_T(),
    u = reaper.ImGui_Key_U(), v = reaper.ImGui_Key_V(), w = reaper.ImGui_Key_W(), x = reaper.ImGui_Key_X(),
    y = reaper.ImGui_Key_Y(), z = reaper.ImGui_Key_Z(),

    ['1'] = reaper.ImGui_Key_1(), ['2'] = reaper.ImGui_Key_2(), ['3'] = reaper.ImGui_Key_3(), ['4'] = reaper.ImGui_Key_4(),
    ['5'] = reaper.ImGui_Key_5(), ['6'] = reaper.ImGui_Key_6(), ['7'] = reaper.ImGui_Key_7(), ['8'] = reaper.ImGui_Key_8(),
    ['9'] = reaper.ImGui_Key_9(), ['0'] = reaper.ImGui_Key_0(),

    [','] = reaper.ImGui_Key_Comma(),
    ['.'] = reaper.ImGui_Key_Period(),
    ['/'] = reaper.ImGui_Key_Slash(),
    [';'] = reaper.ImGui_Key_Semicolon(),
    ["'"] = reaper.ImGui_Key_Apostrophe(),
    ['['] = reaper.ImGui_Key_LeftBracket(),
    [']'] = reaper.ImGui_Key_RightBracket(),
    ['-'] = reaper.ImGui_Key_Minus(),
    ['='] = reaper.ImGui_Key_Equal()

    -- for the life of me I could NOT get this to work
    -- maybe it never will. My disappointment is immeasurable and my day is ruined
    --['#'] = reaper.ImGui_Key_?????????
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function midi_to_name(midi)
    local pc = midi % 12
    local octave = math.floor(midi / 12) - 1
    return NOTE_NAMES[pc + 1] .. tostring(octave)
end

-- state
local root_pc = 0                 -- 0 = C
local octave = 3                  -- default octave (3)
local scale_names = {}
for k in pairs(SCALES) do
    table.insert(scale_names, k)
end
table.sort(scale_names)
local scale_idx = 1               -- index into scale_names
local last_note_str = '—'

local key_map = {}                -- char to midi note
local held = {}                   -- char to midi note (currently on)
local velocity = 90
local midi_chan = 0               -- 0..15

local porta_enabled = false
local porta_time = 2

local function send_cc(cc, value)
    local status = 0xB0 + (midi_chan & 0x0F)
    reaper.StuffMIDIMessage(0, status, cc & 0x7F, value & 0x7F)
end

local function set_mono_mode(enabled)
    if enabled then
        send_cc(126, 1)  -- mono mode ON (1 channel)
    else
        send_cc(127, 0)  -- poly mode ON
    end
end

local function update_portamento()
    if porta_enabled then
        send_cc(126, 1)   -- mono mode ON
        send_cc(68, 127)  -- legato ON
        send_cc(65, 127)  -- portamento ON
        send_cc(5, porta_time)
    else
        send_cc(65, 0)    -- portamento OFF
        send_cc(68, 0)    -- legato OFF
        send_cc(127, 0)   -- poly mode ON
    end
end

local function is_midi_active_in_range(midi, base_c, octaves)
    local top_c = base_c + (octaves - 1) * 12

    for _, held_midi in pairs(held) do
        local m = held_midi

        -- clamp high notes into the top octave
        if m > top_c + 11 then
            m = top_c + (m % 12)
        end

        if m == midi then
            return true
        end
    end

    return false
end

local function toggle_play_stop()
    reaper.Main_OnCommand(40044, 0)
end

local function toggle_record()
    reaper.Main_OnCommand(1013, 0)
end

local function root_midi_base()
    return (octave + 1) * 12 + root_pc
end

local function build_key_map()
    key_map = {}

    local r = root_midi_base()
    local pattern = SCALES[scale_names[scale_idx]]
    local note = r
    local scale_ct = 1

    for idx, key in ipairs(KEYBOARD_LAYOUT) do
        if key == 'a' then
            note = r + 12
            scale_ct = 1
        elseif key == 'q' then
            note = r + 24
            scale_ct = 1
        elseif key == '1' then
            note = r + 36
            scale_ct = 1
        elseif idx ~= 1 then
            note = note + pattern[scale_ct]
            scale_ct = (scale_ct % #pattern) + 1
        end

        key_map[key] = note
    end
end

local function note_on(midi_note)
    local status = 0x90 + (midi_chan & 0x0F)
    reaper.StuffMIDIMessage(0, status, midi_note & 0x7F, velocity & 0x7F)
end

local function note_off(midi_note)
    local status = 0x80 + (midi_chan & 0x0F)
    reaper.StuffMIDIMessage(0, status, midi_note & 0x7F, 0)
end

local function all_notes_off()
    for _, midi_note in pairs(held) do
        note_off(midi_note)
    end
    held = {}
end

build_key_map()

local function draw_piano(ctx, base_c)
    local white_w = 22
    local white_h = 80
    local black_w = 14
    local black_h = 48
    local spacing = 1
    local octaves = 3

    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local x0, y0 = reaper.ImGui_GetCursorScreenPos(ctx)

    local white_steps = { 0, 2, 4, 5, 7, 9, 11 }

    -- draw white keys
    local white_index = 0
    for oct = 0, octaves - 1 do
        for _, step in ipairs(white_steps) do
            local midi = base_c + oct * 12 + step
            local active = is_midi_active_in_range(midi, base_c, octaves)

            local x = x0 + white_index * (white_w + spacing)
            local y = y0

            local col = active
                and reaper.ImGui_ColorConvertDouble4ToU32(0.9, 0.7, 0.3, 1.0)
                or  reaper.ImGui_ColorConvertDouble4ToU32(0.92, 0.92, 0.92, 1.0)

            reaper.ImGui_DrawList_AddRectFilled(
                draw_list,
                x, y,
                x + white_w, y + white_h,
                col
            )

            reaper.ImGui_DrawList_AddRect(
                draw_list,
                x, y,
                x + white_w, y + white_h,
                reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1.0)
            )

            white_index = white_index + 1
        end
    end

    -- black keys (relative to white indices)
    local black_map = {
        [1]  = 1, -- C#
        [3]  = 2, -- D#
        [6]  = 4, -- F#
        [8]  = 5, -- G#
        [10] = 6  -- A#
    }

    for oct = 0, octaves - 1 do
        for step, w_index in pairs(black_map) do
            local midi = base_c + oct * 12 + step
            local active = is_midi_active_in_range(midi, base_c, octaves)

            local x = x0
                + (oct * 7 + w_index) * (white_w + spacing)
                - black_w / 2
            local y = y0

            local col = active
                and reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.3, 0.3, 1.0)
                or  reaper.ImGui_ColorConvertDouble4ToU32(0.1, 0.1, 0.1, 1.0)

            reaper.ImGui_DrawList_AddRectFilled(
                draw_list,
                x, y,
                x + black_w, y + black_h,
                col
            )
        end
    end
end

local function poll_keys_when_focused()
    -- ctrl+space = play / stop
    -- ctrl+enter = record
    do
        local mods = reaper.ImGui_GetKeyMods(ctx)
        local ctrl = (mods & reaper.ImGui_Mod_Ctrl()) ~= 0

        if ctrl then
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space(), false) then
                toggle_play_stop()
                return
            end

            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) then
                toggle_record()
                return
            end
        end
    end

    for _, ch in ipairs(KEYBOARD_LAYOUT) do
        local k = KEY_ENUM[ch]
        local midi_note = key_map[ch]

        if k and midi_note then
            if reaper.ImGui_IsKeyPressed(ctx, k, false) then
                if not held[ch] then
                    held[ch] = midi_note
                    note_on(midi_note)
                    last_note_str = midi_to_name(midi_note)
                end
            end

            if reaper.ImGui_IsKeyReleased(ctx, k) then
                if held[ch] then
                    note_off(held[ch])
                    held[ch] = nil
                end
            end
        end
    end
end

local function main()
    reaper.ImGui_SetNextWindowSize(ctx, 480, 360, reaper.ImGui_Cond_FirstUseEver())

    local flags =
        reaper.ImGui_WindowFlags_NoNav()
      | reaper.ImGui_WindowFlags_NoNavInputs()

    local visible, open = reaper.ImGui_Begin(ctx, 'ReaKeys', true, flags)

    if visible then
        local focused = reaper.ImGui_IsWindowFocused(
            ctx,
            reaper.ImGui_FocusedFlags_RootAndChildWindows()
        )

        reaper.ImGui_Text(ctx, 'Focused: ' .. (focused and 'YES' or 'NOPE'))

        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_TextDisabled(ctx, '(shortcuts)')
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_Text(ctx, 'Ctrl+Enter = Record')
            reaper.ImGui_Text(ctx, 'Ctrl+Space = Play / Stop')
            reaper.ImGui_EndTooltip(ctx)
        end
        reaper.ImGui_Separator(ctx)

        -- root selector
        local root_names = table.concat(NOTE_NAMES, '\0') .. '\0'
        local changed_root, new_root = reaper.ImGui_Combo(ctx, 'Root', root_pc, root_names)
        if changed_root then
            root_pc = new_root
            build_key_map()
        end

        -- scale selector
        local scale_combo = table.concat(scale_names, '\0') .. '\0'
        local changed_scale, new_scale_idx = reaper.ImGui_Combo(ctx, 'Scale', scale_idx - 1, scale_combo)
        if changed_scale then
            scale_idx = new_scale_idx + 1
            build_key_map()
        end

        -- velocity control
        local changed_vel
        changed_vel, velocity = reaper.ImGui_SliderInt(
            ctx,
            'Velocity',
            velocity,
            1,
            127
        )

        -- portamento toggle
        -- only works on supported instruments (tested using fluidsynth)
        if reaper.ImGui_Checkbox(ctx, 'Portamento (if supported)', porta_enabled) then
            porta_enabled = not porta_enabled
            update_portamento()
        end

        local changed_port_time
        changed_port_time, porta_time = reaper.ImGui_SliderInt(
            ctx,
            'Porta Time',
            porta_time,
            0,
            12
        )

        -- octave controls
        local changed_oct = false
        if reaper.ImGui_Button(ctx, 'Oct -') then
            octave = clamp(octave - 1, -1, 8)
            changed_oct = true
        end
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, 'Octave: ' .. tostring(octave))
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Oct +') then
            octave = clamp(octave + 1, -1, 8)
            changed_oct = true
        end

        if changed_oct then
            all_notes_off()
            build_key_map()
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, 'Last note: ' .. last_note_str)

        if focused then
            poll_keys_when_focused()
        end

        reaper.ImGui_Separator(ctx)
        -- draw the piano visual reference
        -- TODO: maybe add a toggle in case you don't want/need it?
        reaper.ImGui_Text(ctx, 'Piano (visual reference)')
        local base_c = (octave + 1) * 12
        draw_piano(ctx, base_c)

        reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(main)
    else
        all_notes_off()
        -- I don't think DestroyContext is exposed in ReaImGui, or at least
        -- the version I'm using
        -- but I feel weird not destroying contexts so let's do it safely
        if reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(ctx)
        end
    end
end

main()

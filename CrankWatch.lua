_addon.name = 'CrankWatch'
_addon.author = 'VelnerXI'
--twitch.tv/VelnerXI -- Live starting 5:30 pm PT most days!
_addon.version = '1.0.0'
_addon.commands = {'crankwatch', 'cw'}

local texts = require('texts')
local config = require('config')

local defaults = {
    center_x = 900,
    center_y = 450,
    ws_size = 36,
    dmg_size = 42,
    avg_size = 24,
    flair_size = 30,
    line_gap = 44,
    avg_gap = 86,
    flair_gap = 118,
    font = 'Highwind',
    stroke_width = 4,
    big_stroke_width = 5,
    pending_timeout = 1.25,
    flair_duration = 0.85,
    fade_enabled = true,
    fade_in_duration = 0.30,
    hold_duration = 60.0,
    fade_out_duration = 8.0,
    pop_enabled = true,
    pop_duration = 0.35,
    pop_bonus_size = 8,
    gradient_enabled = false,
    flair_fade_duration = 0.85,
    flair_shrink_size = 0,
    flair_float_distance = 32,
    flair_anchor_ratio = 0.72,
    sc_anchor_ratio = 0.50,
    flair_offset_y = 12,
    whiff_shake_duration = 0.45,
    whiff_shake_strength = 6,
    sc_enabled = true,
    sc_window = 4.0,
    sc_fade_duration = 4.50,
    sc_float_distance = 32,
    sc_gap = 118,
    sc_size = 30,
    sc_offset_y = 32,
}

local settings = config.load(defaults)

local last_ws = '-'
local last_dmg = '-'
local last_raw_dmg = 0
local total_ws_damage = 0
local total_ws_count = 0
local avg_dmg = '-'
local pending_ws = nil
local pending_time = 0
local debug_mode = false
local dragging_anchor = false
local flair_expire = 0
local flair_visible = false
local flair_fading = false
local flair_fade_start = 0
local flair_base_size = 0
local flair_fade_start_alpha = 255
local flair_start_y = 0

local alpha_current = 0
local fade_state = 'hidden'
local fade_start = 0
local last_ws_time = 0
local is_whiff = false
local whiff_shaking = false
local whiff_shake_start = 0
local pop_active = false
local pop_start = 0
local pop_base_size = 0
local highlight_visible = false
local layout_refresh_until = 0
local cranked_streak = 0
local cranked_flair_text = 'CRANKED!!!'
local sc_window_until = 0
local sc_armed = false
local sc_visible = false
local sc_fading = false
local sc_fade_start = 0
local sc_fade_start_alpha = 255
local sc_start_y = 0
local sc_bonus_dmg = 0

-- Whitelist of player/automaton weapon skills from BG-Wiki's Weapon Skills category.
-- This prevents job abilities, items, rolls, waltzes, jumps, etc. from being treated as a pending WS.
local weapon_skills = {
    ['Combo'] = true,
    ['Shoulder Tackle'] = true,
    ['One Inch Punch'] = true,
    ['Backhand Blow'] = true,
    ['Raging Fists'] = true,
    ['Spinning Attack'] = true,
    ['Howling Fist'] = true,
    ['Dragon Kick'] = true,
    ['Asuran Fists'] = true,
    ['Tornado Kick'] = true,
    ['Shijin Spiral'] = true,
    ['Final Heaven'] = true,
    ['Victory Smite'] = true,
    ['Ascetic\'s Fury'] = true,
    ['Stringing Pummel'] = true,
    ['Maru Kala'] = true,
    ['Wasp Sting'] = true,
    ['Gust Slash'] = true,
    ['Shadowstitch'] = true,
    ['Viper Bite'] = true,
    ['Cyclone'] = true,
    ['Energy Steal'] = true,
    ['Energy Drain'] = true,
    ['Dancing Edge'] = true,
    ['Shark Bite'] = true,
    ['Evisceration'] = true,
    ['Aeolian Edge'] = true,
    ['Exenterator'] = true,
    ['Mercy Stroke'] = true,
    ['Rudra\'s Storm'] = true,
    ['Mandalic Stab'] = true,
    ['Mordant Rime'] = true,
    ['Pyrrhic Kleos'] = true,
    ['Ruthless Stroke'] = true,
    ['Fast Blade'] = true,
    ['Burning Blade'] = true,
    ['Red Lotus Blade'] = true,
    ['Flat Blade'] = true,
    ['Shining Blade'] = true,
    ['Seraph Blade'] = true,
    ['Circle Blade'] = true,
    ['Spirits Within'] = true,
    ['Vorpal Blade'] = true,
    ['Swift Blade'] = true,
    ['Savage Blade'] = true,
    ['Sanguine Blade'] = true,
    ['Requiescat'] = true,
    ['Knights of Round'] = true,
    ['Chant du Cygne'] = true,
    ['Death Blossom'] = true,
    ['Atonement'] = true,
    ['Expiacion'] = true,
    ['Imperator'] = true,
    ['Hard Slash'] = true,
    ['Power Slash'] = true,
    ['Frostbite'] = true,
    ['Freezebite'] = true,
    ['Shockwave'] = true,
    ['Crescent Moon'] = true,
    ['Sickle Moon'] = true,
    ['Spinning Slash'] = true,
    ['Ground Strike'] = true,
    ['Herculean Slash'] = true,
    ['Resolution'] = true,
    ['Scourge'] = true,
    ['Torcleaver'] = true,
    ['Dimidiation'] = true,
    ['Fimbulvetr'] = true,
    ['Raging Axe'] = true,
    ['Smash Axe'] = true,
    ['Gale Axe'] = true,
    ['Avalanche Axe'] = true,
    ['Spinning Axe'] = true,
    ['Rampage'] = true,
    ['Calamity'] = true,
    ['Mistral Axe'] = true,
    ['Decimation'] = true,
    ['Bora Axe'] = true,
    ['Ruinator'] = true,
    ['Onslaught'] = true,
    ['Cloudsplitter'] = true,
    ['Primal Rend'] = true,
    ['Blitz'] = true,
    ['Shield Break'] = true,
    ['Iron Tempest'] = true,
    ['Sturmwind'] = true,
    ['Armor Break'] = true,
    ['Keen Edge'] = true,
    ['Weapon Break'] = true,
    ['Raging Rush'] = true,
    ['Full Break'] = true,
    ['Steel Cyclone'] = true,
    ['Fell Cleave'] = true,
    ['Upheaval'] = true,
    ['Metatron Torment'] = true,
    ['Ukko\'s Fury'] = true,
    ['King\'s Justice'] = true,
    ['Disaster'] = true,
    ['Slice'] = true,
    ['Dark Harvest'] = true,
    ['Shadow of Death'] = true,
    ['Nightmare Scythe'] = true,
    ['Spinning Scythe'] = true,
    ['Vorpal Scythe'] = true,
    ['Guillotine'] = true,
    ['Cross Reaper'] = true,
    ['Spiral Hell'] = true,
    ['Infernal Scythe'] = true,
    ['Entropy'] = true,
    ['Catastrophe'] = true,
    ['Quietus'] = true,
    ['Insurgency'] = true,
    ['Origin'] = true,
    ['Double Thrust'] = true,
    ['Thunder Thrust'] = true,
    ['Raiden Thrust'] = true,
    ['Leg Sweep'] = true,
    ['Penta Thrust'] = true,
    ['Vorpal Thrust'] = true,
    ['Skewer'] = true,
    ['Wheeling Thrust'] = true,
    ['Impulse Drive'] = true,
    ['Sonic Thrust'] = true,
    ['Stardiver'] = true,
    ['Geirskogul'] = true,
    ['Camlann\'s Torment'] = true,
    ['Drakesbane'] = true,
    ['Diarmuid'] = true,
    ['Blade: Rin'] = true,
    ['Blade: Retsu'] = true,
    ['Blade: Teki'] = true,
    ['Blade: To'] = true,
    ['Blade: Chi'] = true,
    ['Blade: Ei'] = true,
    ['Blade: Jin'] = true,
    ['Blade: Ten'] = true,
    ['Blade: Ku'] = true,
    ['Blade: Yu'] = true,
    ['Blade: Shun'] = true,
    ['Blade: Metsu'] = true,
    ['Blade: Hi'] = true,
    ['Blade: Kamu'] = true,
    ['Zesho Meppo'] = true,
    ['Tachi: Enpi'] = true,
    ['Tachi: Hobaku'] = true,
    ['Tachi: Goten'] = true,
    ['Tachi: Kagero'] = true,
    ['Tachi: Jinpu'] = true,
    ['Tachi: Koki'] = true,
    ['Tachi: Yukikaze'] = true,
    ['Tachi: Gekko'] = true,
    ['Tachi: Kasha'] = true,
    ['Tachi: Ageha'] = true,
    ['Tachi: Shoha'] = true,
    ['Tachi: Kaiten'] = true,
    ['Tachi: Fudo'] = true,
    ['Tachi: Rana'] = true,
    ['Tachi: Mumei'] = true,
    ['Shining Strike'] = true,
    ['Seraph Strike'] = true,
    ['Brainshaker'] = true,
    ['Starlight'] = true,
    ['Moonlight'] = true,
    ['Skullbreaker'] = true,
    ['True Strike'] = true,
    ['Judgment'] = true,
    ['Hexa Strike'] = true,
    ['Black Halo'] = true,
    ['Flash Nova'] = true,
    ['Realmrazer'] = true,
    ['Randgrith'] = true,
    ['Dagan'] = true,
    ['Mystic Boon'] = true,
    ['Exudation'] = true,
    ['Dagda'] = true,
    ['Heavy Swing'] = true,
    ['Rock Crusher'] = true,
    ['Earth Crusher'] = true,
    ['Starburst'] = true,
    ['Sunburst'] = true,
    ['Shell Crusher'] = true,
    ['Full Swing'] = true,
    ['Spirit Taker'] = true,
    ['Retribution'] = true,
    ['Cataclysm'] = true,
    ['Shattersoul'] = true,
    ['Gate of Tartarus'] = true,
    ['Myrkr'] = true,
    ['Vidohunir'] = true,
    ['Garland of Bliss'] = true,
    ['Omniscience'] = true,
    ['Oshala'] = true,
    ['Flaming Arrow'] = true,
    ['Piercing Arrow'] = true,
    ['Dulling Arrow'] = true,
    ['Sidewinder'] = true,
    ['Blast Arrow'] = true,
    ['Arching Arrow'] = true,
    ['Empyreal Arrow'] = true,
    ['Refulgent Arrow'] = true,
    ['Apex Arrow'] = true,
    ['Namas Arrow'] = true,
    ['Jishnu\'s Radiance'] = true,
    ['Sarv'] = true,
    ['Hot Shot'] = true,
    ['Split Shot'] = true,
    ['Sniper Shot'] = true,
    ['Slug Shot'] = true,
    ['Blast Shot'] = true,
    ['Heavy Shot'] = true,
    ['Detonator'] = true,
    ['Numbing Shot'] = true,
    ['Last Stand'] = true,
    ['Coronach'] = true,
    ['Wildfire'] = true,
    ['Trueflight'] = true,
    ['Leaden Salute'] = true,
    ['Terminus'] = true,
    ['Slapstick'] = true,
    ['String Clipper'] = true,
    ['Chimera Ripper'] = true,
    ['Knockout'] = true,
    ['Cannibal Blade'] = true,
    ['Magic Mortar'] = true,
    ['Bone Crusher'] = true,
    ['String Shredder'] = true,
    ['Arcuballista'] = true,
    ['Daze'] = true,
    ['Armor Piercer'] = true,
    ['Armor Shatterer'] = true,
}

local function is_weapon_skill(name)
    return name and weapon_skills[name] == true
end

-- These are common job abilities that use the same chat wording as weapon skills:
-- "Player uses Ability."
-- Ignoring them prevents the next melee damage line from being paired as a fake WS.
-- Comprehensive non-WS ignore list.
-- Anything listed here uses the same chat shape as a WS:
-- "Player uses Ability."
-- Keeping these out prevents abilities, stances, rolls, waltzes, runes,
-- steps, flourishes, pet commands, and SP abilities from being paired
-- with the next damage line as a fake weapon skill.
local ignored_abilities = {
    ['Accession'] = true,
    ['Activate'] = true,
    ['Addendum: Black'] = true,
    ['Addendum: White'] = true,
    ['Aggressor'] = true,
    ['Alacrity'] = true,
    ["Allies' Roll"] = true,
    ['Ancient Circle'] = true,
    ['Animated Flourish'] = true,
	['Angon'] = true,
    ['Arcane Circle'] = true,
    ['Aspir Samba'] = true,
    ['Aspir Samba II'] = true,
    ["Assassin's Charge"] = true,
    ['Astral Conduit'] = true,
    ['Astral Flow'] = true,
    ['Asylum'] = true,
    ['Aura Steal'] = true,
    ["Avenger's Roll"] = true,
    ['Azure Lore'] = true,
    ['Barrage'] = true,
	['Battuta'] = true,
    ['Beast Roll'] = true,
    ['Benediction'] = true,
    ['Berserk'] = true,
    ['Blade Bash'] = true,
    ['Blaze of Glory'] = true,
    ["Blitzer's Roll"] = true,
    ['Blood Rage'] = true,
    ['Blood Weapon'] = true,
    ["Bolter's Roll"] = true,
    ['Boost'] = true,
    ['Bounty Shot'] = true,
    ['Box Step'] = true,
    ['Brazen Rush'] = true,
    ['Building Flourish'] = true,
    ['Call Beast'] = true,
    ['Camouflage'] = true,
    ["Caster's Roll"] = true,
    ['Celerity'] = true,
    ['Chain Affinity'] = true,
    ['Chainspell'] = true,
    ['Chakra'] = true,
    ['Chaos Roll'] = true,
    ['Charm'] = true,
    ['Chi Blast'] = true,
    ['Chivalry'] = true,
    ['Choral Roll'] = true,
    ['Clarion Call'] = true,
    ['Climactic Flourish'] = true,
    ['Collaborator'] = true,
    ["Companion's Roll"] = true,
    ['Composure'] = true,
    ['Concentric Pulse'] = true,
    ['Conspirator'] = true,
    ['Consume Mana'] = true,
    ['Convert'] = true,
    ['Cooldown'] = true,
    ["Corsair's Roll"] = true,
    ['Counterstance'] = true,
    ["Courser's Roll"] = true,
    ['Cover'] = true,
    ['Crooked Cards'] = true,
    ['Curing Waltz'] = true,
    ['Curing Waltz II'] = true,
    ['Curing Waltz III'] = true,
    ['Curing Waltz IV'] = true,
    ['Curing Waltz V'] = true,
    ['Cutting Cards'] = true,
    ["Dancer's Roll"] = true,
    ['Dark Arts'] = true,
    ['Dark Maneuver'] = true,
    ['Dark Seal'] = true,
    ['Dark Shot'] = true,
    ['Deactivate'] = true,
    ['Decoy Shot'] = true,
    ['Defender'] = true,
    ['Dematerialize'] = true,
    ['Deploy'] = true,
    ['Desperate Blows'] = true,
    ['Desperate Flourish'] = true,
    ['Despoil'] = true,
    ['Deus Ex Automata'] = true,
    ['Diabolic Eye'] = true,
    ['Divine Emblem'] = true,
    ['Divine Seal'] = true,
    ['Divine Waltz'] = true,
    ['Divine Waltz II'] = true,
    ['Dodge'] = true,
    ['Double Shot'] = true,
    ['Double-Up'] = true,
    ['Drachen Roll'] = true,
    ['Drain Samba'] = true,
    ['Drain Samba II'] = true,
    ['Drain Samba III'] = true,
    ['Eagle Eye Shot'] = true,
    ['Earth Maneuver'] = true,
    ['Earth Shot'] = true,
    ['Ebullience'] = true,
    ['Ecliptic Attrition'] = true,
    ['Efflux'] = true,
    ['Elemental Seal'] = true,
    ['Elemental Sforzo'] = true,
    ['Elemental Siphon'] = true,
    ['Embolden'] = true,
    ['Enlightenment'] = true,
    ['Enmity Douse'] = true,
    ['Entrust'] = true,
    ["Evoker's Roll"] = true,
    ['Familiar'] = true,
    ['Fealty'] = true,
    ['Feather Step'] = true,
    ['Feral Howl'] = true,
    ['Fight'] = true,
    ["Fighter's Roll"] = true,
    ['Fire Maneuver'] = true,
    ['Fire Shot'] = true,
    ['Flabra'] = true,
    ['Flashy Shot'] = true,
    ['Flee'] = true,
    ['Focus'] = true,
    ['Fold'] = true,
    ['Footwork'] = true,
    ['Formless Strikes'] = true,
    ['Full Circle'] = true,
    ['Futae'] = true,
    ["Gallant's Roll"] = true,
    ['Gambit'] = true,
    ['Gauge'] = true,
    ['Gelus'] = true,
    ['Grand Pas'] = true,
    ['Hagakure'] = true,
    ['Hamanoha'] = true,
    ['Hasso'] = true,
    ['Haste Samba'] = true,
    ['Heady Artifice'] = true,
    ["Healer's Roll"] = true,
    ['Healing Waltz'] = true,
    ['Heel'] = true,
    ['Hide'] = true,
    ['High Jump'] = true,
    ['Holy Circle'] = true,
    ['Hover Shot'] = true,
    ['Hundred Fists'] = true,
    ["Hunter's Roll"] = true,
    ['Ice Maneuver'] = true,
    ['Ice Shot'] = true,
    ['Ignis'] = true,
    ['Immanence'] = true,
    ['Impetus'] = true,
    ['Inner Strength'] = true,
    ['Innin'] = true,
    ['Intervene'] = true,
    ['Invincible'] = true,
    ['Issekigan'] = true,
    ['Jump'] = true,
    ['Killer Instinct'] = true,
    ['Konzen-ittai'] = true,
    ['Larceny'] = true,
    ['Last Resort'] = true,
    ['Lasting Emanation'] = true,
    ['Leave'] = true,
    ['Liement'] = true,
    ['Life Cycle'] = true,
    ['Light Arts'] = true,
    ['Light Maneuver'] = true,
    ['Light Shot'] = true,
    ['Lunge'] = true,
    ['Lux'] = true,
    ["Magus's Roll"] = true,
    ['Maintenance'] = true,
    ['Mana Cede'] = true,
    ['Mana Wall'] = true,
    ['Manafont'] = true,
    ['Manawell'] = true,
    ['Manifestation'] = true,
    ['Mantra'] = true,
    ['Marcato'] = true,
    ['Martyr'] = true,
    ['Meditate'] = true,
    ['Mending Halation'] = true,
    ['Mighty Strikes'] = true,
    ['Mijin Gakure'] = true,
    ['Mikage'] = true,
    ["Miser's Roll"] = true,
    ["Monk's Roll"] = true,
    ['Mug'] = true,
    ["Naturalist's Roll"] = true,
    ['Nether Void'] = true,
    ['Nightingale'] = true,
    ['Ninja Roll'] = true,
    ['No Foot Rise'] = true,
    ['Odyllic Subterfuge'] = true,
	['One of All'] = true,['Odyllic Subterfuge'] = true,
    ['One For All'] = true,
    ['Overdrive'] = true,
    ['Overkill'] = true,
    ['Palisade'] = true,
    ['Parsimony'] = true,
    ['Penury'] = true,
    ['Perfect Counter'] = true,
    ['Perfect Dodge'] = true,
    ['Perpetuance'] = true,
    ['Pflug'] = true,
    ['Phantom Roll'] = true,
    ['Pianissimo'] = true,
    ['Provoke'] = true,
    ['Puppet Roll'] = true,
    ['Quick Draw'] = true,
    ['Quickstep'] = true,
    ['Radial Arcana'] = true,
    ['Rampart'] = true,
    ['Random Deal'] = true,
    ['Rapture'] = true,
    ['Rayke'] = true,
    ['Ready'] = true,
    ['Release'] = true,
    ['Repair'] = true,
    ['Restraint'] = true,
    ['Retaliation'] = true,
    ['Retrieve'] = true,
	['Restoring Breath'] = true,
    ['Reverse Flourish'] = true,
    ['Reward'] = true,
    ["Rogue's Roll"] = true,
    ['Role Reversal'] = true,
    ['Run Wild'] = true,
    ["Runeist's Roll"] = true,
    ['Saboteur'] = true,
    ['Sacrosanctity'] = true,
    ['Samurai Roll'] = true,
    ['Sange'] = true,
    ['Savage Shot'] = true,
    ['Scarlet Delirium'] = true,
    ['Scavenge'] = true,
    ["Scholar's Roll"] = true,
    ['Seigan'] = true,
    ['Sekkanoki'] = true,
    ['Sentinel'] = true,
    ['Sepulcher'] = true,
    ['Shadowbind'] = true,
    ['Sharpshot'] = true,
    ['Shield Bash'] = true,
    ['Shikikoyo'] = true,
    ['Sic'] = true,
	['Smiting Breath'] = true,
    ['Snake Eye'] = true,
    ['Snarl'] = true,
    ['Soul Eater'] = true,
    ['Soul Jump'] = true,
    ['Soul Voice'] = true,
    ['Souleater'] = true,
    ['Spirit Jump'] = true,
    ['Spirit Link'] = true,
    ['Spirit Surge'] = true,
    ['Spontaneity'] = true,
    ['Spur'] = true,
    ['Stay'] = true,
    ['Steal'] = true,
    ['Stealth Shot'] = true,
    ['Strafe'] = true,
    ['Striking Flourish'] = true,
    ['Stutter Step'] = true,
    ['Stymie'] = true,
    ['Sublimation'] = true,
    ['Sulpor'] = true,
    ['Super Jump'] = true,
    ['Swipe'] = true,
    ['Swordplay'] = true,
    ['Tabula Rasa'] = true,
    ['Tactical Switch'] = true,
    ["Tactician's Roll"] = true,
    ['Tame'] = true,
    ['Tellus'] = true,
    ['Tenebrae'] = true,
    ['Tenuto'] = true,
    ['Ternary Flourish'] = true,
    ['Theurgic Focus'] = true,
    ['Third Eye'] = true,
    ['Thunder Maneuver'] = true,
    ['Thunder Shot'] = true,
    ['Tomahawk'] = true,
    ['Trance'] = true,
    ['Triple Shot'] = true,
    ['Troubadour'] = true,
    ['Unbridled Learning'] = true,
    ['Unbridled Wisdom'] = true,
    ['Unda'] = true,
    ['Unleash'] = true,
    ['Unlimited Shot'] = true,
    ['Valiance'] = true,
    ['Vallation'] = true,
    ['Velocity Shot'] = true,
    ['Ventriloquy'] = true,
    ['Violent Flourish'] = true,
    ['Vivacious Pulse'] = true,
    ['Warcry'] = true,
    ['Warding Circle'] = true,
    ["Warlock's Roll"] = true,
    ["Warrior's Charge"] = true,
    ['Water Maneuver'] = true,
    ['Water Shot'] = true,
    ['Weapon Bash'] = true,
    ['Widened Compass'] = true,
    ['Wild Card'] = true,
    ['Wild Flourish'] = true,
    ['Wind Maneuver'] = true,
    ['Wind Shot'] = true,
    ["Wizard's Roll"] = true,
    ['Yaegasumi'] = true,
    ['Yonin'] = true,
	['a remedy'] = true,
	['a panacea'] = true,
	['an echo drop'] = true,
	['Wary'] = true,
	
	
}
local function text_settings(size)
    return {
        pos = {x = settings.center_x, y = settings.center_y},

        bg = {
            visible = false,
            alpha = 0,
        },

        flags = {
            bold = true,
            draggable = true,
            right = false,
            bottom = false,
        },

        padding = 0,

        text = {
            font = settings.font,
            size = size,
            alpha = 255,
            red = 255,
            green = 255,
            blue = 255,

            stroke = {
                width = settings.stroke_width,
                alpha = 255,
                red = 0,
                green = 0,
                blue = 0,
            },
        },
    }
end

local ws_text = texts.new('', text_settings(settings.ws_size))
local dmg_text = texts.new('', text_settings(settings.dmg_size))
local avg_text = texts.new('', text_settings(settings.avg_size))
local avg_label_text = texts.new('', text_settings(settings.avg_size))
local avg_value_text = texts.new('', text_settings(settings.avg_size))
local sc_text = texts.new('', text_settings(settings.sc_size or settings.avg_size))
local flair_text = texts.new('', text_settings(settings.flair_size))
local highlight_text = texts.new('', text_settings(settings.dmg_size))

-- Start hidden on addon load. The overlay appears after the first tracked WS,
-- or manually with //cw show.
ws_text:hide()
dmg_text:hide()
avg_text:hide()
avg_label_text:hide()
avg_value_text:hide()
sc_text:hide()
flair_text:hide()
highlight_text:hide()

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function apply_alpha(alpha)
    alpha = clamp(math.floor(alpha or 255), 0, 255)
    alpha_current = alpha

    ws_text:alpha(alpha)
    dmg_text:alpha(alpha)
    avg_text:alpha(alpha)
    avg_label_text:alpha(alpha)
    avg_value_text:alpha(alpha)
    if sc_visible and not sc_fading then
        sc_text:alpha(alpha)
    end
    if not flair_fading then
        flair_text:alpha(alpha)
    end
    if settings.gradient_enabled then
        highlight_text:alpha(math.floor(alpha * 0.35))
    else
        highlight_text:alpha(0)
    end

    ws_text:stroke_alpha(alpha)
    dmg_text:stroke_alpha(alpha)
    avg_text:stroke_alpha(alpha)
    avg_label_text:stroke_alpha(alpha)
    avg_value_text:stroke_alpha(alpha)
    if sc_visible and not sc_fading then
        sc_text:stroke_alpha(alpha)
    end
    if not flair_fading then
        flair_text:stroke_alpha(alpha)
    end
    highlight_text:stroke_alpha(0)

    if alpha <= 0 then
        ws_text:hide()
        dmg_text:hide()
        avg_text:hide()
        avg_label_text:hide()
        avg_value_text:hide()
        sc_text:hide()
        flair_text:hide()
        highlight_text:hide()
    else
        ws_text:show()
        dmg_text:show()
        avg_text:show()
        avg_label_text:show()
        avg_value_text:show()
        if sc_visible then
            sc_text:show()
        end
        if flair_visible then
            flair_text:show()
        end
        if highlight_visible and settings.gradient_enabled then
            highlight_text:show()
        else
            highlight_text:hide()
        end
    end
end

local function start_damage_fade_in()
    if not settings.fade_enabled then
        fade_state = 'visible'
        apply_alpha(255)
        return
    end

    -- A new WS should refresh the overlay, but only the damage line fades in.
    fade_state = 'damage_fade_in'
    fade_start = os.clock()

    ws_text:show()
    dmg_text:show()
    avg_text:show()
    avg_label_text:show()
    avg_value_text:show()
    if sc_visible then sc_text:show() end

    ws_text:alpha(255)
    ws_text:stroke_alpha(255)

    avg_text:alpha(255)
    avg_text:stroke_alpha(255)
    avg_label_text:alpha(255)
    avg_label_text:stroke_alpha(255)
    avg_value_text:alpha(255)
    avg_value_text:stroke_alpha(255)
    if sc_visible and not sc_fading then
        sc_text:alpha(255)
        sc_text:stroke_alpha(255)
    end

    dmg_text:alpha(1)
    dmg_text:stroke_alpha(1)

    if highlight_visible and settings.gradient_enabled then
        highlight_text:alpha(1)
        highlight_text:show()
    end

    if flair_visible then
        flair_text:show()
        -- On the first WS after hidden load, make sure flair starts visible too.
        -- Previously only the damage line was explicitly faded in, so Big Hit / CRANKED
        -- could be created with alpha 0 and remain invisible until the next WS.
        if flair_fading then
            flair_fade_start_alpha = 255
            flair_text:alpha(255)
            flair_text:stroke_alpha(255)
        end
    end

    alpha_current = 255
end

local function format_number(num)
    local s = tostring(num or '')
    s = s:gsub(',', '')
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function clean_damage_number(num)
    local s = tostring(num or '0'):gsub(',', '')
    return tonumber(s) or 0
end

local function get_damage_style(dmg)
    if is_whiff then
        return 180, 180, 180, settings.stroke_width, 'LOL'
    end

    dmg = tonumber(dmg) or 0

    if dmg == 99999 then
        return 255, 70, 70, settings.big_stroke_width, cranked_flair_text
    elseif dmg >= 80000 then
        return 255, 70, 70, settings.big_stroke_width, 'MASSIVE HIT!!'
    elseif dmg >= 50000 then
        return 255, 215, 0, settings.big_stroke_width, 'BIG HIT!'
    elseif dmg >= 10000 then
        return 100, 170, 255, settings.stroke_width, nil
    else
        return 255, 255, 255, settings.stroke_width, nil
    end
end

local function safe_extents(obj)
    local w, h = obj:extents()
    return tonumber(w) or 0
end

local function position_line(obj, y)
    local width = safe_extents(obj)
    obj:pos(math.floor(settings.center_x - (width / 2)), y)
end

local function position_avg_line()
    local ws_x = ws_text:pos()
    local y = settings.center_y + settings.avg_gap

    -- Keep the label white and color only the damage number.
    avg_label_text:pos(ws_x, y)

    local label_width = safe_extents(avg_label_text)
    avg_value_text:pos(math.floor(ws_x + label_width), y)

    -- Legacy avg_text is kept hidden/unused so older settings/layout logic stays harmless.
    avg_text:hide()
end

local function request_layout_refresh(duration)
    -- Windower text extents can lag for a few frames after changing text/size/font.
    -- Re-centering briefly keeps the overlay at the saved //cw pos immediately.
    layout_refresh_until = os.clock() + (duration or 0.35)
end

local function apply_avg_style(avg)
    avg = tonumber(avg) or 0

    if avg >= 80000 then
        avg_value_text:color(255, 70, 70)
        avg_value_text:stroke_width(settings.big_stroke_width)
    elseif avg >= 50000 then
        avg_value_text:color(255, 215, 0)
        avg_value_text:stroke_width(settings.big_stroke_width)
    elseif avg >= 10000 then
        avg_value_text:color(100, 170, 255)
        avg_value_text:stroke_width(settings.stroke_width)
    else
        avg_value_text:color(255, 255, 255)
        avg_value_text:stroke_width(settings.stroke_width)
    end
end

local function update_display()
    ws_text:text('Last WS: ' .. last_ws .. '!')

    local damage_line = last_dmg .. ' damage!!'
    if is_whiff then
        damage_line = 'WHIFF!!'
    end

    dmg_text:text(damage_line)
    highlight_text:text(damage_line)
    avg_text:text('')
    avg_label_text:text('Avg: ')
    avg_value_text:text(avg_dmg)

    position_line(ws_text, settings.center_y)
    if not whiff_shaking then
        position_line(dmg_text, settings.center_y + settings.line_gap)
    end

    if highlight_visible and settings.gradient_enabled then
        position_line(highlight_text, settings.center_y + settings.line_gap - 2)
    end

    position_avg_line()

    if flair_visible and not flair_fading then
        position_line(flair_text, settings.center_y + settings.flair_gap)
    end
end

local function apply_gradient_style(raw_dmg)
    highlight_visible = false
    highlight_text:hide()
    highlight_text:alpha(0)
    highlight_text:stroke_alpha(0)

    if not settings.gradient_enabled then
        return
    end

    raw_dmg = tonumber(raw_dmg) or 0

    if raw_dmg >= 80000 then
        -- Red tier: warm orange/red highlight over red base.
        highlight_text:color(255, 150, 80)
        highlight_text:stroke_width(0)
        highlight_text:alpha(math.floor(alpha_current * 0.35))
        highlight_text:stroke_alpha(0)
        highlight_visible = true
        highlight_text:show()
    elseif raw_dmg >= 50000 then
        -- Gold tier: pale yellow highlight over gold base.
        highlight_text:color(255, 245, 150)
        highlight_text:stroke_width(0)
        highlight_text:alpha(math.floor(alpha_current * 0.35))
        highlight_text:stroke_alpha(0)
        highlight_visible = true
        highlight_text:show()
    end
end

local function start_pop(raw_dmg)
    raw_dmg = tonumber(raw_dmg) or 0

    if not settings.pop_enabled or raw_dmg < 50000 then
        return
    end

    pop_active = true
    pop_start = os.clock()
    pop_base_size = settings.dmg_size
    dmg_text:size(settings.dmg_size + settings.pop_bonus_size)
    highlight_text:size(settings.dmg_size + settings.pop_bonus_size)
    update_display()
end

local function apply_damage_style(raw_dmg)
    local r, g, b, stroke, flair = get_damage_style(raw_dmg)

    dmg_text:color(r, g, b)
    dmg_text:stroke_width(stroke)
    apply_gradient_style(raw_dmg)

    if flair then
        flair_text:text(flair)
        flair_text:color(255, 255, 255)
        flair_text:stroke_width(stroke)
        flair_text:size(settings.flair_size)
        flair_text:alpha(alpha_current)
        flair_text:stroke_alpha(alpha_current)
        flair_text:show()
        flair_visible = true
        flair_fading = true
        flair_fade_start = os.clock()
        flair_base_size = settings.flair_size
        flair_fade_start_alpha = alpha_current
        flair_start_y = settings.center_y + settings.flair_gap
        flair_expire = 0
    else
        flair_text:hide()
        flair_visible = false
        flair_fading = false
        flair_fade_start = 0
        flair_expire = 0
    end
end

local function save_settings()
    config.save(settings)
end

local function clean_line(line)
    if not line then return '' end

    line = line:gsub('cs%(%d+,%d+,%d+%)', '')
    line = line:gsub('cr', '')
    line = line:gsub('\30.', '')
    line = line:gsub('\31.', '')
    line = line:gsub('%s+', ' ')

    return line
end

local function escape_lua_pattern(s)
    return (s:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1'))
end

local function player_ws_from_line(line, player_name)
    local ws = line:match('You use%s+([^%,%.]+)[%,%.]')
    if ws then return ws end

    local safe_name = escape_lua_pattern(player_name)
    ws = line:match(safe_name .. '%s+uses%s+([^%,%.]+)[%,%.]')
    if ws then return ws end

    return nil
end

local function damage_from_line(line)
    return line:match('takes%s+([%d,]+)%s+points?%s+of%s+damage')
end

local function whiff_from_line(line)
    line = line:lower()

    return line:find('miss') ~= nil
        or line:find('evade') ~= nil
        or line:find('no effect') ~= nil
        or line:find('fails to take effect') ~= nil
        or line:find('has no effect') ~= nil
end

local function skillchain_from_line(line)
    local l = line:lower()
    return l:find('skillchain') ~= nil
        or l:find('magic burst') ~= nil
end

local function position_sc_line(y)
    local width = safe_extents(sc_text)
    sc_text:pos(math.floor(settings.center_x - (width / 2)), y)
end

local function start_sc_popup(dmg)
    if not settings.sc_enabled then return end

    local raw = clean_damage_number(dmg)
    if raw <= 0 then return end

    sc_bonus_dmg = raw
    sc_text:text('SC Bonus: ' .. format_number(raw) .. '!!')
    sc_text:font(settings.font)
    sc_text:size(settings.sc_size or settings.flair_size)
    sc_text:color(120, 255, 255)
    sc_text:stroke_width(settings.stroke_width)
    sc_text:alpha(255)
    sc_text:stroke_alpha(255)

    -- Use the same visual lane as Big Hit / Massive Hit / CRANKED.
    -- It is intentionally anchored near the damage text instead of centered.
    sc_start_y = settings.center_y + (settings.sc_gap or settings.flair_gap or 118)

    -- True center the SC Bonus on the overlay center.
    -- This prevents large SC text from hanging right.
    position_sc_line(math.floor(sc_start_y + (settings.flair_offset_y or -4) + (settings.sc_offset_y or 0)))

    sc_visible = true
    sc_fading = true
    sc_fade_start = os.clock()
    sc_fade_start_alpha = 255
    sc_text:show()

    sc_armed = false
    sc_window_until = 0

    if debug_mode then
        windower.add_to_chat(200, '[CrankWatch] SC Bonus: ' .. format_number(raw))
    end
end

local function start_whiff_shake()
    whiff_shaking = true
    whiff_shake_start = os.clock()
end

local function commit(ws, dmg)
    is_whiff = tostring(dmg or ''):upper() == 'WHIFF'

    local raw_dmg = 0
    if not is_whiff then
        raw_dmg = clean_damage_number(dmg)
    end

    if not is_whiff then
        total_ws_damage = total_ws_damage + raw_dmg
        total_ws_count = total_ws_count + 1
        local avg_raw = math.floor(total_ws_damage / total_ws_count)
        avg_dmg = format_number(avg_raw)
        apply_avg_style(avg_raw)
    end

    if raw_dmg == 99999 then
        cranked_streak = cranked_streak + 1
        if cranked_streak <= 1 then
            cranked_flair_text = 'CRANKED!!!'
        else
            cranked_flair_text = 'CRANKED x ' .. tostring(cranked_streak)
        end
    else
        cranked_streak = 0
        cranked_flair_text = 'CRANKED!!!'
    end

    last_ws = ws
    last_raw_dmg = raw_dmg
    last_dmg = is_whiff and 'WHIFF' or format_number(raw_dmg)
    pending_ws = nil
    pending_time = 0

    last_ws_time = os.clock()
    sc_window_until = last_ws_time + (settings.sc_window or 4.0)
    sc_armed = false

    apply_damage_style(raw_dmg)
    update_display()
    request_layout_refresh(0.45)

    if is_whiff then
        start_whiff_shake()
    else
        whiff_shaking = false
        start_pop(raw_dmg)
    end

    start_damage_fade_in()

    if debug_mode then
        windower.add_to_chat(200, '[CrankWatch] Updated: ' .. last_ws .. ' / ' .. last_dmg)
    end
end

local function sync_center_from_ws_anchor()
    local x, y = ws_text:pos()
    settings.center_x = math.floor(x + (safe_extents(ws_text) / 2))
    settings.center_y = y
    update_display()
end

local function sync_center_from_dmg_anchor()
    local x, y = dmg_text:pos()
    settings.center_x = math.floor(x + (safe_extents(dmg_text) / 2))
    settings.center_y = y - settings.line_gap
    update_display()
end

local function sync_center_from_avg_anchor()
    local x, y = avg_text:pos()
    settings.center_x = math.floor(x + (safe_extents(avg_text) / 2))
    settings.center_y = y - settings.avg_gap
    update_display()
end

local function sync_center_from_flair_anchor()
    local x, y = flair_text:pos()
    settings.center_x = math.floor(x + (safe_extents(flair_text) / 2))
    settings.center_y = y - settings.flair_gap
    update_display()
end

ws_text:register_event('drag', function()
    dragging_anchor = true
    sync_center_from_ws_anchor()
end)

dmg_text:register_event('drag', function()
    dragging_anchor = true
    sync_center_from_dmg_anchor()
end)

avg_text:register_event('drag', function()
    dragging_anchor = true
    sync_center_from_avg_anchor()
end)

flair_text:register_event('drag', function()
    dragging_anchor = true
    sync_center_from_flair_anchor()
end)

windower.register_event('mouse', function(type)
    if type == 2 and dragging_anchor then
        dragging_anchor = false
        save_settings()
        windower.add_to_chat(200, '[CrankWatch] Position saved.')
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()

    if layout_refresh_until > 0 then
        if now <= layout_refresh_until then
            update_display()
        else
            layout_refresh_until = 0
        end
    end

    if sc_visible and sc_fading then
        local t = (now - sc_fade_start) / math.max(settings.sc_fade_duration or 4.50, 0.01)

        if t >= 1 then
            sc_text:hide()
            sc_visible = false
            sc_fading = false
            sc_fade_start = 0
            sc_text:alpha(0)
            sc_text:stroke_alpha(0)
        else
            local eased = 1 - ((1 - t) * (1 - t))
            local a = math.floor(sc_fade_start_alpha * (1 - t))
            local y = math.floor(sc_start_y - ((settings.sc_float_distance or 32) * eased))

            sc_text:alpha(a)
            sc_text:stroke_alpha(a)
            sc_text:show()

            position_sc_line(math.floor(y + (settings.flair_offset_y or -4) + (settings.sc_offset_y or 0)))
        end
    end

    if flair_visible and flair_fading then
        local t = (now - flair_fade_start) / math.max(settings.flair_fade_duration, 0.01)

        if t >= 1 then
            flair_text:hide()
            flair_visible = false
            flair_fading = false
            flair_fade_start = 0
            flair_expire = 0
            flair_text:size(settings.flair_size)
            flair_text:alpha(0)
            flair_text:stroke_alpha(0)
        else
            -- Float upward while fading out quickly.
            local eased = 1 - ((1 - t) * (1 - t))
            local a = math.floor(flair_fade_start_alpha * (1 - t))
            local y = math.floor(flair_start_y - ((settings.flair_float_distance or 32) * eased))
            local size = math.max(1, math.floor(flair_base_size - ((settings.flair_shrink_size or 0) * t)))

            flair_text:size(size)
            flair_text:alpha(a)
            flair_text:stroke_alpha(a)
            flair_text:show()

            local dmg_x, dmg_y = dmg_text:pos()
            local dmg_width = safe_extents(dmg_text)

            flair_text:pos(
                math.floor(dmg_x + (dmg_width * (settings.flair_anchor_ratio or 0.72))),
                math.floor(y + (settings.flair_offset_y or -4))
            )
        end
    end

    if whiff_shaking then
        local t = (now - whiff_shake_start) / math.max(settings.whiff_shake_duration, 0.01)

        if t >= 1 then
            whiff_shaking = false
            update_display()
        else
            local offset = math.floor(math.sin(t * 70) * settings.whiff_shake_strength * (1 - t))
            local width = safe_extents(dmg_text)
            dmg_text:pos(math.floor(settings.center_x - (width / 2)) + offset, settings.center_y + settings.line_gap)
        end
    end

    if pop_active then
        local t = (now - pop_start) / math.max(settings.pop_duration, 0.01)
        if t >= 1 then
            pop_active = false
            dmg_text:size(settings.dmg_size)
            highlight_text:size(settings.dmg_size)
            update_display()
        else
            -- Ease back from enlarged to normal size.
            local eased = 1 - ((1 - t) * (1 - t))
            local size = math.floor((settings.dmg_size + settings.pop_bonus_size) - (settings.pop_bonus_size * eased))
            dmg_text:size(size)
            highlight_text:size(size)
            update_display()
        end
    end

    if not settings.fade_enabled then
        return
    end

    if fade_state == 'damage_fade_in' then
        local t = (now - fade_start) / math.max(settings.fade_in_duration, 0.01)

        ws_text:alpha(255)
        ws_text:stroke_alpha(255)
        avg_text:alpha(255)
        avg_text:stroke_alpha(255)
        avg_label_text:alpha(255)
        avg_label_text:stroke_alpha(255)
        avg_value_text:alpha(255)
        avg_value_text:stroke_alpha(255)

        if t >= 1 then
            fade_state = 'visible'
            dmg_text:alpha(255)
            dmg_text:stroke_alpha(255)
            if highlight_visible and settings.gradient_enabled then
                highlight_text:alpha(math.floor(255 * 0.35))
            end
        else
            local a = math.max(1, math.floor(255 * t))
            dmg_text:alpha(a)
            dmg_text:stroke_alpha(a)
            if highlight_visible and settings.gradient_enabled then
                highlight_text:alpha(math.floor(a * 0.35))
            end
        end

    elseif fade_state == 'visible' then
        if last_ws_time > 0 and (now - last_ws_time) >= settings.hold_duration then
            fade_state = 'fade_out'
            fade_start = now
        end

    elseif fade_state == 'fade_out' then
        local t = (now - fade_start) / math.max(settings.fade_out_duration, 0.01)
        if t >= 1 then
            fade_state = 'hidden'
            apply_alpha(0)
        else
            apply_alpha(255 * (1 - t))
        end
    end
end)

windower.register_event('incoming text', function(original, modified)
    local p = windower.ffxi.get_player()
    if not p then return end

    local now = os.clock()
    local name = p.name
    local line = clean_line(original)

    if debug_mode then
        windower.add_to_chat(207, '[wsdamage debug] ' .. line)
    end

    if pending_ws and (now - pending_time > settings.pending_timeout) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Pending WS expired: ' .. pending_ws)
        end
        pending_ws = nil
        pending_time = 0
    end

    local ws = player_ws_from_line(line, name)
    local dmg = damage_from_line(line)
    local whiff = whiff_from_line(line)
    local skillchain = skillchain_from_line(line)

    if settings.sc_enabled and sc_window_until > 0 and now > sc_window_until then
        sc_window_until = 0
        sc_armed = false
    end

    if settings.sc_enabled and skillchain and sc_window_until > 0 and now <= sc_window_until then
        sc_armed = true
    end

    if settings.sc_enabled and dmg and sc_armed and sc_window_until > 0 and now <= sc_window_until and not ws then
        start_sc_popup(dmg)
        return
    end

    if ws and ignored_abilities[ws] then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored ability: ' .. ws)
        end
        return
    end

    if ws and not is_weapon_skill(ws) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored non-WS use line: ' .. ws)
        end
        return
    end

    if ws and dmg then
        commit(ws, dmg)
        return
    end

    if ws and whiff then
        commit(ws, 'WHIFF')
        return
    end

    if ws then
        pending_ws = ws
        pending_time = now

        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] WS detected: ' .. pending_ws)
        end

        return
    end

    if dmg and pending_ws and (now - pending_time <= settings.pending_timeout) then
        commit(pending_ws, dmg)
        return
    end

    if whiff and pending_ws and (now - pending_time <= settings.pending_timeout) then
        commit(pending_ws, 'WHIFF')
        return
    end
end)

local function apply_all_visual_settings()
    ws_text:font(settings.font)
    dmg_text:font(settings.font)
    avg_text:font(settings.font)
    avg_label_text:font(settings.font)
    avg_value_text:font(settings.font)
    sc_text:font(settings.font)
    flair_text:font(settings.font)
    highlight_text:font(settings.font)

    ws_text:size(settings.ws_size)
    dmg_text:size(settings.dmg_size)
    avg_text:size(settings.avg_size)
    avg_label_text:size(settings.avg_size)
    avg_value_text:size(settings.avg_size)
    sc_text:size(settings.sc_size or settings.flair_size)
    flair_text:size(settings.flair_size)
    highlight_text:size(settings.dmg_size)

    ws_text:stroke_width(settings.stroke_width)
    dmg_text:stroke_width(settings.stroke_width)
    avg_text:stroke_width(settings.stroke_width)
    avg_label_text:stroke_width(settings.stroke_width)
    avg_value_text:stroke_width(settings.stroke_width)
    sc_text:stroke_width(settings.stroke_width)
    flair_text:stroke_width(settings.stroke_width)
    highlight_text:stroke_width(0)

    ws_text:color(255, 255, 255)
    avg_text:color(255, 255, 255)
    avg_label_text:color(255, 255, 255)
    sc_text:color(120, 255, 255)
    apply_avg_style(clean_damage_number(avg_dmg))

    apply_damage_style(last_raw_dmg)
    update_display()
    request_layout_refresh(0.45)
end

windower.register_event('addon command', function(cmd, arg1, arg2)
    cmd = cmd and cmd:lower() or ''

    if cmd == 'test' then
        commit('Savage Blade', '29973')

    elseif cmd == 'testwhite' then
        commit('Savage Blade', '9999')

    elseif cmd == 'testwhiff' then
        commit('Savage Blade', 'WHIFF')

    elseif cmd == 'testbig' then
        commit('Stardiver', '65000')

    elseif cmd == 'testred' then
        commit('Savage Blade', '90000')

    elseif cmd == 'testmassive' then
        commit('Torcleaver', '99999')

    elseif cmd == 'testsc' then
        commit('Savage Blade', '54321')
        start_sc_popup('18772')

    elseif cmd == 'testcrankedstreak' then
        commit('Torcleaver', '99999')
        commit('Torcleaver', '99999')
        commit('Torcleaver', '99999')

    elseif cmd == 'pos' then
        local x = tonumber(arg1)
        local y = tonumber(arg2)

        if x and y then
            settings.center_x = x
            settings.center_y = y
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Center position set and saved: ' .. x .. ', ' .. y)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw pos 900 450')
        end

    elseif cmd == 'size' then
        local size = tonumber(arg1)

        if size then
            settings.ws_size = size
            settings.dmg_size = size + 6
            settings.avg_size = math.max(16, size - 12)
            settings.flair_size = math.max(18, size - 4)
            settings.line_gap = math.floor(size * 1.22)
            settings.avg_gap = math.floor(size * 2.40)
            settings.flair_gap = math.floor(size * 3.25)

            apply_all_visual_settings()
            save_settings()

            windower.add_to_chat(200, '[CrankWatch] Size saved: WS ' .. settings.ws_size .. ', damage ' .. settings.dmg_size)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw size 36')
        end

    elseif cmd == 'gap' then
        local gap = tonumber(arg1)

        if gap then
            settings.line_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Line gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw gap 44')
        end

    elseif cmd == 'avggap' then
        local gap = tonumber(arg1)

        if gap then
            settings.avg_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Average gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw avggap 86')
        end

    elseif cmd == 'flairgap' then
        local gap = tonumber(arg1)

        if gap then
            settings.flair_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Flair gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw flairgap 88')
        end

    elseif cmd == 'stroke' then
        local width = tonumber(arg1)

        if width then
            settings.stroke_width = width
            settings.big_stroke_width = width + 1
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Stroke width saved: ' .. width)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw stroke 4')
        end

    elseif cmd == 'font' then
        local font = arg1

        if font and font ~= '' then
            settings.font = font
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Font saved: ' .. font)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw font Highwind')
        end

    elseif cmd == 'fade' then
        local value = arg1 and arg1:lower() or ''

        if value == 'on' then
            settings.fade_enabled = true
            last_ws_time = os.clock()
            start_damage_fade_in()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Fade enabled.')
        elseif value == 'off' then
            settings.fade_enabled = false
            fade_state = 'visible'
            apply_alpha(255)
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Fade disabled.')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw fade on|off')
        end

    elseif cmd == 'fadetime' then
        local hold = tonumber(arg1)
        local out = tonumber(arg2)

        if hold and out then
            settings.hold_duration = hold
            settings.fade_out_duration = out
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Fade timing saved: hold ' .. hold .. 's, out ' .. out .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw fadetime 60 8')
        end

    elseif cmd == 'fadein' then
        local duration = tonumber(arg1)

        if duration then
            settings.fade_in_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Fade-in saved: ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw fadein 0.3')
        end

    elseif cmd == 'pop' then
        local value = arg1 and arg1:lower() or ''

        if value == 'on' then
            settings.pop_enabled = true
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Pop enabled.')
        elseif value == 'off' then
            settings.pop_enabled = false
            pop_active = false
            dmg_text:size(settings.dmg_size)
            highlight_text:size(settings.dmg_size)
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Pop disabled.')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw pop on|off')
        end

    elseif cmd == 'popsize' then
        local bonus = tonumber(arg1)

        if bonus then
            settings.pop_bonus_size = bonus
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Pop size saved: +' .. bonus)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw popsize 8')
        end

    elseif cmd == 'poptime' then
        local duration = tonumber(arg1)

        if duration then
            settings.pop_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Pop duration saved: ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw poptime 0.35')
        end

    elseif cmd == 'gradient' then
        local value = arg1 and arg1:lower() or ''

        if value == 'on' then
            settings.gradient_enabled = true
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Gradient enabled.')
        elseif value == 'off' then
            settings.gradient_enabled = false
            highlight_visible = false
            highlight_text:hide()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Gradient disabled.')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw gradient on|off')
        end

    elseif cmd == 'flairfade' then
        local duration = tonumber(arg1)

        if duration then
            settings.flair_fade_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Flair fade duration saved: ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw flairfade 1.5')
        end

    elseif cmd == 'flairshrink' then
        local shrink = tonumber(arg1)

        if shrink then
            settings.flair_shrink_size = shrink
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Flair shrink saved: ' .. shrink)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw flairshrink 0')
        end

    elseif cmd == 'flairfloat' then
        local distance = tonumber(arg1)

        if distance then
            settings.flair_float_distance = distance
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Flair float distance saved: ' .. distance)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw flairfloat 32')
        end

    elseif cmd == 'whiffshake' then
        local strength = tonumber(arg1)
        local duration = tonumber(arg2)

        if strength and duration then
            settings.whiff_shake_strength = strength
            settings.whiff_shake_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] WHIFF shake saved: strength ' .. strength .. ', duration ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw whiffshake 6 0.45')
        end

    elseif cmd == 'scsize' then
        local size = tonumber(arg1)

        if size then
            settings.sc_size = math.max(10, math.floor(size))
            sc_text:size(settings.sc_size)
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC Bonus size saved: ' .. settings.sc_size)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scsize 28')
        end

    elseif cmd == 'scfade' then
        local duration = tonumber(arg1)

        if duration then
            settings.sc_fade_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC fade duration saved: ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scfade 4.5')
        end

    elseif cmd == 'scfloat' then
        local distance = tonumber(arg1)

        if distance then
            settings.sc_float_distance = distance
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC float distance saved: ' .. distance)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scfloat 32')
        end

    elseif cmd == 'scoffset' then
        local offset = tonumber(arg1)

        if offset then
            settings.sc_offset_y = offset
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC vertical offset saved: ' .. offset)
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scoffset 18')
        end

    elseif cmd == 'reset' or cmd == 'resetavg' then
        total_ws_damage = 0
        total_ws_count = 0
        avg_dmg = '-'
        apply_avg_style(0)
        update_display()
        request_layout_refresh(0.45)
        windower.add_to_chat(200, '[CrankWatch] Average reset.')

    elseif cmd == 'factoryreset' then
        settings.center_x = defaults.center_x
        settings.center_y = defaults.center_y
        settings.ws_size = defaults.ws_size
        settings.dmg_size = defaults.dmg_size
        settings.avg_size = defaults.avg_size
        settings.flair_size = defaults.flair_size
        settings.line_gap = defaults.line_gap
        settings.avg_gap = defaults.avg_gap
        settings.flair_gap = defaults.flair_gap
        settings.font = defaults.font
        settings.stroke_width = defaults.stroke_width
        settings.big_stroke_width = defaults.big_stroke_width
        settings.pending_timeout = defaults.pending_timeout
        settings.flair_duration = defaults.flair_duration
        settings.fade_enabled = defaults.fade_enabled
        settings.fade_in_duration = defaults.fade_in_duration
        settings.hold_duration = defaults.hold_duration
        settings.fade_out_duration = defaults.fade_out_duration
        settings.whiff_shake_duration = defaults.whiff_shake_duration
        settings.whiff_shake_strength = defaults.whiff_shake_strength
        settings.sc_enabled = defaults.sc_enabled
        settings.sc_window = defaults.sc_window
        settings.sc_fade_duration = defaults.sc_fade_duration
        settings.sc_float_distance = defaults.sc_float_distance
        settings.sc_gap = defaults.sc_gap
        settings.sc_size = defaults.sc_size
        settings.sc_offset_y = defaults.sc_offset_y
        settings.pop_enabled = defaults.pop_enabled
        settings.pop_duration = defaults.pop_duration
        settings.pop_bonus_size = defaults.pop_bonus_size
        settings.gradient_enabled = defaults.gradient_enabled
        settings.flair_fade_duration = defaults.flair_fade_duration
        settings.flair_shrink_size = defaults.flair_shrink_size
        settings.flair_float_distance = defaults.flair_float_distance

        apply_all_visual_settings()
        save_settings()
        windower.add_to_chat(200, '[CrankWatch] Factory settings reset and saved.')

    elseif cmd == 'hide' then
        ws_text:hide()
        dmg_text:hide()
        avg_text:hide()
        avg_label_text:hide()
        avg_value_text:hide()
        sc_text:hide()
        flair_text:hide()
        highlight_text:hide()
        fade_state = 'hidden'
        alpha_current = 0

    elseif cmd == 'show' then
        fade_state = 'visible'
        alpha_current = 255
        apply_alpha(255)
        update_display()
        request_layout_refresh(0.45)

    elseif cmd == 'debug' then
        debug_mode = not debug_mode
        windower.add_to_chat(200, '[CrankWatch] Debug mode: ' .. tostring(debug_mode))

    elseif cmd == 'help' then
        windower.add_to_chat(200, '[CrankWatch] Commands: //cw test | testwhite | testwhiff | testbig | testred | testmassive | testsc | testcrankedstreak | reset | show | hide | pos x y | size 36 | gap 44 | avggap 86 | flairgap 118 | stroke 4 | font Highwind | fade on|off | fadetime 60 8 | fadein 0.3 | pop on|off | popsize 8 | poptime 0.35 | gradient on|off | flairfade 1.5 | flairshrink 0 | flairfloat 32 | whiffshake 6 0.45 | scsize 28 | scfade 4.5 | scfloat 32 | scoffset 0 | reset | factoryreset | debug')

    else
        windower.add_to_chat(200, '[CrankWatch] Commands: //cw test | testwhite | testwhiff | testbig | testred | testmassive | testsc | testcrankedstreak | reset | show | hide | pos x y | size 36 | gap 44 | avggap 86 | flairgap 118 | stroke 4 | font Highwind | fade on|off | fadetime 60 8 | fadein 0.3 | pop on|off | popsize 8 | poptime 0.35 | gradient on|off | flairfade 1.5 | flairshrink 0 | flairfloat 32 | whiffshake 6 0.45 | scsize 28 | scfade 4.5 | scfloat 32 | scoffset 0 | reset | factoryreset | debug')
    end
end)

windower.register_event('unload', function()
    save_settings()

    if ws_text then
        ws_text:destroy()
    end

    if dmg_text then
        dmg_text:destroy()
    end

    if avg_text then
        avg_text:destroy()
    end

    if avg_label_text then
        avg_label_text:destroy()
    end

    if avg_value_text then
        avg_value_text:destroy()
    end

    if sc_text then
        sc_text:destroy()
    end

    if flair_text then
        flair_text:destroy()
    end

    if highlight_text then
        highlight_text:destroy()
    end
end)

apply_all_visual_settings()
update_display()
apply_alpha(0)

fade_state = 'hidden'
alpha_current = 0

_addon.name = 'CrankWatch'
_addon.author = 'VelnerXI'
--twitch.tv/VelnerXI -- Live starting 5:30 pm PT most days!
_addon.version = '2.0'
_addon.commands = {'crankwatch', 'cw'}

local texts = require('texts')
local config = require('config')
pcall(require, 'luau')
pcall(require, 'pack')
local has_actions = pcall(require, 'actions')
local ActionPacket = has_actions and _G.ActionPacket or nil
local sc_packet_bar_enabled = ActionPacket and type(ActionPacket.open_listener) == 'function'

-- Packet-confirmed skillchain message IDs, mirrored from Skillchains.
-- Chain count must come from these add_effect packet messages, not from
-- "a WS landed during GO" or the delayed chat-side SC damage line.
local SKILLCHAIN_IDS = {
    [288]=true,[289]=true,[290]=true,[291]=true,[292]=true,[293]=true,[294]=true,[295]=true,
    [296]=true,[297]=true,[298]=true,[299]=true,[300]=true,[301]=true,
    [385]=true,[386]=true,[387]=true,[388]=true,[389]=true,[390]=true,[391]=true,[392]=true,
    [393]=true,[394]=true,[395]=true,[396]=true,[397]=true,
    [767]=true,[768]=true,[769]=true,[770]=true,
}
local has_skills, skills = pcall(require, 'skills')
if not has_skills then skills = nil end


local defaults = {
    center_x = 1475,
    center_y = 850,
    ws_size = 36,
    dmg_size = 42,
    avg_size = 24,
    flair_size = 32,
    line_gap = 45,
    avg_gap = 99,
    flair_gap = 100,
    font = 'Highwind',
    stroke_width = 4,
    big_stroke_width = 5,
    pending_timeout = 1.25,
    flair_duration = 2.5,
    fade_enabled = true,
    fade_in_duration = 0.30,
    hold_duration = 60.0,
    fade_out_duration = 5,
    pop_enabled = true,
    pop_duration = 0.35,
    pop_bonus_size = 8,
    auto_reset = true,
    flair_fade_duration = 1.5,
    flair_shrink_size = 6,
    flair_float_distance = 32,
    flair_anchor_ratio = 0.72,
    sc_anchor_ratio = 0.48,
    flair_offset_y = -6,
    whiff_shake_duration = 0.45,
    whiff_shake_strength = 6,
    sc_enabled = true,
    sc_window = 4.0,
    sc_fade_duration = 4,
    sc_float_distance = 28,
    sc_gap = 68,
    sc_size = 34,
    sc_offset_y = 32,
    sc_bar_enabled = true,
    sc_bar_gap = 132,
    sc_bar_size = 18,
    sc_bar_width = 18,
    sc_bar_label_size = 15,
    sc_bar_label_overlap = 20,
    sc_bar_delay = 3.0,
    sc_bar_max_step = 5,
    sc_bar_font = 'Consolas',
    sc_bar_shake_duration = 0.35,
    sc_bar_shake_strength = 5,
    sc_chain_counter_enabled = true,
    sc_chain_counter_size = 18,
    sc_chain_counter_gap = 6,
    sc_chain_info_enabled = true,
    sc_chain_info_size = 20,
    sc_chain_info_gap = 175,
    sc_chain_info_duration = 5.0,
    sc_chain_info_offset_y = 4,
    sc_chain_info_shake_duration = 0.75,
    sc_chain_info_shake_strength = 8,
    mb_enabled = true,
    mb_size = 24,
    mb_duration = 3.0,
    mb_fade_in_duration = 0.15,
    mb_fade_out_duration = 0.35,
    mb_offset_x = 95,
    mb_offset_y = -31,
    mb_shake_duration = 0.50,
    mb_shake_strength = 5,
    -- Treat different WS packets on the same target inside this tiny window as
    -- one simultaneous burst. Exact duplicates are still ignored, but different
    -- alts/actions inside the burst can break/reset Chain instead of stacking it.
    sc_bar_burst_window = 0.45,
}


local settings = config.load(defaults)
if settings.auto_reset == nil then settings.auto_reset = true end

local last_ws = '-'
local last_dmg = '-'
local last_raw_dmg = 0
local total_ws_damage = 0
local total_ws_count = 0
local avg_dmg = '-'
local recent_ws = {}
local avg_trend = ''
local avg_trend_color = {255, 255, 255}
local pending_ws = nil
local pending_time = 0
local debug_mode = false
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
local sc_bar_active = false
local sc_bar_open_time = 0
local sc_bar_close_time = 0
local sc_bar_total_window = 0
local sc_bar_total_delay = 0
local sc_bar_step = 1
local sc_bar_last_ws_time = 0
local sc_chain_step = 1
local sc_bar_target_id = nil
local sc_bar_last_action_id = nil
local sc_bar_last_actor_id = nil
local sc_bar_last_action_time = 0
local sc_bar_damage_update_guard_until = 0
local sc_bar_was_waiting = false
local sc_bar_shake_start = 0
local sc_chain_count = 0
local sc_chain_counter_visible = false
local sc_chain_info_visible = false
local sc_chain_info_fading = false
local sc_chain_info_fade_start = 0
local sc_chain_info_expire = 0
local sc_chain_info_prefix_value = ''
local sc_chain_info_name_value = ''
local sc_chain_info_elements_value = ''
local sc_chain_info_shake_start = 0
local sc_chain_info_color = {255, 255, 255}
local mb_visible = false
local mb_start_time = 0
local mb_expire = 0
local mb_value = ''
local mb_pending_until = 0
local mb_shake_start = 0


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
	['Fast Blade II'] = true,
	['Dragon Blow'] = true,
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
            draggable = false,
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
local avg_trend_text = texts.new('', text_settings(settings.avg_size))
local sc_text = texts.new('', text_settings(settings.sc_size or settings.avg_size))
local sc_bar_text = texts.new('', text_settings(settings.sc_bar_size or settings.avg_size))
local sc_bar_label_text = texts.new('', text_settings(settings.sc_bar_label_size or 15))
local sc_bar_status_text = texts.new('', text_settings(settings.sc_bar_label_size or 15))
local sc_chain_counter_text = texts.new('', text_settings(settings.sc_chain_counter_size or 18))
local sc_chain_info_text = texts.new('', text_settings(settings.sc_chain_info_size or 20))
local sc_chain_info_name_text = texts.new('', text_settings(settings.sc_chain_info_size or 20))
local sc_chain_info_elements_text = texts.new('', text_settings(settings.sc_chain_info_size or 20))
local mb_text = texts.new('', text_settings(settings.mb_size or 18))
local flair_text = texts.new('', text_settings(settings.flair_size))

-- Start hidden on addon load. The overlay appears after the first tracked WS,
-- or manually with //cw show.
ws_text:hide()
dmg_text:hide()
avg_text:hide()
avg_label_text:hide()
avg_value_text:hide()
avg_trend_text:hide()
sc_text:hide()
sc_bar_text:hide()
sc_bar_label_text:hide()
sc_bar_status_text:hide()
sc_chain_counter_text:hide()
sc_chain_info_text:hide()
sc_chain_info_name_text:hide()
sc_chain_info_elements_text:hide()
mb_text:hide()
flair_text:hide()

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
    avg_trend_text:alpha(alpha)
    if sc_visible and not sc_fading then
        sc_text:alpha(alpha)
    end
    if sc_bar_active then
        sc_bar_text:alpha(alpha)
        sc_bar_label_text:alpha(alpha)
        sc_bar_status_text:alpha(alpha)
    end
    if sc_chain_counter_visible then
        sc_chain_counter_text:alpha(alpha)
    end
    if sc_chain_info_visible and not sc_chain_info_fading then
        sc_chain_info_text:alpha(alpha)
        sc_chain_info_name_text:alpha(alpha)
        sc_chain_info_elements_text:alpha(alpha)
    end
    if mb_visible then
        mb_text:alpha(alpha)
    end
    if not flair_fading then
        flair_text:alpha(alpha)
    end

    ws_text:stroke_alpha(alpha)
    dmg_text:stroke_alpha(alpha)
    avg_text:stroke_alpha(alpha)
    avg_label_text:stroke_alpha(alpha)
    avg_value_text:stroke_alpha(alpha)
    avg_trend_text:stroke_alpha(alpha)
    if sc_visible and not sc_fading then
        sc_text:stroke_alpha(alpha)
    end
    if sc_bar_active then
        sc_bar_text:stroke_alpha(alpha)
        sc_bar_label_text:stroke_alpha(alpha)
        sc_bar_status_text:stroke_alpha(alpha)
    end
    if sc_chain_counter_visible then
        sc_chain_counter_text:stroke_alpha(alpha)
    end
    if sc_chain_info_visible and not sc_chain_info_fading then
        sc_chain_info_text:stroke_alpha(alpha)
        sc_chain_info_name_text:stroke_alpha(alpha)
        sc_chain_info_elements_text:stroke_alpha(alpha)
    end
    if mb_visible then
        mb_text:stroke_alpha(alpha)
    end
    if not flair_fading then
        flair_text:stroke_alpha(alpha)
    end

    if alpha <= 0 then
        ws_text:hide()
        dmg_text:hide()
        avg_text:hide()
        avg_label_text:hide()
        avg_value_text:hide()
        avg_trend_text:hide()
        sc_text:hide()
        sc_bar_text:hide()
        sc_bar_label_text:hide()
        sc_bar_status_text:hide()
        sc_chain_counter_text:hide()
        sc_chain_info_text:hide()
        sc_chain_info_name_text:hide()
        sc_chain_info_elements_text:hide()
        mb_text:hide()
        flair_text:hide()
            else
        ws_text:show()
        dmg_text:show()
        avg_text:show()
        avg_label_text:show()
        avg_value_text:show()
        if avg_trend ~= '' then
            avg_trend_text:show()
        else
            avg_trend_text:hide()
        end
        if sc_visible then
            sc_text:show()
        end
        if sc_bar_active then
            sc_bar_text:show()
            sc_bar_label_text:show()
            sc_bar_status_text:show()
        end
        if sc_chain_counter_visible then
            sc_chain_counter_text:show()
        end
        if sc_chain_info_visible then
            sc_chain_info_text:show()
            sc_chain_info_name_text:show()
            if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
        end
        if mb_visible then
            mb_text:show()
        else
            mb_text:hide()
        end
        if flair_visible then
            flair_text:show()
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
    if avg_trend ~= '' then avg_trend_text:show() else avg_trend_text:hide() end
    if sc_visible then sc_text:show() end
    if sc_bar_active then
        sc_bar_text:show()
        sc_bar_label_text:show()
        sc_bar_status_text:show()
    end
    if sc_chain_counter_visible then
        sc_chain_counter_text:show()
    end
    if sc_chain_info_visible then
        sc_chain_info_text:show()
        sc_chain_info_name_text:show()
        if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
    end
    if mb_visible then
        mb_text:show()
    end

    ws_text:alpha(255)
    ws_text:stroke_alpha(255)

    avg_text:alpha(255)
    avg_text:stroke_alpha(255)
    avg_label_text:alpha(255)
    avg_label_text:stroke_alpha(255)
    avg_value_text:alpha(255)
    avg_value_text:stroke_alpha(255)
    avg_trend_text:alpha(255)
    avg_trend_text:stroke_alpha(255)
    if sc_visible and not sc_fading then
        sc_text:alpha(255)
        sc_text:stroke_alpha(255)
    end
    if sc_bar_active then
        sc_bar_text:alpha(255)
        sc_bar_text:stroke_alpha(255)
        sc_bar_label_text:alpha(255)
        sc_bar_label_text:stroke_alpha(255)
        sc_bar_status_text:alpha(255)
        sc_bar_status_text:stroke_alpha(255)
    end
    if sc_chain_counter_visible then
        sc_chain_counter_text:alpha(255)
        sc_chain_counter_text:stroke_alpha(255)
    end
    if sc_chain_info_visible and not sc_chain_info_fading then
        sc_chain_info_text:alpha(255)
        sc_chain_info_text:stroke_alpha(255)
        sc_chain_info_name_text:alpha(255)
        sc_chain_info_name_text:stroke_alpha(255)
        sc_chain_info_elements_text:alpha(255)
        sc_chain_info_elements_text:stroke_alpha(255)
    end
    if mb_visible then
        mb_text:alpha(255)
        mb_text:stroke_alpha(255)
    end

    dmg_text:alpha(1)
    dmg_text:stroke_alpha(1)


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
        return 180, 100, 255, settings.big_stroke_width, cranked_flair_text
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

    local value_width = safe_extents(avg_value_text)
    avg_trend_text:pos(math.floor(ws_x + label_width + value_width + 8), y - 5)

    -- Legacy avg_text is kept hidden/unused so older settings/layout logic stays harmless.
    avg_text:hide()
end


local position_sc_chain_counter

local function position_sc_bar_line()
    local y = settings.center_y + (settings.sc_bar_gap or ((settings.avg_gap or 99) + 34))
    local bar_width = safe_extents(sc_bar_text)

    -- Keep the bar left-aligned with the Last WS line instead of centered
    -- under the whole overlay.
    local x = ws_text:pos()

    -- Tiny shake when the bar changes from WAIT to GO.
    local shake_x = 0
    if sc_bar_shake_start and sc_bar_shake_start > 0 then
        local t = (os.clock() - sc_bar_shake_start) / math.max(settings.sc_bar_shake_duration or 0.35, 0.01)
        if t >= 1 then
            sc_bar_shake_start = 0
        else
            shake_x = math.floor(math.sin(t * 60) * (settings.sc_bar_shake_strength or 5) * (1 - t))
        end
    end

    x = math.floor(x + shake_x)
    sc_bar_text:pos(x, y)

    -- Center the combined "Bonus Chance:" + status text across the actual bar width.
    local label_width = safe_extents(sc_bar_label_text)
    local status_width = safe_extents(sc_bar_status_text)
    local total_width = label_width + status_width
    local label_x = math.floor(x + (bar_width / 2) - (total_width / 2))
    local label_y = math.floor(y + (settings.sc_bar_label_overlap or 20))

    sc_bar_label_text:pos(label_x, label_y)
    sc_bar_status_text:pos(math.floor(label_x + label_width), label_y)

    if sc_chain_counter_visible then
        position_sc_chain_counter()
    end
end


local function position_mb_text()
    local x, y
    local mb_width = safe_extents(mb_text)

    if sc_bar_active then
        -- Put MB directly over the SC bar itself, centered on the bar.
        local bar_x, bar_y = sc_bar_text:pos()
        local bar_width = safe_extents(sc_bar_text)
        x = math.floor(bar_x + (bar_width / 2) - (mb_width / 2) + (settings.mb_offset_x or 0))
        y = math.floor(bar_y + (settings.mb_offset_y or -4))
    else
        -- Test/fallback location: approximate the SC bar lane, but a little higher
        -- than the old fallback so //cw testmb does not appear far below the HUD.
        x = math.floor(settings.center_x - (mb_width / 2) + (settings.mb_offset_x or 0))
        y = math.floor(settings.center_y + (settings.sc_bar_gap or ((settings.avg_gap or 99) + 34)) + (settings.mb_offset_y or -4))
    end

    local shake_x = 0
    if mb_shake_start and mb_shake_start > 0 then
        local t = (os.clock() - mb_shake_start) / math.max(settings.mb_shake_duration or 0.50, 0.01)
        if t >= 1 then
            mb_shake_start = 0
        else
            shake_x = math.floor(math.sin(t * 80) * (settings.mb_shake_strength or 5) * (1 - t))
        end
    end

    mb_text:pos(x + shake_x, y)
end

position_sc_chain_counter = function()
    if not settings.sc_bar_enabled or not settings.sc_chain_counter_enabled then return end

    local bar_x, bar_y = sc_bar_text:pos()
    local label_x, label_y = sc_bar_label_text:pos()
    local label_width = safe_extents(sc_bar_label_text)
    local status_width = safe_extents(sc_bar_status_text)

    -- Put Chain just to the right of "Bonus Chance: GO!!" / "Wait. . .",
    -- still sitting in the same lower-overlap lane on the SC bar.
    -- Positive values move it farther right; negative values pull it closer.
    local x = math.floor(label_x + label_width + status_width + (settings.sc_chain_counter_gap or 6))
    local y = math.floor(label_y)
    sc_chain_counter_text:pos(x, y)
end


local main_overlay_visible

local function normalize_sc_name(name)
    name = tostring(name or '')
    name = name:gsub('_', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or name == 'unknown' then
        return 'Skillchain'
    end
    return name
end

local function sc_name_from_add_effect(add_eff)
    if not add_eff then return 'Skillchain' end
    local name = add_eff.animation or add_eff.name or add_eff.param or add_eff.message
    return normalize_sc_name(name)
end

local SC_ELEMENT_COLORS = {
    Fire     = {255,  70,  70},   -- Red
    Ice      = {120, 220, 255},   -- Light Blue
    Water    = { 45,  95, 255},   -- Dark Blue
    Darkness = {180, 100, 255},   -- Purple
    Light    = {245, 245, 220},   -- Pearl
    Thunder  = {205, 145, 255},   -- Light Purple
    Wind     = {100, 255, 100},   -- Green
    Earth    = {230, 210,  80},   -- Bright yellow with slight brown tinge
}

local SC_ELEMENTS = {
    Liquefaction  = "Fire",
    Induration    = "Ice",
    Reverberation = "Water",
    Detonation    = "Wind",
    Scission      = "Earth",
    Impaction     = "Thunder",
    Transfixion   = "Light",
    Compression   = "Dark.",

    Fusion        = "Fire/Light",
    Fragmentation = "Wind/Thund.",
    Distortion    = "Ice/Water",
    Gravitation   = "Earth/Dark.",

    Light         = "Fire/Wind/Thund./Light",
    Darkness      = "Earth/Water/Ice/Dark.",

    Radiance      = "Fire/Wind/Thund./Light",
    Umbra         = "Earth/Water/Ice/Dark.",
}

local function sc_elements_for_name(name)
    -- The packet/add_effect name can vary by casing, spacing, or include extra text.
    -- Match the same flexible way as the color function instead of requiring
    -- an exact table key like "Fusion".
    local clean = normalize_sc_name(name):gsub('%s*%b()%s*$', '')
    local exact = SC_ELEMENTS[clean]
    if exact then return exact end

    local key = tostring(clean or ''):lower():gsub('%s+', '')

    -- Level 4 first, so Radiance/Umbra are not swallowed by Light/Darkness checks.
    if key:find('radiance') then return SC_ELEMENTS.Radiance end
    if key:find('umbra') then return SC_ELEMENTS.Umbra end

    -- Level 2 before Level 3/1 broad words.
    if key:find('fusion') then return SC_ELEMENTS.Fusion end
    if key:find('fragmentation') then return SC_ELEMENTS.Fragmentation end
    if key:find('distortion') then return SC_ELEMENTS.Distortion end
    if key:find('gravitation') then return SC_ELEMENTS.Gravitation end

    -- Level 1
    if key:find('liquefaction') then return SC_ELEMENTS.Liquefaction end
    if key:find('induration') then return SC_ELEMENTS.Induration end
    if key:find('reverberation') then return SC_ELEMENTS.Reverberation end
    if key:find('detonation') then return SC_ELEMENTS.Detonation end
    if key:find('scission') then return SC_ELEMENTS.Scission end
    if key:find('impaction') then return SC_ELEMENTS.Impaction end
    if key:find('transfixion') then return SC_ELEMENTS.Transfixion end
    if key:find('compression') then return SC_ELEMENTS.Compression end

    -- Level 3 last because these names are broad.
    if key:find('darkness') then return SC_ELEMENTS.Darkness end
    if key:find('light') then return SC_ELEMENTS.Light end

    return nil
end

local function blend_sc_colors(...)
    local names = {...}
    local r, g, b, count = 0, 0, 0, 0

    for _, name in ipairs(names) do
        local c = SC_ELEMENT_COLORS[name]
        if c then
            r = r + c[1]
            g = g + c[2]
            b = b + c[3]
            count = count + 1
        end
    end

    if count <= 0 then
        return 255, 255, 255
    end

    return math.floor(r / count), math.floor(g / count), math.floor(b / count)
end

local function sc_color_for_name(name)
    local key = tostring(name or ''):lower():gsub('%s+', '')

    -- Level 3 / 4
    if key:find('radiance') then return unpack(SC_ELEMENT_COLORS.Light) end
    if key:find('umbra') then return unpack(SC_ELEMENT_COLORS.Darkness) end
    if key:find('darkness') then return unpack(SC_ELEMENT_COLORS.Darkness) end
    if key:find('light') then return unpack(SC_ELEMENT_COLORS.Light) end

    -- Level 2 multi-element skillchains. Text objects cannot gradient,
    -- so these use a blended version of the requested element colors.
    if key:find('fusion') then return blend_sc_colors('Fire', 'Light') end
    if key:find('fragmentation') then return blend_sc_colors('Wind', 'Thunder') end
    if key:find('distortion') then return blend_sc_colors('Ice', 'Water') end
    if key:find('gravitation') then return blend_sc_colors('Earth', 'Darkness') end

    -- Level 1
    if key:find('liquefaction') then return unpack(SC_ELEMENT_COLORS.Fire) end
    if key:find('scission') then return unpack(SC_ELEMENT_COLORS.Earth) end
    if key:find('reverberation') then return unpack(SC_ELEMENT_COLORS.Water) end
    if key:find('detonation') then return unpack(SC_ELEMENT_COLORS.Wind) end
    if key:find('induration') then return unpack(SC_ELEMENT_COLORS.Ice) end
    if key:find('impaction') then return unpack(SC_ELEMENT_COLORS.Thunder) end
    if key:find('transfixion') then return unpack(SC_ELEMENT_COLORS.Light) end
    if key:find('compression') then return unpack(SC_ELEMENT_COLORS.Darkness) end

    return 255, 255, 255
end

local function position_sc_chain_info()
    local x = ws_text:pos()
    local y = settings.center_y + (settings.sc_chain_info_gap or 175) + (settings.sc_chain_info_offset_y or 4)

    -- Radiance / Umbra impact shake. Applies to the whole Chain Info line:
    -- prefix, colored skillchain name, and white element suffix.
    local shake_x = 0
    if sc_chain_info_shake_start and sc_chain_info_shake_start > 0 then
        local t = (os.clock() - sc_chain_info_shake_start) / math.max(settings.sc_chain_info_shake_duration or 0.75, 0.01)
        if t >= 1 then
            sc_chain_info_shake_start = 0
        else
            shake_x = math.floor(math.sin(t * 80) * (settings.sc_chain_info_shake_strength or 8) * (1 - t))
        end
    end

    x = math.floor(x + shake_x)
    sc_chain_info_text:pos(x, y)

    local prefix_width = safe_extents(sc_chain_info_text)
    local name_x = math.floor(x + prefix_width + 4)
    sc_chain_info_name_text:pos(name_x, y)

    local name_width = safe_extents(sc_chain_info_name_text)
    sc_chain_info_elements_text:pos(math.floor(name_x + name_width), y)
end
local function hide_sc_chain_info()
    sc_chain_info_visible = false
    sc_chain_info_fading = false
    sc_chain_info_fade_start = 0
    sc_chain_info_expire = 0
    sc_chain_info_text:hide()
    sc_chain_info_name_text:hide()
    sc_chain_info_elements_text:hide()
end

local function start_sc_chain_info_fade()
    if sc_chain_info_visible and not sc_chain_info_fading then
        -- Chain info should fade as soon as the live Chain counter disappears.
        sc_chain_info_expire = 0
        sc_chain_info_fading = true
        sc_chain_info_fade_start = os.clock()
    end
end

-- Compatibility aliases for existing call sites.
local function start_sc_chain_info_break_fade()
    start_sc_chain_info_fade()
end

local function start_sc_chain_info_timeout_fade()
    start_sc_chain_info_fade()
end

local function show_sc_chain_info(chain_num, sc_name)
    if not settings.sc_bar_enabled or not settings.sc_chain_info_enabled then return end
    if not main_overlay_visible() then return end

    chain_num = math.max(1, tonumber(chain_num) or 1)
    sc_name = normalize_sc_name(sc_name)
    local r, g, b = sc_color_for_name(sc_name)

    sc_chain_info_prefix_value = 'Chain ' .. tostring(chain_num) .. ':'
    local clean_sc_name = sc_name:gsub('%s*%b()%s*$', '')
    local elements = sc_elements_for_name(clean_sc_name)

    local clean_key = tostring(clean_sc_name or ''):lower():gsub('%s+', '')
    if clean_key:find('radiance') or clean_key:find('umbra') then
        sc_chain_info_shake_start = os.clock()
    else
        sc_chain_info_shake_start = 0
    end

    sc_chain_info_name_value = clean_sc_name
    if elements then
        sc_chain_info_elements_value = string.format(' (%s)', elements)
    else
        sc_chain_info_elements_value = ''
    end
    sc_chain_info_color = {r, g, b}

    sc_chain_info_text:text(sc_chain_info_prefix_value)
    sc_chain_info_text:font(settings.font or 'Highwind')
    sc_chain_info_text:size(settings.sc_chain_info_size or 20)
    sc_chain_info_text:color(255, 255, 255)
    sc_chain_info_text:stroke_width(settings.stroke_width)
    sc_chain_info_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_info_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_chain_info_name_text:text(sc_chain_info_name_value)
    sc_chain_info_name_text:font(settings.font or 'Highwind')
    sc_chain_info_name_text:size(settings.sc_chain_info_size or 20)
    sc_chain_info_name_text:color(r, g, b)
    sc_chain_info_name_text:stroke_width(settings.stroke_width)
    sc_chain_info_name_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_info_name_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_chain_info_elements_text:text(sc_chain_info_elements_value)
    sc_chain_info_elements_text:font(settings.font or 'Highwind')
    sc_chain_info_elements_text:size(settings.sc_chain_info_size or 20)
    sc_chain_info_elements_text:color(255, 255, 255)
    sc_chain_info_elements_text:stroke_width(settings.stroke_width)
    sc_chain_info_elements_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_info_elements_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_chain_info_visible = true
    sc_chain_info_fading = false
    sc_chain_info_fade_start = 0
    sc_chain_info_expire = 0

    position_sc_chain_info()
    sc_chain_info_text:show()
    sc_chain_info_name_text:show()
    if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
end

main_overlay_visible = function()
    -- The SC bar should not summon CrankWatch by itself.
    -- It should only display once CrankWatch is already visible or fading in
    -- because the Last WS / damage GUI updated.
    return fade_state ~= 'hidden' and alpha_current > 0
end

local function make_sc_bar(percent)
    local width = math.max(6, math.floor(settings.sc_bar_width or 34))
    percent = clamp(percent or 0, 0, 1)
    local filled = math.floor((width * percent) + 0.5)
    local empty = width - filled
    return string.rep('█', filled) .. string.rep('░', empty)
end

local stop_sc_bar
-- Forward declarations: these functions are called by helpers defined below
-- before their implementations appear later in the file. Without these, Lua
-- resolves the early calls as globals and raises a nil-value runtime error.
local update_display
local request_layout_refresh

local function start_sc_bar_from_time(base_time, step, target_id, action_id, actor_id, delay_override)
    if not settings.sc_bar_enabled then return end

    -- When packet listening is available, never create a targetless bar.
    -- Targetless bars are the main reason the countdown can linger after a mob dies.
    if sc_packet_bar_enabled and not target_id then return end

    if target_id then
        local mob = windower.ffxi.get_mob_by_id(target_id)
        if not mob or (tonumber(mob.hpp) or 0) <= 0 then
            stop_sc_bar(true)
            return
        end
    end

    base_time = base_time or os.clock()
    step = clamp(math.floor(step or 1), 1, settings.sc_bar_max_step or 5)

    local delay = tonumber(delay_override) or tonumber(settings.sc_bar_delay) or 3.0
    local duration = math.max(1.0, 8.0 - step)

    sc_bar_step = step
    sc_bar_last_ws_time = base_time
    sc_bar_target_id = target_id or sc_bar_target_id
    sc_bar_last_action_id = action_id or sc_bar_last_action_id
    sc_bar_last_actor_id = actor_id or sc_bar_last_actor_id
    sc_bar_last_action_time = base_time
    sc_bar_open_time = base_time + delay
    sc_bar_close_time = sc_bar_open_time + duration
    sc_bar_total_window = duration
    sc_bar_total_delay = math.max(delay, 0.01)
    sc_bar_active = true

    sc_bar_text:font(settings.sc_bar_font or 'Consolas')
    sc_bar_text:size(settings.sc_bar_size or settings.avg_size)
    sc_bar_text:stroke_width(settings.stroke_width)
    sc_bar_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_label_text:font(settings.font or 'Highwind')
    sc_bar_label_text:size(settings.sc_bar_label_size or 15)
    sc_bar_label_text:stroke_width(settings.stroke_width)
    sc_bar_label_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_label_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_status_text:font(settings.font or 'Highwind')
    sc_bar_status_text:size(settings.sc_bar_label_size or 15)
    sc_bar_status_text:stroke_width(settings.stroke_width)
    sc_bar_status_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_status_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_chain_counter_text:font(settings.font or 'Highwind')
    sc_chain_counter_text:size(settings.sc_chain_counter_size or 18)
    sc_chain_counter_text:stroke_width(settings.stroke_width)
    sc_chain_counter_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_counter_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_was_waiting = true
    sc_bar_shake_start = 0

    if main_overlay_visible() then
        sc_bar_text:show()
        sc_bar_label_text:show()
        sc_bar_status_text:show()
    else
        sc_bar_text:hide()
        sc_bar_label_text:hide()
        sc_bar_status_text:hide()
        sc_chain_counter_text:hide()
    end
end

local function test_sc_bar_default()
    if not settings.sc_bar_enabled then return end

    local now = os.clock()
    local delay = tonumber(settings.sc_bar_delay) or 3.0
    local duration = math.max(1.0, 8.0 - 1)

    sc_bar_step = 1
    sc_bar_last_ws_time = now
    sc_bar_target_id = nil
    sc_bar_last_action_id = nil
    sc_bar_last_actor_id = nil
    sc_bar_last_action_time = now
    sc_bar_open_time = now + delay
    sc_bar_close_time = sc_bar_open_time + duration
    sc_bar_total_window = duration
    sc_bar_total_delay = math.max(delay, 0.01)
    sc_bar_active = true
    -- Test command should visibly display the bar even without a real WS update.
    fade_state = 'visible'
    alpha_current = 255
    last_ws_time = os.clock()

    ws_text:show()
    dmg_text:show()
    avg_label_text:show()
    avg_value_text:show()

    ws_text:alpha(255)
    ws_text:stroke_alpha(255)
    dmg_text:alpha(255)
    dmg_text:stroke_alpha(255)
    avg_label_text:alpha(255)
    avg_label_text:stroke_alpha(255)
    avg_value_text:alpha(255)
    avg_value_text:stroke_alpha(255)


    sc_bar_text:font(settings.sc_bar_font or 'Consolas')
    sc_bar_text:size(settings.sc_bar_size or settings.avg_size)
    sc_bar_text:stroke_width(settings.stroke_width)
    sc_bar_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_label_text:font(settings.font or 'Highwind')
    sc_bar_label_text:size(settings.sc_bar_label_size or 15)
    sc_bar_label_text:stroke_width(settings.stroke_width)
    sc_bar_label_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_label_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_status_text:font(settings.font or 'Highwind')
    sc_bar_status_text:size(settings.sc_bar_label_size or 15)
    sc_bar_status_text:stroke_width(settings.stroke_width)
    sc_bar_status_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_bar_status_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_chain_counter_text:font(settings.font or 'Highwind')
    sc_chain_counter_text:size(settings.sc_chain_counter_size or 18)
    sc_chain_counter_text:stroke_width(settings.stroke_width)
    sc_chain_counter_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_counter_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)

    sc_bar_was_waiting = true
    sc_bar_shake_start = 0

    sc_bar_text:show()
    sc_bar_label_text:show()
    sc_bar_status_text:show()

    update_display()
    request_layout_refresh(0.45)
end

stop_sc_bar = function(reset_step, reason)
    sc_bar_active = false
    sc_bar_open_time = 0
    sc_bar_close_time = 0
    sc_bar_total_window = 0
    sc_bar_total_delay = 0
    sc_bar_target_id = nil
    sc_bar_last_action_id = nil
    sc_bar_last_actor_id = nil
    sc_bar_last_action_time = 0
    sc_bar_damage_update_guard_until = 0
    sc_bar_was_waiting = false
    sc_bar_shake_start = 0
    sc_bar_text:hide()
    sc_bar_label_text:hide()
    sc_bar_status_text:hide()
    if reset_step then
        sc_chain_step = 1
        sc_bar_step = 1
        sc_chain_count = 0
        sc_chain_counter_visible = false
        sc_chain_counter_text:hide()
        start_sc_chain_info_fade()
    end
end


local function get_current_battle_target_id()
    local targ = windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_mob_by_target('bt')
    return targ and targ.id or nil
end

local function is_current_battle_target_id(target_id)
    target_id = tonumber(target_id)
    if not target_id then return false end

    local current_id = tonumber(get_current_battle_target_id())
    return current_id ~= nil and current_id == target_id
end

local function stop_sc_bar_if_target_changed()
    if not sc_bar_active or not sc_bar_target_id then return false end

    if not is_current_battle_target_id(sc_bar_target_id) then
        stop_sc_bar(true, 'target_changed')
        sc_window_until = 0
        sc_armed = false
        return true
    end

    return false
end

local function stop_sc_bar_if_target_dead()
    if not sc_bar_active or not sc_bar_target_id then return false end

    local mob = windower.ffxi.get_mob_by_id(sc_bar_target_id)
    if not mob or (tonumber(mob.hpp) or 0) <= 0 then
        stop_sc_bar(true)
        sc_window_until = 0
        sc_armed = false
        return true
    end

    return false
end

local function update_sc_bar()
    if not sc_bar_active then return end
    if stop_sc_bar_if_target_changed() then return end
    if stop_sc_bar_if_target_dead() then return end

    local now = os.clock()
    if now >= sc_bar_close_time then
        stop_sc_bar(true, 'timeout')
        return
    end

    if now < sc_bar_open_time then
        local wait_remaining = sc_bar_open_time - now
        local wait_percent = wait_remaining / math.max(sc_bar_total_delay, 0.01)
        sc_bar_was_waiting = true
        sc_bar_text:color(255, 70, 70)
        sc_bar_text:text(make_sc_bar(wait_percent))
        sc_bar_label_text:color(255, 255, 255)
        sc_bar_label_text:text('SC Window: ')
        sc_bar_status_text:color(255, 40, 40)
        sc_bar_status_text:text('Wait. . .')
    else
        local remaining = sc_bar_close_time - now
        local percent = remaining / math.max(sc_bar_total_window, 0.01)
        if sc_bar_was_waiting then
            sc_bar_was_waiting = false
            sc_bar_shake_start = os.clock()
        end
        sc_bar_text:color(80, 255, 120)
        sc_bar_text:text(make_sc_bar(percent))
        sc_bar_label_text:color(255, 255, 255)
        sc_bar_label_text:text('SC Window: ')
        sc_bar_status_text:color(80, 255, 80)
        sc_bar_status_text:text('GO!!')
    end

    position_sc_bar_line()
    if mb_visible then
        position_mb_text()
    end

    if main_overlay_visible() then
        sc_bar_text:show()
        sc_bar_label_text:show()
        sc_bar_status_text:show()
        if sc_chain_counter_visible then
            sc_chain_counter_text:show()
        end
        if sc_chain_info_visible then
            sc_chain_info_text:show()
            sc_chain_info_name_text:show()
            if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
        end
        if mb_visible then mb_text:show() end
    else
        sc_bar_text:hide()
        sc_bar_label_text:hide()
        sc_bar_status_text:hide()
        sc_chain_counter_text:hide()
        sc_chain_info_text:hide()
        sc_chain_info_name_text:hide()
        sc_chain_info_elements_text:hide()
        mb_text:hide()
    end
end

request_layout_refresh = function(duration)
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

local function update_avg_trend()
    -- Trend arrow compares recent successful WS against the prior baseline.
    -- It starts after 10 successful non-whiff WS so the baseline is more meaningful
    -- during normal testing, then naturally grows into the intended
    -- last-5-versus-previous-20 comparison once 25 WS are available.
    local n = #recent_ws
    if n < 10 then
        avg_trend = ''
        avg_trend_color = {255, 255, 255}
        return
    end

    local recent_count = math.min(5, math.floor(n / 2))
    local previous_count = math.min(20, n - recent_count)
    local recent_sum = 0
    local previous_sum = 0

    for i = n - recent_count + 1, n do
        recent_sum = recent_sum + (recent_ws[i] or 0)
    end

    for i = n - recent_count - previous_count + 1, n - recent_count do
        previous_sum = previous_sum + (recent_ws[i] or 0)
    end

    local recent_avg = recent_sum / math.max(recent_count, 1)
    local previous_avg = previous_sum / math.max(previous_count, 1)

    if recent_avg > previous_avg * 1.02 then
        avg_trend = '↑'
        avg_trend_color = {80, 255, 80}
    elseif recent_avg < previous_avg * 0.98 then
        avg_trend = '↓'
        avg_trend_color = {255, 80, 80}
    else
        avg_trend = '→'
        avg_trend_color = {255, 255, 255}
    end
end

local function apply_avg_trend_style()
    avg_trend_text:text(avg_trend or '')
    avg_trend_text:font('Consolas')
    avg_trend_text:size(settings.avg_size)
    avg_trend_text:color(avg_trend_color[1] or 255, avg_trend_color[2] or 255, avg_trend_color[3] or 255)
    avg_trend_text:stroke_width(settings.stroke_width)

    if avg_trend and avg_trend ~= '' and alpha_current > 0 and fade_state ~= 'hidden' then
        avg_trend_text:show()
    else
        avg_trend_text:hide()
    end
end

local function reset_average(silent)
    total_ws_damage = 0
    total_ws_count = 0
    avg_dmg = '-'
    recent_ws = {}
    avg_trend = ''
    avg_trend_color = {255, 255, 255}
    apply_avg_style(0)
    apply_avg_trend_style()
    update_display()
    request_layout_refresh(0.45)
    if not silent then
        windower.add_to_chat(200, '[CrankWatch] Average reset.')
    end
end

update_display = function()
    ws_text:text('Last WS: ' .. last_ws .. '!')

    local damage_line = last_dmg .. ' damage!!'
    if is_whiff then
        damage_line = 'WHIFF!!'
    end

    dmg_text:text(damage_line)
    avg_text:text('')
    avg_label_text:text('Avg: ')
    avg_value_text:text(avg_dmg)
    apply_avg_trend_style()

    position_line(ws_text, settings.center_y)
    if not whiff_shaking then
        position_line(dmg_text, settings.center_y + settings.line_gap)
    end


    position_avg_line()
    if sc_bar_active then
        position_sc_bar_line()
    elseif sc_chain_counter_visible then
        position_sc_chain_counter()
    end
    if sc_chain_info_visible then
        position_sc_chain_info()
    end
    if mb_visible then
        position_mb_text()
    end

    if flair_visible and not flair_fading then
        position_line(flair_text, settings.center_y + settings.flair_gap)
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
    update_display()
end

local function apply_damage_style(raw_dmg)
    local r, g, b, stroke, flair = get_damage_style(raw_dmg)

    dmg_text:color(r, g, b)
    dmg_text:stroke_width(stroke)

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
    --line = line:gsub('cr', '')
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
    -- Case-insensitive and slightly forgiving because Battlemod / big-chat
    -- formatting can vary in capitalization and punctuation.
    local l = tostring(line or ''):lower()
    return l:match('takes%s+([%d,]+)%s+points?%s+of%s+damage')
        or l:match('takes%s+([%d,]+)%s+damage')
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
end

local function normalize_mb_line(line)
    -- Avoid deleting the visible character after a Windower control byte.
    -- The older cleaner used \30. / \31., which can accidentally remove the
    -- first real letter of "Magic Burst!" if a control byte appears before it.
    local s = tostring(line or '')
    s = s:gsub('cs%(%d+,%d+,%d+%)', '')
    s = s:gsub('cr', '')
    s = s:gsub('\30', '')
    s = s:gsub('\31', '')
    s = s:gsub('%s+', ' ')
    return s
end

local function magic_burst_damage_from_line(line)
    if not line then return nil end

    local l = normalize_mb_line(line)
    local lower = l:lower()

    -- Be intentionally loose: control/color codes or Battlemod can split the
    -- exact phrase, but if the same incoming line has both words, treat it as MB.
    if not (lower:find('magic') and lower:find('burst')) then
        return nil
    end

    -- User-facing log shape:
    -- Magic Burst! The TARGET takes X points of damage.
    -- Lua patterns do not need to know the target; just grab X after "takes".
    local dmg = l:match('[Tt]akes%s+([%d,]+)')
        or l:match('[Tt]akes[^%d]+([%d,]+)')
        or l:match('([%d,]+)%s+points%s+of%s+damage')
        or l:match('([%d,]+)%s+point%s+of%s+damage')

    return dmg
end

local function position_sc_line(y)
    local width = safe_extents(sc_text)
    sc_text:pos(math.floor(settings.center_x - (width / 2)), y)
end

local function update_sc_chain_counter()
    if not settings.sc_chain_counter_enabled then return end
    if sc_chain_count <= 0 then
        sc_chain_counter_visible = false
        sc_chain_counter_text:hide()
        start_sc_chain_info_fade()
        return
    end

    sc_chain_counter_text:text('Chain: ' .. tostring(sc_chain_count))
    sc_chain_counter_text:font(settings.font or 'Highwind')
    sc_chain_counter_text:size(settings.sc_chain_counter_size or 18)
    sc_chain_counter_text:color(255, 255, 255)
    sc_chain_counter_text:stroke_width(settings.stroke_width)
    sc_chain_counter_text:alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_counter_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)
    sc_chain_counter_visible = true
    sc_chain_counter_text:show()

    if sc_bar_active then
        position_sc_chain_counter()
    end
end


local function start_mb_popup(dmg)
    if not settings.mb_enabled then return end

    local raw = clean_damage_number(dmg)
    -- Show MB even when damage is 0 so resisted/immune test targets still confirm detection.
    if raw < 0 then return end

    mb_value = 'MB: ' .. format_number(raw) .. '!!'
    mb_text:text(mb_value)
    mb_text:font(settings.font or 'Highwind')
    mb_text:size(settings.mb_size or 18)
    mb_text:color(255, 140, 255)
    mb_text:stroke_width(settings.stroke_width)
    mb_text:alpha(0)
    mb_text:stroke_alpha(0)

    mb_visible = true
    mb_start_time = os.clock()
    mb_shake_start = mb_start_time
    mb_expire = mb_start_time + (settings.mb_duration or 3.0)

    position_mb_text()
    mb_text:show()
end

local function start_sc_popup(dmg)
    if not settings.sc_enabled then return end

    -- Do not show SC Bonus if the main CrankWatch overlay is hidden.
    if not main_overlay_visible() then
        return
    end

    local raw = clean_damage_number(dmg)
    -- Show and count skillchains even when the SC damage is 0.
    -- This is useful for tracking chain progression and spotting immunity/resist behavior.
    if raw < 0 then return end

    sc_bonus_dmg = raw

    -- Chain count is packet-driven. The delayed chat-side SC damage line only
    -- displays the SC Bonus popup; it must not increment Chain or refill/re-time
    -- the countdown bar.

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

    -- Chain count/depth is packet-driven by the SC bar now.
    -- Chat-side SC damage should update the visible SC Bonus popup only.
    -- The countdown bar is packet-driven, so do NOT restart/refill the red WAIT bar here.
    -- Restarting from chat causes drift on longer chains because chat appears after
    -- the action packet timing already began.

    sc_armed = false
    sc_window_until = sc_packet_bar_enabled and (sc_bar_active and sc_bar_close_time or 0) or 0

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

        table.insert(recent_ws, raw_dmg)
        if #recent_ws > 25 then
            table.remove(recent_ws, 1)
        end
        update_avg_trend()

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

    -- Damage/chat UI updates happen slightly after the packet event that starts
    -- the WAIT bar. Some action-listener environments can surface a second
    -- WS-result style event at the same moment damage is reported. Guard that
    -- short period so the display update cannot indirectly refill the red bar.
    if sc_bar_active and os.clock() < (sc_bar_open_time or 0) then
        sc_bar_damage_update_guard_until = os.clock() + 0.90
    end

    -- Important: the SC countdown bar is packet-driven only.
    -- Damage/chat updates must never start, stop, refill, or retime the bar.
    -- Otherwise the red WAIT bar can begin from the action packet and then pop
    -- back to full when the delayed damage line updates the CrankWatch display.
    if sc_bar_active then
        sc_window_until = sc_bar_close_time
    end
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

windower.register_event('prerender', function()
    local now = os.clock()

    if layout_refresh_until > 0 then
        if now <= layout_refresh_until then
            update_display()
        else
            layout_refresh_until = 0
        end
    end

    update_sc_bar()

    if mb_visible then
        if now >= mb_expire then
            mb_visible = false
            mb_start_time = 0
            mb_expire = 0
            mb_value = ''
            mb_text:hide()
        else
            local fade_in = math.max(settings.mb_fade_in_duration or 0.15, 0.01)
            local fade_out = math.max(settings.mb_fade_out_duration or 0.35, 0.01)
            local elapsed = now - (mb_start_time or now)
            local remaining = mb_expire - now
            local a = 255

            if elapsed < fade_in then
                a = math.floor(255 * (elapsed / fade_in))
            elseif remaining < fade_out then
                a = math.floor(255 * (remaining / fade_out))
            end

            a = clamp(a, 0, 255)
            mb_text:alpha(a)
            mb_text:stroke_alpha(a)
            position_mb_text()
            mb_text:show()
        end
    end

    -- Hard link SC info visibility to the live Chain counter state.
    -- If the counter has disappeared/reset, the last SC info should fade too.
    if sc_chain_info_visible and not sc_chain_info_fading and sc_chain_count <= 0 and not sc_chain_counter_visible then
        start_sc_chain_info_fade()
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

    if sc_chain_info_visible then
        if not main_overlay_visible() then
            sc_chain_info_text:hide()
            sc_chain_info_name_text:hide()
            sc_chain_info_elements_text:hide()
        else
            position_sc_chain_info()
            if sc_chain_info_fading then
                local t = (now - sc_chain_info_fade_start) / 0.75
                if t >= 1 then
                    hide_sc_chain_info()
                else
                    local a = math.floor((alpha_current > 0 and alpha_current or 255) * (1 - t))
                    sc_chain_info_text:alpha(a)
                    sc_chain_info_text:stroke_alpha(a)
                    sc_chain_info_name_text:alpha(a)
                    sc_chain_info_name_text:stroke_alpha(a)
                    sc_chain_info_elements_text:alpha(a)
                    sc_chain_info_elements_text:stroke_alpha(a)
                    sc_chain_info_text:show()
                    sc_chain_info_name_text:show()
                    if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
                end
            elseif (sc_chain_info_expire or 0) > 0 and now >= (sc_chain_info_expire or 0) then
                sc_chain_info_fading = true
                sc_chain_info_fade_start = now
            else
                sc_chain_info_text:alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_name_text:alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_name_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_elements_text:alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_elements_text:stroke_alpha(alpha_current > 0 and alpha_current or 255)
                sc_chain_info_text:show()
                sc_chain_info_name_text:show()
                if sc_chain_info_elements_value ~= '' then sc_chain_info_elements_text:show() else sc_chain_info_elements_text:hide() end
            end
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
            update_display()
        else
            -- Ease back from enlarged to normal size.
            local eased = 1 - ((1 - t) * (1 - t))
            local size = math.floor((settings.dmg_size + settings.pop_bonus_size) - (settings.pop_bonus_size * eased))
            dmg_text:size(size)
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
        avg_trend_text:alpha(255)
        avg_trend_text:stroke_alpha(255)

        if t >= 1 then
            fade_state = 'visible'
            dmg_text:alpha(255)
            dmg_text:stroke_alpha(255)
        else
            local a = math.max(1, math.floor(255 * t))
            dmg_text:alpha(a)
            dmg_text:stroke_alpha(a)
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


local sc_action_categories = {
    weaponskill_finish = true,
    avatar_tp_finish = true,
}

local function get_action_delay(resource, action_id)
    if skills and resource and action_id and skills[resource] and skills[resource][action_id] then
        return skills[resource][action_id].delay or settings.sc_bar_delay or 3.0
    end
    return settings.sc_bar_delay or 3.0
end

local function is_valid_sc_bar_action(resource, action_id)
    -- Use the same style as Skillchains:
    -- action:get_spell() returns resource + action_id.
    -- A real player WS should resolve as skills.weapon_skills[action_id].
    if not skills or not resource or not action_id then
        return false
    end

    local ability = skills[resource] and skills[resource][action_id]
    if not ability then
        return false
    end

    if resource ~= 'weapon_skills' then
        return false
    end

    return ability.en and is_weapon_skill(ability.en)
end

local function party_member_id(member)
    if type(member) ~= 'table' then return nil end

    if member.mob and member.mob.id then
        return tonumber(member.mob.id)
    end

    return tonumber(member.id)
end

local function is_party_or_alliance_actor(actor_id)
    actor_id = tonumber(actor_id)
    if not actor_id then return false end

    local party = windower.ffxi.get_party()
    if not party then return false end

    -- Windower's party table includes p0-p5 and alliance slots when present.
    -- Iterating every table entry keeps this compatible with party-only and
    -- alliance layouts without needing to know the exact slot names.
    for _, member in pairs(party) do
        local member_id = party_member_id(member)
        if member_id and member_id == actor_id then
            return true
        end
    end

    -- Pet/avatar/automaton support: allow the action if the actor's owner is
    -- in the party/alliance. This keeps SMN/PUP/DRG pet TP actions from being
    -- filtered out while still blocking nearby strangers.
    local mob = windower.ffxi.get_mob_by_id(actor_id)
    local owner_id = mob and tonumber(mob.owner_id)
    if owner_id then
        for _, member in pairs(party) do
            local member_id = party_member_id(member)
            if member_id and member_id == owner_id then
                return true
            end
        end
    end

    return false
end

local function refresh_sc_bar_from_action(actor_id, target_id, resource, action_id, add_eff, conclusion)
    if not settings.sc_bar_enabled or not target_id then return end

    -- Only track WS/SC packets for the player's current battle target.
    -- Any party/alliance member can advance or break the chain, but only when
    -- their action is on the exact mob the local player is targeting.
    if not is_current_battle_target_id(target_id) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored SC packet on non-current target: ' .. tostring(target_id))
        end
        return
    end

    if not is_party_or_alliance_actor(actor_id) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored outside-party/alliance SC packet actor: ' .. tostring(actor_id))
        end
        return
    end

    local now = os.clock()

    -- Damage/chat UI updates happen after the packet event that starts the bar.
    -- If the action listener also sees a second WS-result style event during that
    -- brief UI update, do not let it refill the red WAIT bar.
    if sc_bar_active
        and now < (sc_bar_open_time or 0)
        and target_id == sc_bar_target_id
        and now <= (sc_bar_damage_update_guard_until or 0) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored damage-update WAIT duplicate for SC bar.')
        end
        return
    end

    local confirmed_sc = add_eff and conclusion and tonumber(add_eff.message_id) and SKILLCHAIN_IDS[tonumber(add_eff.message_id)]

    -- Catch exact duplicate events first. These are the same WS result being
    -- surfaced twice, not a real extra alt WS.
    local duplicate_window = 0.75
    local exact_duplicate = sc_bar_last_action_id == action_id
        and sc_bar_last_actor_id == actor_id
        and sc_bar_target_id == target_id
        and (now - (sc_bar_last_action_time or 0)) < duplicate_window

    if exact_duplicate then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Ignored exact duplicate WS packet for SC bar.')
        end
        return
    end

    -- If different WS packets hit the same target almost simultaneously, they are
    -- not duplicates. This is the Sortie Send-macro case: one WS may close a SC
    -- while another WS immediately interrupts/overwrites the chain state. In that
    -- situation, reset must win over counting additional Chain progress.
    local burst_window = settings.sc_bar_burst_window or 0.45
    local same_target_burst = sc_bar_active
        and sc_bar_target_id == target_id
        and (now - (sc_bar_last_action_time or 0)) < burst_window

    -- During the opening WAIT delay, old builds ignored same-target packets to
    -- avoid duplicate bar refills. That accidentally hid real Send-macro WSs from
    -- different alts. Keep the exact-duplicate protection above, but let real
    -- different actions continue through so they can reset Chain when needed.
    local burst_interrupt = same_target_burst

    if confirmed_sc and not burst_interrupt then
        -- A confirmed add_effect skillchain means the previous WS actually chained.
        -- This is the only place Chain increments, so non-combining WSs during GO
        -- will refresh the bar but will not falsely raise the Chain count.
        sc_chain_count = (sc_chain_count or 0) + 1
        sc_chain_step = clamp((sc_chain_count or 0) + 1, 1, settings.sc_bar_max_step or 5)
        update_sc_chain_counter()
        show_sc_chain_info(sc_chain_count, sc_name_from_add_effect(add_eff))

        if debug_mode then
            local sc_name = sc_name_from_add_effect(add_eff)
            windower.add_to_chat(200, '[CrankWatch] Packet-confirmed skillchain: ' .. sc_name .. ' / Chain ' .. tostring(sc_chain_count))
        end
    end

    -- If a new WS lands while the previous SC window is still active, it is only
    -- a possible chain follow-up. Do not increment Chain from this alone because
    -- the WS elements may not actually create a skillchain. Chain increments only
    -- when the packet add_effect confirms an actual skillchain.
    local is_chain_followup = sc_bar_active
        and sc_bar_target_id == target_id
        and now <= (sc_bar_close_time or 0)

    if burst_interrupt then
        if confirmed_sc then
            show_sc_chain_info((sc_chain_count or 0) + 1, sc_name_from_add_effect(add_eff))
        end

        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Chain reset: simultaneous WS burst on same target.')
        end

        sc_chain_count = 0
        sc_chain_counter_visible = false
        sc_chain_counter_text:hide()
        sc_chain_step = 1

    elseif not confirmed_sc then
        if is_chain_followup then
            -- A WS landed inside the active skillchain window but did not carry
            -- a packet-confirmed skillchain add_effect. That means the elements
            -- did not combine, so the visible chain is broken. Hide Chain and
            -- let this WS become the new opener for the next possible chain.
            if (sc_chain_count or 0) > 0 and debug_mode then
                windower.add_to_chat(200, '[CrankWatch] Chain reset: WS did not produce a skillchain.')
            end
        end

        -- Fresh opening WS, or failed follow-up WS, starts a new possible chain
        -- sequence. Do not increment Chain here; only packet-confirmed SC
        -- add_effect events do that.
        sc_chain_count = 0
        sc_chain_counter_visible = false
        sc_chain_counter_text:hide()
        sc_chain_step = 1
    end

    -- Any new WS on the current target interrupts/restarts the opening delay.
    -- WS packets on other mobs are ignored above, even if they come from party/alliance.
    local step = sc_chain_step or 1
    start_sc_bar_from_time(now, step, target_id, action_id, actor_id, get_action_delay(resource, action_id))
    sc_window_until = sc_bar_close_time
    sc_armed = false

    if debug_mode then
        windower.add_to_chat(200, '[CrankWatch] SC bar refreshed by WS action on target ' .. tostring(target_id))
    end
end

if sc_packet_bar_enabled then
    ActionPacket.open_listener(function(act)
        local actionpacket = ActionPacket.new(act)
        local category = actionpacket:get_category_string()
        if not sc_action_categories[category] or act.param == 0 then return end

        local actor_id = actionpacket:get_id()
        local target = actionpacket:get_targets()()
        if not target then return end

        local action = target:get_actions()()
        if not action then return end

        local add_eff = action:get_add_effect()
        local param, resource, action_id, interruption, conclusion = action:get_spell()
        if not action_id or action_id == 0 then return end

        if not is_valid_sc_bar_action(resource, action_id) then
            if debug_mode then
                local ability = skills and resource and skills[resource] and skills[resource][action_id]
                local name = ability and ability.en or tostring(action_id)
                windower.add_to_chat(200, '[CrankWatch] Ignored non-whitelisted SC packet action: resource=' .. tostring(resource) .. ' name=' .. tostring(name))
            end
            return
        end

        -- Ignore other mobs before doing any state-changing cleanup. Otherwise a
        -- dying side target can accidentally wipe the bar/chain for your target.
        if not is_current_battle_target_id(target.id) then
            if debug_mode then
                windower.add_to_chat(200, '[CrankWatch] Ignored packet target that is not current target: ' .. tostring(target.id))
            end
            return
        end

        local mob = windower.ffxi.get_mob_by_id(target.id)
        if not mob or (tonumber(mob.hpp) or 0) <= 0 then
            stop_sc_bar(true)
            return
        end

        refresh_sc_bar_from_action(actor_id, target.id, resource, action_id, add_eff, conclusion)
    end)
end

windower.register_event('incoming text', function(original, modified)
    local p = windower.ffxi.get_player()
    if not p then return end

    local now = os.clock()
    local name = p.name
    local raw_line = tostring(original or '')
    local raw_mod_line = tostring(modified or '')
    local raw_all = raw_line .. ' ' .. raw_mod_line
    local line = clean_line(original)
    local mod_line = clean_line(modified)

    if debug_mode then
        windower.add_to_chat(207, '[wsdamage debug] ' .. line)
        if mod_line ~= '' and mod_line ~= line then
            windower.add_to_chat(207, '[wsdamage debug modified] ' .. mod_line)
        end
    end

    if pending_ws and (now - pending_time > settings.pending_timeout) then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Pending WS expired: ' .. pending_ws)
        end
        pending_ws = nil
        pending_time = 0
    end

    local ws = player_ws_from_line(line, name) or player_ws_from_line(mod_line, name)
    local dmg = damage_from_line(line) or damage_from_line(mod_line)
    local whiff = whiff_from_line(line) or whiff_from_line(mod_line)
    local skillchain = skillchain_from_line(line) or skillchain_from_line(mod_line)
    local mb_dmg = magic_burst_damage_from_line(line) or magic_burst_damage_from_line(mod_line) or magic_burst_damage_from_line(raw_line) or magic_burst_damage_from_line(raw_mod_line)
    local mb_seen_line = normalize_mb_line(raw_all):lower()
    local mb_seen = mb_seen_line:find('magic') and mb_seen_line:find('burst')

    if settings.sc_enabled and sc_window_until > 0 and now > sc_window_until then
        sc_window_until = 0
        sc_armed = false
        if sc_bar_active and now > sc_bar_close_time then
            stop_sc_bar(true)
        end
    end

    if mb_dmg then
        -- Restored from the old working MB trigger path: the log line itself
        -- contains both "Magic Burst!" and the damage, so just flash the
        -- minimal MB overlay immediately.
        mb_pending_until = 0
        start_mb_popup(mb_dmg)
        return
    end

    -- If Windower/Battlemod splits "Magic Burst!" and the damage into separate
    -- incoming text events, arm a short window and use the next non-WS damage line.
    if mb_seen then
        mb_pending_until = now + 1.75
    end

    if mb_pending_until and mb_pending_until > 0 then
        if now <= mb_pending_until and dmg and not ws and not skillchain then
            mb_pending_until = 0
            start_mb_popup(dmg)
            return
        elseif now > mb_pending_until then
            mb_pending_until = 0
        end
    end

    if settings.sc_enabled and skillchain and sc_window_until > 0 and now <= sc_window_until then
        sc_armed = (not sc_bar_target_id) or is_current_battle_target_id(sc_bar_target_id)
    end

    if settings.sc_enabled and dmg and sc_armed and sc_window_until > 0 and now <= sc_window_until and not ws then
        if (not sc_bar_target_id) or is_current_battle_target_id(sc_bar_target_id) then
            start_sc_popup(dmg)
        end
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
    avg_trend_text:font('Consolas')
    sc_text:font(settings.font)
    sc_bar_text:font(settings.sc_bar_font or 'Consolas')
    sc_bar_label_text:font(settings.font)
    sc_bar_status_text:font(settings.font)
    sc_chain_counter_text:font(settings.font)
    sc_chain_info_text:font(settings.font)
    sc_chain_info_name_text:font(settings.font)
    sc_chain_info_elements_text:font(settings.font)
    mb_text:font(settings.font)
    flair_text:font(settings.font)

    ws_text:size(settings.ws_size)
    dmg_text:size(settings.dmg_size)
    avg_text:size(settings.avg_size)
    avg_label_text:size(settings.avg_size)
    avg_value_text:size(settings.avg_size)
    avg_trend_text:size(settings.avg_size)
    sc_text:size(settings.sc_size or settings.flair_size)
    sc_bar_text:size(settings.sc_bar_size or settings.avg_size)
    sc_bar_label_text:size(settings.sc_bar_label_size or 15)
    sc_bar_status_text:size(settings.sc_bar_label_size or 15)
    sc_chain_counter_text:size(settings.sc_chain_counter_size or 18)
    sc_chain_info_text:size(settings.sc_chain_info_size or 20)
    sc_chain_info_name_text:size(settings.sc_chain_info_size or 20)
    sc_chain_info_elements_text:size(settings.sc_chain_info_size or 20)
    mb_text:size(settings.mb_size or 22)
    flair_text:size(settings.flair_size)

    ws_text:stroke_width(settings.stroke_width)
    dmg_text:stroke_width(settings.stroke_width)
    avg_text:stroke_width(settings.stroke_width)
    avg_label_text:stroke_width(settings.stroke_width)
    avg_value_text:stroke_width(settings.stroke_width)
    avg_trend_text:stroke_width(settings.stroke_width)
    sc_text:stroke_width(settings.stroke_width)
    sc_bar_text:stroke_width(settings.stroke_width)
    sc_bar_label_text:stroke_width(settings.stroke_width)
    sc_bar_status_text:stroke_width(settings.stroke_width)
    sc_chain_counter_text:stroke_width(settings.stroke_width)
    sc_chain_info_text:stroke_width(settings.stroke_width)
    sc_chain_info_name_text:stroke_width(settings.stroke_width)
    sc_chain_info_elements_text:stroke_width(settings.stroke_width)
    mb_text:stroke_width(settings.stroke_width)
    flair_text:stroke_width(settings.stroke_width)

    ws_text:color(255, 255, 255)
    avg_text:color(255, 255, 255)
    avg_label_text:color(255, 255, 255)
    apply_avg_trend_style()
    sc_text:color(120, 255, 255)
    sc_bar_text:color(80, 255, 120)
    sc_bar_label_text:color(255, 255, 255)
    sc_chain_info_text:color(255, 255, 255)
    sc_chain_info_name_text:color(sc_chain_info_color[1] or 255, sc_chain_info_color[2] or 255, sc_chain_info_color[3] or 255)
    sc_chain_info_elements_text:color(255, 255, 255)
    sc_bar_status_text:color(80, 255, 80)
    sc_chain_counter_text:color(255, 255, 255)
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
        local valid_skillchains = {
            liquefaction  = 'Liquefaction',
            induration    = 'Induration',
            reverberation = 'Reverberation',
            detonation    = 'Detonation',
            scission      = 'Scission',
            impaction     = 'Impaction',
            transfixion   = 'Transfixion',
            compression   = 'Compression',
            fusion        = 'Fusion',
            fragmentation = 'Fragmentation',
            distortion    = 'Distortion',
            gravitation   = 'Gravitation',
            light         = 'Light',
            darkness      = 'Darkness',
            radiance      = 'Radiance',
            umbra         = 'Umbra',
        }

        local requested = tostring(arg1 or ''):lower():gsub('_', ''):gsub('%s+', '')
        local sc_name = valid_skillchains[requested]

        if not sc_name then
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw testsc <skillchain name>')
            windower.add_to_chat(200, '[CrankWatch] Valid skillchains: Liquefaction, Induration, Reverberation, Detonation, Scission, Impaction, Transfixion, Compression, Fusion, Fragmentation, Distortion, Gravitation, Light, Darkness, Radiance, Umbra.')
        elseif not settings.sc_bar_enabled then
            windower.add_to_chat(200, '[CrankWatch] Skillchain HUD is disabled. Use //cw scbar on before testing.')
        else
            -- This is a visual-only test of the same chain-info rendering path
            -- used by real packet-confirmed skillchains.
            fade_state = 'visible'
            alpha_current = 255
            last_ws_time = os.clock()
            apply_alpha(255)
            update_display()
            show_sc_chain_info(1, sc_name)
            request_layout_refresh(0.45)
            windower.add_to_chat(200, '[CrankWatch] Testing skillchain display: ' .. sc_name .. '.')
        end

    elseif cmd == 'testmb' then
        start_mb_popup(arg1 or '40000')


    elseif cmd == 'mb' then
        local value = arg1 and arg1:lower() or ''

        if value == 'on' then
            settings.mb_enabled = true
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Magic Burst display enabled.')
        elseif value == 'off' then
            settings.mb_enabled = false
            mb_visible = false
            mb_pending_until = 0
            mb_text:hide()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Magic Burst display disabled.')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw mb on|off')
        end

    elseif cmd == 'mbsize' then
        local size = tonumber(arg1)
        if size then
            settings.mb_size = size
            mb_text:size(settings.mb_size)
            if mb_visible then
                position_mb_text()
            end
            save_settings()
            update_display()
            request_layout_refresh(0.45)
            windower.add_to_chat(200, '[CrankWatch] MB size saved: ' .. tostring(size))
        else
            windower.add_to_chat(200, '[CrankWatch] Current MB size: ' .. tostring(settings.mb_size or 18))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw mbsize <size>')
        end

    elseif cmd == 'mbx' then
        local x = tonumber(arg1)
        if x then
            settings.mb_offset_x = x
            save_settings()
            if mb_visible then position_mb_text() end
            windower.add_to_chat(200, '[CrankWatch] MB horizontal offset set to ' .. tostring(x) .. '.')
        else
            windower.add_to_chat(200, '[CrankWatch] MB horizontal offset: ' .. tostring(settings.mb_offset_x or 0) .. '. Use //cw mbx <pixels>.')
        end

    elseif cmd == 'mby' then
        local y = tonumber(arg1)
        if y then
            settings.mb_offset_y = y
            save_settings()
            if mb_visible then position_mb_text() end
            windower.add_to_chat(200, '[CrankWatch] MB vertical offset set to ' .. tostring(y) .. '.')
        else
            windower.add_to_chat(200, '[CrankWatch] MB vertical offset: ' .. tostring(settings.mb_offset_y or -4) .. '. Use //cw mby <pixels>.')
        end

    elseif cmd == 'testbar' then
        commit('Savage Blade', '54321')
        test_sc_bar_default()
        windower.add_to_chat(200, '[CrankWatch] Test SC bar started.')

    elseif cmd == 'scbarlabelsize' then
        local size = tonumber(arg1)
        if size then
            settings.sc_bar_label_size = size
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar label size saved: ' .. size)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar label size: ' .. tostring(settings.sc_bar_label_size))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbarlabelsize <size>')
        end

    elseif cmd == 'scbarlabeloverlap' then
        local overlap = tonumber(arg1)
        if overlap then
            settings.sc_bar_label_overlap = overlap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar label overlap saved: ' .. overlap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar label overlap: ' .. tostring(settings.sc_bar_label_overlap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbarlabeloverlap <pixels>')
        end

    elseif cmd == 'scchaincountersize' then
        local size = tonumber(arg1)
        if size then
            settings.sc_chain_counter_size = size
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC chain counter size saved: ' .. size)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC chain counter size: ' .. tostring(settings.sc_chain_counter_size))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scchaincountersize <size>')
        end

    elseif cmd == 'scchaincountergap' then
        local gap = tonumber(arg1)
        if gap then
            settings.sc_chain_counter_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC chain counter offset saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC chain counter offset: ' .. tostring(settings.sc_chain_counter_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scchaincountergap <pixels>  -- offset from Bonus Chance text')
        end


    elseif cmd == 'scinfogap' then
        local gap = tonumber(arg1)

        if gap then
            settings.sc_chain_info_gap = gap
            update_display()
            request_layout_refresh(0.5)
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC info gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC info gap: ' .. tostring(settings.sc_chain_info_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scinfogap <pixels>')
        end

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
            windower.add_to_chat(200, '[CrankWatch] Current center position: ' .. tostring(settings.center_x) .. ', ' .. tostring(settings.center_y))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw pos <x> <y>')
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
            windower.add_to_chat(200, '[CrankWatch] Current sizes: WS ' .. tostring(settings.ws_size) .. ', damage ' .. tostring(settings.dmg_size) .. ', avg ' .. tostring(settings.avg_size) .. ', flair ' .. tostring(settings.flair_size) .. ', SC ' .. tostring(settings.sc_size))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw size <ws size>')
        end

    elseif cmd == 'gap' then
        local gap = tonumber(arg1)

        if gap then
            settings.line_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Line gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current line gap: ' .. tostring(settings.line_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw gap <pixels>')
        end

    elseif cmd == 'avggap' then
        local gap = tonumber(arg1)

        if gap then
            settings.avg_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Average gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current average gap: ' .. tostring(settings.avg_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw avggap <pixels>')
        end

    elseif cmd == 'flairgap' then
        local gap = tonumber(arg1)

        if gap then
            settings.flair_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Flair gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current flair gap: ' .. tostring(settings.flair_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw flairgap <pixels>')
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
            windower.add_to_chat(200, '[CrankWatch] Current stroke width: ' .. tostring(settings.stroke_width) .. ' / big ' .. tostring(settings.big_stroke_width))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw stroke <width>')
        end

    elseif cmd == 'font' then
        local font = arg1

        if font and font ~= '' then
            settings.font = font
            apply_all_visual_settings()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Font saved: ' .. font)
        else
            windower.add_to_chat(200, '[CrankWatch] Current font: ' .. tostring(settings.font))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw font <font name>')
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


    elseif cmd == 'testbar' then
        commit('Savage Blade', '54321')

    elseif cmd == 'scbar' then
        local value = arg1 and arg1:lower() or ''

        if value == 'on' then
            settings.sc_bar_enabled = true
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Skillchain HUD enabled: countdown bar, chain tracker, and last skillchain elements.')
        elseif value == 'off' then
            settings.sc_bar_enabled = false
            stop_sc_bar(true)
            sc_chain_counter_visible = false
            sc_chain_counter_text:hide()
            hide_sc_chain_info()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Skillchain HUD disabled: countdown bar, chain tracker, and last skillchain elements.')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbar on|off')
        end

    elseif cmd == 'scbargap' then
        local gap = tonumber(arg1)

        if gap then
            settings.sc_bar_gap = gap
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar gap saved: ' .. gap)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar gap: ' .. tostring(settings.sc_bar_gap))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbargap <pixels>')
        end

    elseif cmd == 'scbarwidth' then
        local width = tonumber(arg1)

        if width then
            settings.sc_bar_width = math.max(6, math.floor(width))
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar width saved: ' .. settings.sc_bar_width)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar width: ' .. tostring(settings.sc_bar_width))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbarwidth <characters>')
        end

    elseif cmd == 'scbarsize' then
        local size = tonumber(arg1)

        if size then
            settings.sc_bar_size = math.max(8, math.floor(size))
            sc_bar_text:size(settings.sc_bar_size)
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar size saved: ' .. settings.sc_bar_size)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar size: ' .. tostring(settings.sc_bar_size))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbarsize <size>')
        end

    elseif cmd == 'scbardelay' then
        local delay = tonumber(arg1)

        if delay then
            settings.sc_bar_delay = math.max(0, delay)
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC bar delay saved: ' .. settings.sc_bar_delay .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC bar delay: ' .. tostring(settings.sc_bar_delay) .. 's')
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scbardelay <seconds>')
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
            windower.add_to_chat(200, '[CrankWatch] Current SC Bonus size: ' .. tostring(settings.sc_size))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scsize <size>')
        end

    elseif cmd == 'scfade' then
        local duration = tonumber(arg1)

        if duration then
            settings.sc_fade_duration = duration
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC fade duration saved: ' .. duration .. 's')
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC fade duration: ' .. tostring(settings.sc_fade_duration) .. 's')
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scfade <seconds>')
        end

    elseif cmd == 'scfloat' then
        local distance = tonumber(arg1)

        if distance then
            settings.sc_float_distance = distance
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC float distance saved: ' .. distance)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC float distance: ' .. tostring(settings.sc_float_distance))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scfloat <pixels>')
        end

    elseif cmd == 'scoffset' then
        local offset = tonumber(arg1)

        if offset then
            settings.sc_offset_y = offset
            update_display()
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] SC vertical offset saved: ' .. offset)
        else
            windower.add_to_chat(200, '[CrankWatch] Current SC vertical offset: ' .. tostring(settings.sc_offset_y))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw scoffset <pixels>')
        end


    elseif cmd == 'layout' then
        windower.add_to_chat(200, '[CrankWatch] Layout: pos ' .. tostring(settings.center_x) .. ', ' .. tostring(settings.center_y)
            .. ' | gap ' .. tostring(settings.line_gap)
            .. ' | avggap ' .. tostring(settings.avg_gap)
            .. ' | flairgap ' .. tostring(settings.flair_gap)
            .. ' | scgap ' .. tostring(settings.sc_gap)
            .. ' | font ' .. tostring(settings.font))

    elseif cmd == 'reset' or cmd == 'resetavg' then
        reset_average(false)

    elseif cmd == 'autoreset' then
        local state = tostring(arg1 or ''):lower()

        if state == 'on' then
            settings.auto_reset = true
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Auto average reset: ON')
        elseif state == 'off' then
            settings.auto_reset = false
            save_settings()
            windower.add_to_chat(200, '[CrankWatch] Auto average reset: OFF')
        elseif state == '' then
            windower.add_to_chat(200, '[CrankWatch] Auto average reset: ' .. (settings.auto_reset and 'ON' or 'OFF'))
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw autoreset on|off')
        else
            windower.add_to_chat(200, '[CrankWatch] Usage: //cw autoreset on|off')
        end
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
        settings.sc_bar_enabled = defaults.sc_bar_enabled
        settings.sc_bar_gap = defaults.sc_bar_gap
        settings.sc_bar_size = defaults.sc_bar_size
        settings.sc_bar_width = defaults.sc_bar_width
        settings.sc_bar_delay = defaults.sc_bar_delay
        settings.sc_bar_max_step = defaults.sc_bar_max_step
        settings.sc_bar_font = defaults.sc_bar_font
        settings.pop_enabled = defaults.pop_enabled
        settings.pop_duration = defaults.pop_duration
        settings.pop_bonus_size = defaults.pop_bonus_size
        settings.auto_reset = defaults.auto_reset
        settings.flair_fade_duration = defaults.flair_fade_duration
        settings.flair_shrink_size = defaults.flair_shrink_size
        settings.flair_float_distance = defaults.flair_float_distance
        settings.flair_anchor_ratio = defaults.flair_anchor_ratio
        settings.sc_anchor_ratio = defaults.sc_anchor_ratio
        settings.flair_offset_y = defaults.flair_offset_y
        settings.sc_gap = defaults.sc_gap

        apply_all_visual_settings()
        save_settings()
        windower.add_to_chat(200, '[CrankWatch] Factory settings reset and saved.')

    elseif cmd == 'hide' then
        ws_text:hide()
        dmg_text:hide()
        avg_text:hide()
        avg_label_text:hide()
        avg_value_text:hide()
        avg_trend_text:hide()
        sc_text:hide()
        sc_bar_text:hide()
        sc_bar_label_text:hide()
        sc_bar_status_text:hide()
        sc_chain_counter_text:hide()
        flair_text:hide()
                fade_state = 'hidden'
        alpha_current = 0
        stop_sc_bar(false)

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
        windower.add_to_chat(200, '[CrankWatch] Commands: //cw test | testwhite | testwhiff | testbig | testred | testmassive | testsc <skillchain> | testbar | testcrankedstreak | reset | show | hide | layout | pos x y | size 36 | gap 45 | avggap 99 | flairgap 100 | stroke 4 | font Highwind | fade on|off | fadetime 60 8 | fadein 0.3 | pop on|off | popsize 8 | poptime 0.35 | flairfade 1.5 | flairshrink 0 | flairfloat 32 | whiffshake 6 0.45 | scsize 28 | scfade 4.5 | scfloat 32 | scoffset 0 | scbar on|off | mb on|off | scbargap 132 | scbarwidth 34 | scbarsize 18 | scbardelay 3 | autoreset on|off | reset | factoryreset | debug')

    else
        windower.add_to_chat(200, '[CrankWatch] Commands: //cw test | testwhite | testwhiff | testbig | testred | testmassive | testsc <skillchain> | testbar | testcrankedstreak | reset | show | hide | layout | pos x y | size 36 | gap 45 | avggap 99 | flairgap 100 | stroke 4 | font Highwind | fade on|off | fadetime 60 8 | fadein 0.3 | pop on|off | popsize 8 | poptime 0.35 | flairfade 1.5 | flairshrink 0 | flairfloat 32 | whiffshake 6 0.45 | scsize 28 | scfade 4.5 | scfloat 32 | scoffset 0 | scbar on|off | mb on|off | scbargap 132 | scbarwidth 34 | scbarsize 18 | scbardelay 3 | autoreset on|off | reset | factoryreset | debug')
    end
end)

windower.register_event('zone change', function()
    if not settings.auto_reset then
        if debug_mode then
            windower.add_to_chat(200, '[CrankWatch] Auto average reset skipped on zone change.')
        end
        return
    end

    reset_average(true)
    if debug_mode then
        windower.add_to_chat(200, '[CrankWatch] Average reset on zone change.')
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

    if avg_trend_text then
        avg_trend_text:destroy()
    end

    if sc_text then
        sc_text:destroy()
    end

    if sc_bar_text then
        sc_bar_text:destroy()
    end

    if flair_text then
        flair_text:destroy()
    end

end)

apply_all_visual_settings()
update_display()
apply_alpha(0)

fade_state = 'hidden'
alpha_current = 0

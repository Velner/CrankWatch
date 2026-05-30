CrankWatch v1.0 — Complete Commands README
A cinematic Weapon Skill tracker addon for Final Fantasy XI / Windower

Primary command aliases:
  //cw
  //crankwatch

Example:
  //cw show
  //crankwatch show

==================================================
HIGHWIND FONT
==================================================

-CrankWatch defaults to Highwind Font which is a custom font
-Highwind can be downloaded here: https://font.download/font/highwind
-It's easy to install!  Once downloaded just right click the font file and choose 'Install'
-BUT if you don't want this font or prefer a different font, CrankWatch is fully compatible with any Windows Font! (//cw font FONTNAME))

==================================================
DEFAULT BEHAVIOR
==================================================

- The GUI starts hidden on load.
- The overlay appears automatically after your first tracked Weapon Skill.
- The overlay can be shown manually with //cw show.
- Position is draggable and auto-saves when you release the mouse.
- Weapon Skill whitelist protection prevents food, items, JAs, rolls, waltzes, jumps, etc. from falsely triggering WS tracking.
- No packet injection is used.

==================================================
COMMAND ALIASES
==================================================

Both command aliases work:

  //cw <command>
  //crankwatch <command>

Examples:
  //cw test
  //crankwatch test

==================================================
BASIC DISPLAY COMMANDS
==================================================

Show the overlay:
  //cw show

Hide the overlay:
  //cw hide

Show all commands in-game:
  //cw help

==================================================
LAYOUT SETTINGS
==================================================
View layout settings quickly:

//cw layout

Will display the main GUI settings to make adjustments easier.

==================================================
POSITIONING
==================================================

Set exact overlay center position:
  //cw pos X Y

Example:
  //cw pos 900 450

Notes:
- X controls horizontal position.
- Y controls vertical position.
- You can also drag the overlay with the mouse.
- Position saves automatically after dragging.


==================================================
MAIN SIZE CONTROL
==================================================

Adjust overall overlay size:
  //cw size 36

Important:
- This is a master scaler.
- It changes WS text, damage text, average text, flair size, and spacing.
- If you only want to change SC Bonus size, use //cw scsize instead.

Default-style example:
  //cw size 36

==================================================
SPACING / GAP CONTROLS
==================================================

Adjust gap between WS line and damage line:
  //cw gap 44

Adjust gap for the average damage line:
  //cw avggap 86

Adjust gap for flair text:
  //cw flairgap 118

Notes:
- Larger values move that element lower.
- Smaller values move that element higher.

==================================================
FONT AND OUTLINE
==================================================

Change font:
  //cw font Highwind

Example:
  //cw font Arial

Adjust outline / stroke thickness:
  //cw stroke 4

Notes:
- Higher stroke values make text outlines thicker.
- Highwind.ttf should be installed in Windows Fonts or otherwise available to Windower.

==================================================
MAIN GUI FADE CONTROLS
==================================================

Enable GUI fade behavior:
  //cw fade on

Disable GUI fade behavior:
  //cw fade off

Set hold time and fade-out time:
  //cw fadetime HOLD_SECONDS FADE_SECONDS

Example:
  //cw fadetime 60 8

Meaning:
- Hold fully visible for 60 seconds.
- Fade out over 8 seconds.

Adjust fade-in speed:
  //cw fadein 0.3

Notes:
- Lower fadein values feel snappier.
- Higher fadein values feel smoother/slower.

==================================================
POP ANIMATION CONTROLS
==================================================

Enable damage pop animation:
  //cw pop on

Disable damage pop animation:
  //cw pop off

Adjust pop size bonus:
  //cw popsize 8

Adjust pop duration:
  //cw poptime 0.35

Notes:
- Pop animation applies to large hits.
- popsize controls how much the damage text briefly enlarges.
- poptime controls how long the pop animation lasts.

==================================================
GRADIENT / HIGHLIGHT CONTROLS
==================================================

Enable gradient highlight:
  //cw gradient on

Disable gradient highlight:
  //cw gradient off

Notes:
- Gradient adds an extra highlight overlay to large damage text.
- If text looks blurry, try turning gradient off.

==================================================
BIG HIT / MASSIVE HIT / CRANKED FLAIR CONTROLS
==================================================

Adjust flair fade duration:
  //cw flairfade 1.5

Adjust flair shrink amount:
  //cw flairshrink 0

Adjust flair upward float distance:
  //cw flairfloat 32

Notes:
- Flair includes BIG HIT, MASSIVE HIT, CRANKED, and related popup text.
- flairfade controls how long the flair takes to fade.
- flairshrink controls whether the flair shrinks while fading.
- flairfloat controls how far the flair drifts upward.

==================================================
SKILLCHAIN BONUS CONTROLS
==================================================

Adjust SC Bonus font size:
  //cw scsize 30

Example:
  //cw scsize 40

Adjust SC Bonus fade duration:
  //cw scfade 4.5

Adjust SC Bonus upward float distance:
  //cw scfloat 32

Adjust SC Bonus vertical placement:
  //cw scoffset 18

Notes:
- Positive scoffset values move SC Bonus lower.
- Negative scoffset values move SC Bonus higher.
- scsize only affects SC Bonus text.
- scfade controls how long SC Bonus remains visible/fading.
- scfloat controls how far SC Bonus moves upward during fade.

==================================================
WHIFF CONTROLS
==================================================

Adjust WHIFF shake:
  //cw whiffshake STRENGTH DURATION

Example:
  //cw whiffshake 6 0.45

Notes:
- Strength controls shake intensity.
- Duration controls how long the shake lasts.
- WHIFF also triggers the LOL popup.

==================================================
AVERAGE DAMAGE / RESET COMMANDS
==================================================

Reset average WS damage:
  //cw reset

Alternative reset command:
  //cw resetavg

Factory reset all settings:
  //cw factoryreset

Notes:
- reset/resetavg only clears average damage tracking.
- factoryreset restores saved addon settings to defaults.

==================================================
DEBUG COMMAND
==================================================

Toggle debug mode:
  //cw debug

Notes:
- Debug mode prints chat parsing information.
- Useful for diagnosing missed WS, false detections, or SC detection behavior.
- Toggle it off again with the same command.

==================================================
TEST COMMANDS
==================================================

Standard damage test:
  //cw test

White/small damage test:
  //cw testwhite

WHIFF test:
  //cw testwhiff

BIG HIT test:
  //cw testbig

MASSIVE HIT / red-tier test:
  //cw testred

CRANKED 99,999 test:
  //cw testmassive

Skillchain Bonus test:
  //cw testsc

CRANKED streak test:
  //cw testcrankedstreak

Notes:
- Test commands are useful for positioning and visual tuning.
- Use //cw show first if you want to manually inspect layout before combat.
- testsc is useful for tuning scsize, scfade, scfloat, and scoffset.

==================================================
QUICK TUNING EXAMPLES
==================================================

Show overlay:
  //cw show

Move overlay:
  //cw pos 900 450

Restore common base size:
  //cw size 36

Adjust normal line spacing:
  //cw gap 44

Adjust average line spacing:
  //cw avggap 86

Adjust flair spacing:
  //cw flairgap 118

Make SC Bonus bigger:
  //cw scsize 40

Move SC Bonus lower:
  //cw scoffset 18

Make SC Bonus linger longer:
  //cw scfade 6

Make SC Bonus float less:
  //cw scfloat 18

Disable gradient if damage text looks blurry:
  //cw gradient off

Reset average:
  //cw reset

==================================================
FEATURE SUMMARY
==================================================

CrankWatch v1.0 includes:

- Weapon Skill whitelist protection
- Last WS display
- WS damage display
- Average WS damage tracking
- BIG HIT flair
- MASSIVE HIT flair
- CRANKED 99,999 flair
- CRANKED streak tracking
- WHIFF display and shake
- LOL popup on WHIFF
- Skillchain Bonus popup
- SC Bonus sizing/fade/float/offset controls
- Pop animation for large hits
- Optional gradient highlights
- Fade-in and fade-out behavior
- Draggable saved positioning
- Hidden-on-load behavior
- Debug mode
- No packet injection

==================================================
END
==================================================

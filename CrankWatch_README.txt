CrankWatch v2.0 — README

A cinematic Weapon Skill tracker addon for Final Fantasy XI / Windower

Primary command aliases: - //cw - //crankwatch

------------------------------------------------------------------------

QUICK START (Most Common Commands)

  -----------------------------------------------------------------------
  Command                       Description
  ----------------------------- -----------------------------------------
  //cw show                     Show the HUD immediately.

  //cw hide                     Hide the HUD.

  //cw pos X Y                  Move the HUD to a specific location.

  //cw size #                   Adjust the overall HUD size.

  //cw reset                    Reset average Weapon Skill damage.

  //cw scbar on / off           Enable or disable the Skillchain HUD (SC
                                bar, Chain tracker, Last Skillchain
                                display).

  //cw mb on / off              Enable or disable Magic Burst popups.

  //cw help                     Display all available commands in-game.
  -----------------------------------------------------------------------

------------------------------------------------------------------------

TEST COMMANDS

  Command                    Description
  -------------------------- ---------------------------------
  //cw test                  Standard Weapon Skill test.
  //cw testwhite             White damage test.
  //cw testwhiff             WHIFF test.
  //cw testbig               BIG HIT test.
  //cw testred               MASSIVE HIT test.
  //cw testmassive           99,999 CRANKED test.
  //cw testsc <skillchain>   Preview any Skillchain display.
  //cw testmb [damage]       Preview the Magic Burst popup.

Supported Skillchains:

Liquefaction, Induration, Reverberation, Detonation, Scission,
Impaction, Transfixion, Compression, Fusion, Fragmentation, Distortion,
Gravitation, Light, Darkness, Radiance, Umbra

Examples:

    //cw testsc fusion
    //cw testsc darkness
    //cw testsc radiance

------------------------------------------------------------------------

INSTALLATION

-   Place CrankWatch.lua in your Windower addons folder.
-   Load with //lua load crankwatch.
-   The HUD is hidden until your first tracked Weapon Skill or
    //cw show.

Highwind Font

CrankWatch defaults to the Highwind font.

Download: https://font.download/font/highwind

Any installed Windows font may also be used:

    //cw font Arial

------------------------------------------------------------------------

DEFAULT BEHAVIOR

-   HUD starts hidden.
-   Appears automatically after your first tracked Weapon Skill.
-   Position is controlled with //cw pos X Y.
-   Weapon Skill whitelist prevents false triggers from JAs, items,
    rolls, waltzes, etc.
-   No packet injection is used.

------------------------------------------------------------------------

POSITIONING

    //cw pos X Y

Example:

    //cw pos 900 450

------------------------------------------------------------------------

APPEARANCE

Useful commands:

    //cw size 36
    //cw gap 44
    //cw avggap 86
    //cw flairgap 118
    //cw font Highwind
    //cw stroke 4

------------------------------------------------------------------------

SKILLCHAIN HUD

Enable or disable the complete Skillchain HUD:

    //cw scbar on
    //cw scbar off

This controls:

-   Skillchain countdown bar
-   Chain tracker
-   Last Skillchain display

------------------------------------------------------------------------

MAGIC BURST

Enable or disable Magic Burst popups:

    //cw mb on
    //cw mb off

------------------------------------------------------------------------

RESETS

Reset average damage:

    //cw reset

Factory reset:

    //cw factoryreset

------------------------------------------------------------------------

DEBUG

Toggle debug mode:

    //cw debug

------------------------------------------------------------------------

NOTES

Changes for v1.2:

-   Removed gradient system.
-   Removed drag-and-drop positioning.
-   Added Skillchain HUD toggle.
-   Added Magic Burst toggle.
-   Added //cw testsc <skillchain>.
-   Default HUD layout updated to the streamlined Velner layout.
-   Expanded Light/Darkness element displays for readability.

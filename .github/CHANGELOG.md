[![Support Server](https://img.shields.io/discord/862736286774198322.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge)](https://discord.com/invite/FKamccAEqz)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.me/joe91de)
![Image](https://img.shields.io/github/downloads/Joe91/fun-bots/total?style=for-the-badge)
![Image](https://img.shields.io/github/stars/Joe91/fun-bots?style=for-the-badge)

## Welcome to the changelogs for release **V3.7.0**
This is the changelog for release **V3.7.0** (in development). Don't forget to [join us on Discord](https://discord.com/invite/FKamccAEqz)


## Changelog

### New features / improvements
* **Capture the Flag:** bots play it on all four Armored Kill levels (XP5_001 - XP5_004) with a navigation mesh.
  The flags are the objectives: bots go for the flag of the other team, guard their own and go after it when it is
  taken; the bot with the flag carries it to its own stand and scores
* **BFLAG** (with the BFLAG mod, MP_001 around B): supported again, now with a navigation mesh. Only B is an objective,
  the teams spawn at A and C
* Bots no longer use the stationary launchers (TOW, Kornet) and never spawn into one: they shot at little and kept the
  bot out of the fight
* Soldiers no longer switch paths by the objectives written on them (only vehicles do): on levels with a mesh the
  routes decide, without one they switch at random
* Debug-server: the census supports Capture the Flag (mesh at the flag stands) and modes of other mods with their own
  name (BFLAG); bots record longer ways between far-apart bases and a second way between them

### Bug fixes
* Capture the Flag: bots respawn again after their first death (the mode has no tickets, the rule for the last
  conquest ticket blocked every respawn)
* Vehicles on a path of other objectives switch to another one by chance again
* A reserved vehicle of no team counted for no team (two bots could go for the same one)
* A bot taken off an invalid objective was still counted on it
* Vehicle paths named like "vehicle truck2" were taken for the paths of the RU team
* "Probability switch same priority" of 0 still switched now and then
* Error in the obstacle handling at the last point of a way
* Bots no longer spawn into a stationary AA outside of the combat area or walk to a vehicle out there

### Updated maps
* New: Capture the Flag on XP5_001, XP5_002 and XP5_004 (paths recorded by bots), XP5_003 with a mesh
* MP_001 BFLAG: navigation mesh, paths cut at it
* Removed (no navigation mesh, they only worked with the old path switching): COOP_006 Conquest Small, XP2_Factory
  and XP2_Office Squad Rush

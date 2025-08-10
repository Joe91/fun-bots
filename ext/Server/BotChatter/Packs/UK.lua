-- ext/Server/BotChatter/Packs/UK.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- UK flavour: understated, dry, tidy. ASCII only.
local UK = {}

UK.Lines = {
  Kill = {
    "sorted.","lovely.","nice one.","job done.","cheeky pick.",
    "clean work.","that'll do.","on to the next.","had him on ropes.","textbook."
  },
  Death = {
    "fair play.","well taken.","you got me.","he earned that.","right, lesson learned.",
    "timing got me.","good angle from them.","deserved, that.","bit of a shambles from me."
  },
  Spawn = {
    "back in.","moving.","let's roll.","forming up.","on you.","regrouping.",
    "focus on.","alright then.","keep it neat.","eyes open."
  },
  Headshot = { "clean between the eyes.","crisp.","keep your head down.","neat shot.","one tap." },
  Revenge  = { "we're square.","consider it even.","that settles it.","paid back." },
  Roadkill = { "mind the bumper.","road's shut.","apologies to the bonnet.","street's closed." },
  RoundStartGlobal = { "gl hf","keep it tidy.","play sensible.","nice and clean." },
  RoundEndGlobal   = { "gg","well played.","nice one.","cheers." },

  VehicleKill = {
    "armor cracked.","bird down.","vehicle disabled.","tank gone.","pilot out.",
    "tracks busted.","driver bailed.","aa down.","rotor stopped.","engine out."
  },
  Multi2 = { "double.","two down.","tempo up.","chain started.","easy two.","momentum." },
  Multi3 = { "triple.","three piece.","they're falling apart.","on a tear.","lining up." },
  Multi4 = { "multi on.","they can't stop me.","stack wiped.","send more, please." },
  Streak = { "on a run.","untouchable.","they can't trade me.","farm mode.","heat check." },
  Longshot = { "long one.","owning that lane.","distance handled.","postcard range.","steady at range." },
  VehEnter = { "climbing in.","mounting up.","driver ready.","gunning.","moving." },
  VehExit  = { "bailing.","hopping out.","on foot.","ground game.","fresh air." },
  FirstBlood = { "first blood.","opening pick.","off to a tidy start.","tempo set." },

  -- Named variants
  KillNamed = {
    "gg {enemy}.","sit down, {enemy}.","trade denied, {enemy}.","peeked wrong, {enemy}.",
    "outplayed, {enemy}.","see you at respawn, {enemy}."
  },
  HeadshotNamed = {
    "one tap, {enemy}.","keep your head down, {enemy}.","peek punished, {enemy}.","clean head, {enemy}."
  },
  LongshotNamed = { "long one, {enemy}.","range diff, {enemy}.","eyes on you from afar, {enemy}." },
  RevengeNamed = { "we're even, {enemy}.","that settles it, {enemy}.","paid back, {enemy}." },
  VehicleKillNamed = { "bye armor, {enemy}.","driver out, {enemy}.","bird down, {enemy}." },
  RoadkillNamed = { "mind the wheels, {enemy}.","street pizza, {enemy}.","green light, {enemy}." },
  DeathNamed = { "nice shot, {enemy}.","you got me, {enemy}.","pre-aimed me, {enemy}.","timing favoured you, {enemy}." },

  -- Weapon-specific
  KnifeKill   = { "quiet now.","silent work.","personal.","slice and tidy.","backstab done." },
  GrenadeKill = { "cook spot on.","frag lands.","nade out.","catch.","good bank." },
  ShotgunKill = { "close range settled.","12g says hello.","door's open.","point blank." },
  PistolKill  = { "sidearm did it.","pistol work.","secondary wins.","tap tap." },
  SniperKill  = { "scope sings.","steady hands.","lane owned.","click at range." },
}

UK.Tweaks = { casing = "lower", distort = { emoticonChance = 0.08 } }
UK.PersonalityBias = { Chill = 1.0, Tactical = 1.1, Cocky = 0.95, Sassy = 1.0 }

return { id = "UK", Lines = UK.Lines, Tweaks = UK.Tweaks, PersonalityBias = UK.PersonalityBias }

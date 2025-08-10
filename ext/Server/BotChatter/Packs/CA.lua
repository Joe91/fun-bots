-- ext/Server/BotChatter/Packs/CA.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- Canada flavour: clean, friendly, lightly hockey-coded. ASCII only; avoid overusing stereotypes.
local CA = {}

CA.Lines = {
  Kill = {
    "beauty.","nice pick.","good one.","too clean.","dialed.","all good.",
    "that'll do.","on to the next.","textbook.","clean work."
  },
  Death = {
    "oof.","good shot.","that's fair.","my bad.","alright then.","i'll get him back.",
    "timing got me.","well taken.","respect on that."
  },
  Spawn = {
    "i'm in.","rolling.","let's go.","we move.","on you.","fresh mags.",
    "all set.","we're good.","eyes up.","focus on."
  },
  Headshot = { "top shelf.","one tap.","clean between the eyes.","crisp.","keep your head down." },
  Revenge  = { "we're even.","call that settled.","that's for earlier.","paid back." },
  Roadkill = { "mind the truck.","road closed.","hood ornament unlocked.","drive-by diploma." },
  RoundStartGlobal = { "gl hf","let's have a good one.","play smart.","stay sharp." },
  RoundEndGlobal   = { "gg","nice game.","good stuff.","cheers." },

  VehicleKill = {
    "armor cracked.","bird down.","vehicle disabled.","tank gone.","pilot out.",
    "tracks busted.","driver bailed.","aa down.","rotor stopped.","engine out."
  },
  Multi2 = { "double.","two down.","tempo up.","chain started.","easy two.","momentum." },
  Multi3 = { "triple.","three piece.","they're falling apart.","on a tear.","lining up." },
  Multi4 = { "multi on.","they can't stop me.","stack wiped.","send more, please." },
  Streak = { "on a run.","untouchable.","they can't trade me.","farm mode.","heat check." },
  Longshot = { "long one.","distance diff.","postcard from downtown.","laser at range.","lane mine." },
  VehEnter = { "taking a ride.","mounting up.","driver ready.","gunning.","moving." },
  VehExit  = { "bailing.","hopping out.","on foot.","ground game.","fresh air." },
  FirstBlood = { "first blood.","opening pick.","we start strong.","tempo set." },

  -- Named variants
  KillNamed = {
    "gg {enemy}.","sit down, {enemy}.","trade denied, {enemy}.","peeked wrong, {enemy}.",
    "outplayed, {enemy}.","see you at respawn, {enemy}."
  },
  HeadshotNamed = {
    "one tap, {enemy}.","keep your head down, {enemy}.","peek punished, {enemy}.","clean head, {enemy}."
  },
  LongshotNamed = { "long one, {enemy}.","range diff, {enemy}.","eagle eye on you, {enemy}." },
  RevengeNamed = { "we're even, {enemy}.","that settles it, {enemy}.","paid back, {enemy}." },
  VehicleKillNamed = { "bye armor, {enemy}.","driver out, {enemy}.","bird down, {enemy}." },
  RoadkillNamed = { "mind the wheels, {enemy}.","street pizza, {enemy}.","green light, {enemy}." },
  DeathNamed = { "nice shot, {enemy}.","you got me, {enemy}.","pre-aimed me, {enemy}.","good timing, {enemy}." },

  -- Weapon-specific
  KnifeKill   = { "quiet now.","silent op.","that was personal.","slice and dice.","backstab meta." },
  GrenadeKill = { "cook perfect.","frag lands.","nade out.","catch.","boom timing.","bank shot." },
  ShotgunKill = { "close range diff.","12g says hello.","door's open.","point blank.","boomstick meta." },
  PistolKill  = { "sidearm gaming.","pistol whipped.","secondary wins.","tap tap." },
  SniperKill  = { "scope sings.","steady hands.","lane owned.","click at range." },
}

CA.Tweaks = { casing = "lower", distort = { emoticonChance = 0.10 } }
CA.PersonalityBias = { Chill = 1.1, Tactical = 1.0, Cocky = 0.95, Sassy = 1.0 }

return { id = "CA", Lines = CA.Lines, Tweaks = CA.Tweaks, PersonalityBias = CA.PersonalityBias }

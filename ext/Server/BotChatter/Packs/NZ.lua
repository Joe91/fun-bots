-- ext/Server/BotChatter/Packs/NZ.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- NZ flavour: subtle, clean, ASCII. Light use of 'sweet as', 'choice', 'chur'. No memes.
local NZ = {}

NZ.Lines = {
  Kill = {
    "sweet as.","too easy.","choice pick.","clean work.","good as.","nice peel.",
    "cheers for the peek.","sorted.","no worries.","that'll do.","mint shot."
  },
  Death = {
    "yep, fair.","he got me.","good one.","yeah nah.","earned that.","stiff as.","timing got me.","my bad there."
  },
  Spawn = {
    "i'm in.","right behind you.","we're on.","ok, send it.","warming up.","keen as.","regrouping.","moving now."
  },
  Headshot = { "clean as.","mint flick.","one tap.","right between the eyes.","crispy.","head gone." },
  Revenge  = { "even as.","that's for before.","we're square.","sorted now." },
  Roadkill = { "mind the ute.","watch the bumper.","that was rough.","road's closed.","whoops." },
  RoundStartGlobal = { "gl hf","play tidy.","good as gold.","keep it clean." },
  RoundEndGlobal   = { "gg","nice work.","that was decent.","cheers team." },

  VehicleKill = {
    "armor cracked.","bird down.","vehicle disabled.","tank gone.","pilot out.","ride's done.",
    "tracks busted.","driver bailed.","aa down.","rotor stopped.","engine out.","free scrap."
  },
  Multi2 = { "double.","two down.","tempo up.","chain started.","easy two.","momentum.","keep feeding." },
  Multi3 = { "triple.","three piece.","they're falling apart.","on a tear.","lining up.","ok, who's next?" },
  Multi4 = { "multi on.","they can't stop me.","stack wiped.","send more, please.","getting rude now :)" },
  Streak = { "on a run.","untouchable.","they can't trade me.","farm mode.","heat check.","everything's clicking." },
  Longshot = { "long one.","range diff.","i own that sightline.","greetings from downtown.","too comfy at range." },
  VehEnter = { "taking a ride.","mounting up.","i'm in.","driver ready.","gunning.","vroom." },
  VehExit  = { "bailing.","hopping out.","on foot.","ditch the ride.","ground game now.","fresh air." },
  FirstBlood = { "first blood.","opening pick.","we start strong.","tempo set.","good start." },

  -- Named variants
  KillNamed = {
    "gg {enemy}.","sit down, {enemy}.","trade denied, {enemy}.","peeked wrong, {enemy}.",
    "outplayed, {enemy}.","see you at respawn, {enemy}.","angle was mine, {enemy}."
  },
  HeadshotNamed = {
    "one tap, {enemy}.","keep your head down, {enemy}.","peek punished, {enemy}.","clean head, {enemy}.","crispy on you, {enemy}."
  },
  LongshotNamed = { "long one, {enemy}.","range diff, {enemy}.","eagle eye on you, {enemy}.","hello from far away, {enemy}." },
  RevengeNamed = { "that's for earlier, {enemy}.","we're even, {enemy}.","payback delivered, {enemy}.","circle closed, {enemy}." },
  VehicleKillNamed = { "bye armor, {enemy}.","driver out, {enemy}.","bird down, {enemy}.","nice ride, {enemy}... was." },
  RoadkillNamed = { "mind the wheels, {enemy}.","hood ornament unlocked, {enemy}.","green light, {enemy}.","street pizza, {enemy}." },
  DeathNamed = { "nice shot, {enemy}.","ok you got me, {enemy}.","pre-aimed me, {enemy}.","good timing, {enemy}.","fair as, {enemy}." },

  -- Weapon-specific
  KnifeKill   = { "shh.","silent op.","that was personal.","slice and dice.","backstab meta." },
  GrenadeKill = { "cook perfect.","frag lands.","nade out.","catch.","boom timing.","bank shot." },
  ShotgunKill = { "close range diff.","12g says hi.","open the door.","point blank.","boomstick meta." },
  PistolKill  = { "sidearm gaming.","pistol whipped.","secondary supremacy.","tap tap.","backup did it." },
  SniperKill  = { "scope sings.","steady hands.","click at range.","lane owned.","glass cannon online." },
}

NZ.Tweaks = { casing = "lower", distort = { emoticonChance = 0.12 } }
NZ.PersonalityBias = { Chill = 1.2, Tactical = 1.0, Cocky = 0.9, Sassy = 0.95 }

return { id = "NZ", Lines = NZ.Lines, Tweaks = NZ.Tweaks, PersonalityBias = NZ.PersonalityBias }

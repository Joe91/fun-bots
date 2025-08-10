-- ext/Server/BotChatter/Packs/AU.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
-- Light Aussie flavour; ASCII only; keep it subtle so it doesn't sound forced.
local AU = {}

AU.Lines = {
  Kill = {
    "cop that.","too easy, mate.","righto.","beaut.","nice peel.",
    "cheers for the peek.","on ya.","sorted.","no dramas.","done and dusted.",
    "clean as.","mint angle.","walked into it.","that'll do.","easy pick.","job done."
  },
  Death = {
    "ah yep, fair.","got me good.","cop it back.","stiff one.","right in the pride.",
    "yeah nah.","he earned that.","bit dusty, my bad.","timing cooked me.","deserved, tbh."
  },
  Spawn = {
    "back on, mate.","right behind ya.","we're on.","ok, send it.","warming up.",
    "keen.","moving now.","eyes up.","reset and roll.","fresh mags."
  },
  Headshot = { "clean as.","love that.","one click, mate.","bonza flick.","crisp as.","top notch." },
  Revenge  = { "we're square, mate.","that's for before.","all even.","paid in full.","closed the loop." },
  Roadkill = { "mind the ute.","watch the bumper.","bit of hoonery there.","street sweeper.","road's shut." },
  RoundStartGlobal = { "gl hf","have a ripper.","keep it tidy.","no dramas.","play smart." },
  RoundEndGlobal   = { "gg","good on ya.","that was decent.","cheers for the runs.","nice shift." },

  VehicleKill = {
    "armor cracked.","bird down.","vehicle disabled.","tank gone.","pilot's gone.","nice ride - gone.",
    "tracks busted.","driver bailed.","aa down.","rotor stopped.","engine out.","free scrap."
  },
  Multi2 = { "double.","two down.","back to back.","tempo up.","chain started.","keep feeding.","easy two.","momentum." },
  Multi3 = { "triple.","three piece.","they're falling apart.","on a tear.","lining up for me.","ok, who's next?","stack em." },
  Multi4 = { "multi on.","they can't stop me.","too many angles.","stack wiped.","send more, please.","getting rude now :)" },
  Streak = { "on a run.","untouchable.","they can't trade me.","farm mode.","heat check.","stacking bodies.","everything's clicking." },
  Longshot = { "long one.","don't peek at range.","i own that sightline.","distance diff.","postcard from the bush.","too comfy at range." },
  VehEnter = { "taking a ride.","mounting up.","i'm in.","driver ready.","gunning.","vroom." },
  VehExit  = { "bailing.","hopping out.","on foot.","ditch the ride.","ground game now.","fresh air." },
  FirstBlood = { "first blood.","opening pick.","we start strong.","tempo set.","good start.","woke them up." },

  -- Named variants
  KillNamed = {
    "gg {enemy}.","sit down, {enemy}.","trade denied, {enemy}.","peeked wrong, {enemy}.",
    "outplayed, {enemy}.","see you at respawn, {enemy}.","angle was mine, {enemy}."
  },
  HeadshotNamed = {
    "one tap, {enemy}.","keep your head down, {enemy}.","peek punished, {enemy}.","clean head, {enemy}.","crispy on you, {enemy}."
  },
  LongshotNamed = { "long one, {enemy}.","range diff, {enemy}.","eagle eye on you, {enemy}.","greetings from out back, {enemy}." },
  RevengeNamed = { "that's for earlier, {enemy}.","we're even, {enemy}.","payback delivered, {enemy}.","circle closed, {enemy}." },
  VehicleKillNamed = { "bye armor, {enemy}.","driver out, {enemy}.","bird down, {enemy}.","nice ride, {enemy}... was." },
  RoadkillNamed = { "mind the wheels, {enemy}.","hood ornament unlocked, {enemy}.","green light, {enemy}.","street pizza, {enemy}." },
  DeathNamed = { "nice shot, {enemy}.","ok you got me, {enemy}.","pre-aimed me, {enemy}.","good timing, {enemy}.","fair go, {enemy}." },

  -- Weapon-specific
  KnifeKill   = { "shh.","silent op.","that was personal.","slice and dice.","backstab meta.","click-click shank." },
  GrenadeKill = { "cook perfect.","frag lands.","nade out.","catch.","boom timing.","bank shot." },
  ShotgunKill = { "close range diff.","12g says hi.","open the door.","point blank.","boomstick meta." },
  PistolKill  = { "sidearm gaming.","pistol whipped.","secondary supremacy.","tap tap.","backup did it." },
  SniperKill  = { "scope sings.","steady hands.","click at range.","lane owned.","glass cannon online." },
}

AU.Tweaks = { casing = "lower", distort = { emoticonChance = 0.12 } }
AU.PersonalityBias = { Chill = 1.2, Tactical = 1.0, Cocky = 0.9, Sassy = 0.9 }

return { id = "AU", Lines = AU.Lines, Tweaks = AU.Tweaks, PersonalityBias = AU.PersonalityBias }

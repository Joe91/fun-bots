-- ext/Server/BotChatter/Packs/Default.lua
-- Code by: JMDigital (https://github.com/JenkinsTR)
local Lines = {
  Kill = {
    "got em","down he goes","clean shot","too easy","one less headache","bye bye","that'll do",
    "he never saw me","boom","confirmed","next","ez pick","sit down","outplayed","deleted",
    "you peeked wrong","catch you at respawn","timing diff","trade denied","tagged and bagged",
    "held my angle","you walked into that","shoulda stayed home","nice try tho","night night",
    "thanks for the peek","gg on that one","that was free","clean beams","blink and he was gone",
    "i'll take that","click heads, win games","no refunds","satisfying","chef's kiss",
    "stacking bodies, sorry :/ ","too crisp","that angle is mine",

    -- more banter
    "peek-a-boom","map knowledge diff","rotations > reactions","caught window shopping",
    "rent free (for now)","montage material","queue next, buddy","you held w, i held angle",
    "out-rotated","crosshair placement pays","that timing was brutal","spine reset",
    "respect the crossfire","reading you like patch notes","shoulda checked the mini-map",
    "aim lab paid rent","hold that respawn screen","clean transfer","pre-aim wins",
    "thanks for the space","out-macroed","i'll sign for that delivery","right place, right time",
    "late to the trade","that jiggle wasn't enough","free real estate","surgical",
  },

  Death = {
    "ouch","lucky shot","they got me","i'm hit","welp","next life i'm angry",
    "that stung","i'll be back","close one","sniper somewhere","oof","respawning",
    "their angle was better","got beamed","walked right into that","anyone trade him?",
    "naded out","pre-aimed me","crossfired","lost the 50/50","they swung two","timing cursed",
    "that hurt my pride more","deserved tbh","ok you win that","i blinked","hands cold, my bad",
    "nice shot","he earned that one","shoulda jiggle peeked","i'm warmed now",
    "note to self: never again","i respect it","yeah... that tracks","gg on me",
    "mental reset","deep breath","clip it, idc","friendly trade pls?",

    -- more banter
    "fair play","skill issue (mine)","good hold from them","shoulda smoked that",
    "i forgot the mini-map existed","i re-peeked like a bot","timing tax paid",
    "stared at the radar too long","walked into utility","spacing was scuffed",
    "that crosshair was parked on me","they earned that clear","reset brain, try again",
  },

  Spawn = {
    "i'm in","moving","let's roll","rotating","regrouping","back in","on you","flanking","holding",
    "rally","rolling out","swinging wide","i'm up","coming in hot","resetting","cover me, i'm here",
    "hi again :)","fresh mags","ok, focus","we good","small steps","checking corners","eyes open",
    "hands warm now","head in the game","alright, fun time",

    -- more banter
    "same plan, better aim","let's tidy this up","play for trades","work the crossfires",
    "utility first, then faces","i'll entry, trade me","holding space","defaulting first",
    "slow it down, read info","no hero plays, just trades",
  },

  Headshot = {
    "head clean","right between the eyes","hold still next time","peek punished","don't peek me",
    "nice helmet, didn't help","one tap","click","keep your head down","crosshair diff","that was crispy",
    "blame your ping","cold flick","pre-aim gods smile","eyes closed (jk)","tight angle, tighter shot",
    "that was mean :)","goodnight forehead",

    -- more banter
    "mind the melon","cranial clearance approved","forehead check passed","scope said yes",
    "micro-adjust landed","that line was pre-paid","taxed the noggin",
  },

  VehicleKill = {
    "armor cracked","bird down","vehicle disabled","tank gone","pilot's gone","nice ride - gone",
    "tracks busted","driver bailed","aa down","rotor stopped","engine out","bye bye armor",
    "that dash light is permanent","smoking... not in a good way","free scrap metal","warranty voided",

    -- more banter
    "tow bill's on me","control-alt-delete on that chassis","return to sender",
    "lost visual, lost vehicle","maintenance required: everything",
  },

  Multi2 = {
    "double","two down","back to back","tempo up","chain started","keep feeding","snowball rolling","easy 2","momentum",

    -- more banter
    "duo discounted","two-piece special","buy one, tag one",
  },

  Multi3 = {
    "triple","three piece","they're falling apart","keep feeding","on a tear","they're lining up","3 clean","ok, who's next?","stack em",

    -- more banter
    "trifecta online","queue the music","that escalated nicely",
  },

  Multi4 = {
    "multi on","they can't stop me","too many angles","stack wiped","uninstall vibes","they keep peeking","send more, please","this is getting rude :)",

    -- more banter
    "lobby control obtained","that's a highlight reel",
  },

  Streak = {
    "on a run","untouchable","they can't trade me","farm mode","heat check","stacking bodies","pacing the lobby","winning time","snowball secured","everything's clicking",

    -- more banter
    "heater","hands toasty","momentum secured","confidence online",
  },

  Roadkill = {
    "free uber","bumper bonus","tire marks say hi","mind the wheels","oops, hood ornament","road's closed","drive-by diploma","vroom vroom, bye",

    -- more banter
    "pavement patrol","traffic calming measure applied",
  },

  Revenge  = {
    "that's for earlier","we're even","payback delivered","told you i'd be back","balance restored","debt paid","remember me?","circle closed","all squared up",

    -- more banter
    "ledger balanced","bookmark removed","closure achieved",
  },

  Longshot = {
    "long one","don't peek at range","i own that sightline","call me eagle eye","distance diff","scope singing","postcard from downtown","too comfy at range",

    -- more banter
    "signed from downtown","wind checked, shot sent","lane belongs to me",
  },

  VehEnter = {
    "taking a ride","mounting up","i'm in","driver ready","gunning","shotgun seat","vroom","mobile now",

    -- more banter
    "keys acquired","ride online",
  },

  VehExit  = {
    "bailing","hopping out","out","on foot","ditch the ride","ground game now","parking here","fresh air","legs online",

    -- more banter
    "handbrake on","tires cooled",
  },

  FirstBlood = {
    "first blood","opening pick","we start strong","tempo set","good start","that wakes them up","hello momentum",

    -- more banter
    "door opened","table set","tone established",
  },

  -- Named variants (use {enemy})
  KillNamed = {
    "gg {enemy}","sit down, {enemy}","tagged you, {enemy}","trade denied, {enemy}",
    "peeked wrong, {enemy}","walked into it, {enemy}","outplayed, {enemy}",
    "see you at respawn, {enemy}","that angle was mine, {enemy}","nice try, {enemy}",

    -- more banter
    "timing diff on you, {enemy}","map read you, {enemy}","pre-aim landed, {enemy}",
    "caught you switching, {enemy}","clean punish, {enemy}",
  },

  HeadshotNamed = {
    "one tap, {enemy}","keep your head down, {enemy}","peek punished, {enemy}",
    "clean head, {enemy}","crispy on you, {enemy}","shoulda ducked, {enemy}",

    -- more banter
    "forehead tax, {enemy}","mind the melon, {enemy}",
  },

  LongshotNamed = {
    "long one, {enemy}","range diff, {enemy}","eagle eye on you, {enemy}","greetings from far away, {enemy}",

    -- more banter
    "postcard delivered, {enemy}","scope said yes, {enemy}",
  },

  RevengeNamed = {
    "that's for earlier, {enemy}","we're even, {enemy}","payback delivered, {enemy}","circle closed, {enemy}",

    -- more banter
    "ledger balanced, {enemy}","tab closed, {enemy}",
  },

  VehicleKillNamed = {
    "bye armor, {enemy}","driver out, {enemy}","bird down, {enemy}","nice ride, {enemy}... was",

    -- more banter
    "tow truck for you, {enemy}","service light on, {enemy}",
  },

  RoadkillNamed = {
    "mind the wheels, {enemy}","street pizza, {enemy}","hood ornament unlocked, {enemy}","green light, {enemy}",

    -- more banter
    "crosswalk denied, {enemy}","traffic stop, {enemy}",
  },

  DeathNamed = {
    "nice shot, {enemy}","ok you got me, {enemy}","pre-aimed me, {enemy}","good timing, {enemy}","alright fair, {enemy}","respect, {enemy}",

    -- more banter
    "clean clear, {enemy}","earned it, {enemy}","you read me, {enemy}",
  },

  -- Weapon-specific
  KnifeKill   = { "shh","silent op","that was personal","slice and dice","backstab meta","click-click shank",
    -- more banter
    "quiet paperwork","sharp decisions",
  },
  GrenadeKill = { "cook perfect","frag lands","nade out","catch","boom timing","bank shot",
    -- more banter
    "delivered with a timer","package signed",
  },
  ShotgunKill = { "close range diff","12g says hi","open the door","point blank","boomstick meta",
    -- more banter
    "door breacher moment","knock-knock resolved",
  },
  PistolKill  = { "sidearm gaming","pistol whipped","secondary supremacy","tap tap","backup did it",
    -- more banter
    "budget aim, premium result","sidearm clutch",
  },
  SniperKill  = { "glass cannon online","scope sings","steady hands","click at range","lane owned",
    -- more banter
    "breath held, shot sent","threaded the needle",
  },
}

local Replies = {
  VictimKilled   = { "gg", "bruh", "ok fair", "nice one", "you got me", "revenge incoming" },
  VictimHeadshot = { "gs", "clean head", "ouch, nice shot" },
  VictimLongshot = { "how far was that?", "from downtown, huh?" },
  VictimRoadkill = { "watch the road!", "bruh what?", "I don't remember ordering an uber..." },
  VictimRevenge  = { "we're even", "I had that coming" },

  AllyDown       = { "we'll trade that", "stay tight", "i saw that", "on my way" },
  Cheer          = { "nice pick", "keep it up", "tempo!", "clean" },
}

local RepliesNamed = {
  VictimKilled   = { "gg {enemy}", "nice shot, {enemy}" },
  VictimHeadshot = { "gs {enemy}", "ok {enemy}, clean" },
  VictimLongshot = { "range diff, {enemy}", "ok sniper, {enemy}" },
  VictimRoadkill = { "bumper bonus huh, {enemy}", "mind the wheels, {enemy}" },
  VictimRevenge  = { "all square, {enemy}" },

  AllyDown       = { "we'll get {enemy} back", "trade {enemy} now" },
  Cheer          = { "nice one {enemy}", "keep farming {enemy}" },
}

return {
  id = "Default",
  Lines = Lines,
  Replies = Replies,
  RepliesNamed = RepliesNamed,

  -- Optional: pack-level tweaks (merged with global config)
  Tweaks = {
    casing = "lower",   -- "lower" | "asis"
    distort = {
      emoticonChance = 0.10
    },
  },

  -- Optional: bias personalities for this pack (weights)
  PersonalityBias = {
    Chill = 1.0, Cocky = 1.0, Tactical = 1.0, Sassy = 1.0
  }
}

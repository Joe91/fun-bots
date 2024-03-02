---@enum BotBehavior
BotBehavior = {
	Default = 0,        --Like before
	DontShootBackBail = 1, --On Attack, try to run away
	DontShootBackHide = 2, --On Attack, try to crouch away, if far enough away
	AbortAttackFast = 3, --Only attack once, then continue
	LongerAttacking = 4, --Don't abort attack that fast
	LovesExplosives = 5, --use Rockets, and Nades more often
	LovesPistols = 6,   --always switches to pistol if close enough
	COUNT = 7           --
}

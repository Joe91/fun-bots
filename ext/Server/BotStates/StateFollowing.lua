---@class StateFollowing
---@overload fun():StateFollowing
StateFollowing = class('StateFollowing')

-- this class handles the following things:
-- - following a player in formation
-- - providing cover fire
-- - defensive behaviors when stationary

-- transitions to:
-- - attacking (if enemy spotted)
-- - moving (if follow target lost)
-- - idle (on death)

-- bot-methods
local m_BotMovement = require('Bot/BotMovement')
local m_BotWeaponHandling = require('Bot/BotWeaponHandling')

function StateFollowing:__init()
    -- Nothing to do.
end

---default update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateFollowing:Update(p_Bot, p_DeltaTime)
    -- transition to other states:
    if p_Bot.m_Player.soldier == nil then
        p_Bot:SetState(g_BotStates.States.Idle)
        return
    end

    -- Check if follow target is still valid
    -- destroyed / disconnected / team-swap / not spawned
    if p_Bot._FollowTargetPlayer == nil or
        p_Bot._FollowTargetPlayer.id == nil or
        p_Bot._FollowTargetPlayer.alive == false or
        p_Bot._FollowTargetPlayer.soldier == nil or
        p_Bot._FollowTargetPlayer.teamId ~= p_Bot.m_Player.teamId then
        p_Bot._FollowTargetPlayer = nil -- clear ref
        p_Bot:SetState(g_BotStates.States.Moving)
        return
    end

    -- transition to attacking if enemy spotted
    if p_Bot._ShootPlayer ~= nil then
        p_Bot:SetState(g_BotStates.States.Attacking)
        return
    end

    -- update state-timer
    p_Bot.m_StateTimer = p_Bot.m_StateTimer + p_DeltaTime

    -- default-handling
    m_BotWeaponHandling:UpdateWeaponSelection(p_DeltaTime, p_Bot)

    -- Use the existing BotMovement following logic
    m_BotMovement:UpdateFollowingMovement(p_DeltaTime, p_Bot)
    m_BotMovement:UpdateSpeedOfMovement(p_Bot)

    p_Bot:_UpdateInputs(p_DeltaTime)
end

---fast update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateFollowing:UpdateFast(p_Bot, p_DeltaTime)
end

---update in every frame
---@param p_Bot Bot
function StateFollowing:UpdateVeryFast(p_Bot)
    -- Update yaw of soldier every tick.
    m_BotMovement:UpdateYaw(p_Bot)
end

---slow update-function
---@param p_Bot Bot
---@param p_DeltaTime number
function StateFollowing:UpdateSlow(p_Bot, p_DeltaTime)
    m_BotWeaponHandling:UpdateDeployAndReload(p_DeltaTime, p_Bot, true)
end

if g_StateFollowing == nil then
    ---@type StateFollowing
    g_StateFollowing = StateFollowing()
end

return g_StateFollowing

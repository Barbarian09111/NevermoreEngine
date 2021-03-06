--- Makes playing and loading tracks into a humanoid easy
-- @classmod AnimationPlayer

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")

local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer
AnimationPlayer.ClassName = "AnimationPlayer"

--- Constructs a new animation player
-- @constructor
-- @tparam humanoid humanoid
function AnimationPlayer.new(humanoid)
	local self = setmetatable({}, AnimationPlayer)

	self._humanoid = humanoid or error("No humanoid")
	self._tracks = {}
	self._fadeTime = 0.4 -- Default

	self.TrackPlayed = Signal.new()

	return self
end

--- Adds an animation to use
function AnimationPlayer:WithAnimation(animation)
	self._tracks[animation.Name] = self._humanoid:LoadAnimation(animation)

	return self
end

--- Adds an animation to play
function AnimationPlayer:AddAnimation(name, animationId)
	local animation = Instance.new("Animation")

	if tonumber(animationId) then
		animation.AnimationId = "http://www.roblox.com/Asset?ID=" .. tonumber(animationId) or error("No animationId")
	else
		animation.AnimationId = animationId
	end

	animation.Name = name or error("No name")

	return self:WithAnimation(animation)
end

--- Returns a track in the player
function AnimationPlayer:GetTrack(trackName)
	return self._tracks[trackName] or error("Track does not exist")
end

---Plays a track
-- @tparam string trackName Name of the track to play
-- @tparam[opt=0.4] number fadeTime How much time it will take to transition into the animation.
-- @tparam[opt=1] number Weight Acts as a multiplier for the offsets and rotations of the playing animation
	-- This parameter is extremely unstable.
	-- Any parameter higher than 1.5 will result in very shaky motion, and any parameter higher '
	-- than 2 will almost always result in NAN errors. Use with caution.
-- @tparam[opt=1] number Speed The time scale of the animation.
	-- Setting this to 2 will make the animation 2x faster, and setting it to 0.5 will make it
	-- run 2x slower.
-- @tparam[opt=0.4] number stopFadeTime
function AnimationPlayer:PlayTrack(trackName, fadeTime, weight, speed, stopFadeTime)
	fadeTime = fadeTime or self._fadeTime
	local track = self:GetTrack(trackName)

	if not track.IsPlaying then
		self.TrackPlayed:Fire(trackName, fadeTime, weight, speed, stopFadeTime)

		self:StopAllTracks(stopFadeTime or fadeTime)
		track:Play(fadeTime, weight, speed)
	end

	return track
end

--- Stops a track from being played
-- @tparam string trackName
-- @tparam[opt=0.4] number fadeTime
-- @treturn AnimationTrack
function AnimationPlayer:StopTrack(trackName, fadeTime)
	fadeTime = fadeTime or self._fadeTime

	local track = self:GetTrack(trackName)

	track:Stop(fadeTime)

	return track
end

--- Stops all tracks playing
function AnimationPlayer:StopAllTracks(fadeTime)
	for trackName, _ in pairs(self._tracks) do
		self:StopTrack(trackName, fadeTime)
	end
end

---
function AnimationPlayer:Destroy()
	self:StopAllTracks()
	setmetatable(self, nil)
end

return AnimationPlayer
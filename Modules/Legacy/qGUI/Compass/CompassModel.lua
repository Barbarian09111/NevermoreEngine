-- CompassModel.lua
-- Provides basic inertia math for a compass

local CompassModel = {}
CompassModel.__index = CompassModel
CompassModel.ClassName = "CompassModel"

local TAU = math.pi * 2

--- Identifies the direction to rotate given the last rotation and the current rotation.
-- @param LastRotation The last rotation (in radians).
-- @param CurrentRotation The current rotation
-- @return RotationDirection If positive, then you should add, otherwise, subtract (Will return 1 or -1)
-- @return ChangeInRotation The amount changed (Basically, the difference between the two points). This is returned so you can
--                        scale the compass. (In radians)
function CompassModel.GetRotationDirection(LastRotation, CurrentRotation)
	local RotationDirection
	local Difference = math.abs(CurrentRotation - LastRotation) % TAU;
	local ChangeInRotation = math.min(TAU - Difference, Difference)

	if ((CurrentRotation - LastRotation + TAU) % TAU < math.pi) then
		RotationDirection = 1
	else
		RotationDirection = -1
	end

	return RotationDirection, ChangeInRotation
end

-- Get's a camera's XZ plane rotation (Rotation along the Y axis) in radians
-- @param CoordinateFrame The CoordinateFrame of the camera
-- @param Focus The focus of the camera
-- 0 degrees is north (I think?)
function CompassModel.GetCameraRotation(CoordinateFrame, Focus)
	return math.atan2(CoordinateFrame.X - Focus.X, CoordinateFrame.Z - Focus.Z) + math.pi
end

--- This is an inertia model compass thing.
-- @param Camera The camera to get the relative angle on.
function CompassModel.new(Camera)
	local self = setmetatable({}, CompassModel)

	self.Camera           = Camera or error("No camera")
	self.SmoothnessFactor = 4 -- The "smoothing" factor of compass model. Increase for a faster speed.
	self.RealAngle        = 0 -- The real angle of the camera.
	self.Angle            = 0 -- Smoothed angle

	self.LastUpdatePoint = tick()

	return self
end

--- Updates the compass, with "step." Should be called to refresh the model, and will update the spin accordingly.
-- With a "low" step-time (that is, more than 1 second or something) compass may spin super fast, jumping around. Adjust smoothness factor or something to compensate.
-- @return Angle Number in radians, the angle of the compass
-- @reutnr RealAngle Number in radians, the real angle of the camera, aka the "target"
function CompassModel:Step()
	local CurrentTime = tick()
	local Delta = CurrentTime - self.LastUpdatePoint
	local Rotation = CompassModel.GetCameraRotation(self.Camera.CoordinateFrame, self.Camera.Focus)
	self.RealAngle = Rotation

	-- Target self.RealAngle
	local Direction, ChangeInRotation = CompassModel.GetRotationDirection(self.Angle, Rotation)
	self.Angle = math.abs((self.Angle + Direction * ChangeInRotation * Delta * self.SmoothnessFactor) % TAU)

	self.LastUpdatePoint = CurrentTime

	return self.Angle, self.RealAngle
end

--- Returns the smoothed angle
function CompassModel:GetAngle()
	return self.Angle
end

--- Return's the actual angle of the camera.
function CompassModel:GetRealAngle()

	return self.RealAngle
end

--- Set's the smoothness factor of the inertia compass.
-- @param NewSmoothnessFactor The smoothness factor. (Number)
function CompassModel:SetSmoothnessFactor(NewSmoothnessFactor)
	assert(type(NewSmoothnessFactor) == "number")

	self.SmoothnessFactor = NewSmoothnessFactor
end

--- Get's the relative angle from the camera to a "target" position in the world coordinates.
-- @param TargetPosition The world target position.
-- @pre Step has been called.

function CompassModel:GetRelativeAngle(TargetPosition)
	local RelativeAngle = CompassModel.GetCameraRotation(self.Camera.CoordinateFrame, TargetPosition)

	return RelativeAngle
end

--- Get's a percent position for a GUI. Tries to handle the wrap-around based upon CurrentAngle and Angle.
-- @param Angle The angle that the percent is needed.
-- @param ThetaVisible The area shown by the compass (the rest will be hidden). (In radians)
-- @return Percent in [0, 1]. May be greater than range (for scaling purposes).
function CompassModel:GetPercentPosition(Angle, ThetaVisible)
	local CurrentAngle = self:GetAngle()

	local SmallBounds = Angle - ThetaVisible/2
	local RelativeAngle = CurrentAngle - SmallBounds
	local PercentPosition = RelativeAngle / ThetaVisible

	local MaximumPercent = TAU / ThetaVisible
	local SwitchPoint = MaximumPercent/2 -- The point left, or right, where it will "switch" over to be on the other side (Aka wrap around).

	if PercentPosition < -SwitchPoint + ThetaVisible/2 then -- Factor in the "shown" area to when it'll switch over.
		return PercentPosition + MaximumPercent
	elseif PercentPosition > SwitchPoint then
		return PercentPosition - MaximumPercent
	else
		return PercentPosition
	end
end

return CompassModel
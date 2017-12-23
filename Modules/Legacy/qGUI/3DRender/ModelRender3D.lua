local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local ScreenSpace = require("ScreenSpace")

-- @author Quenty

local ModelRender3D = {}
ModelRender3D.__index = ModelRender3D

function ModelRender3D.new()
	local self = setmetatable({}, ModelRender3D)
	
	self.RelativeRotation = CFrame.new()
	self.Scale = 1
	
	return self
end

function ModelRender3D:SetGui(Gui)
	self.Gui = Gui
end

function ModelRender3D:SetModel(Model)
	self.Model = Model
	
	if Model then
		assert(Model.PrimaryPart, "Model needs primary part")
		self.PrimaryPart = Model.PrimaryPart
	else
		self.PrimaryPart = nil
	end
end

function ModelRender3D:GetModel()
	return self.Model
end

function ModelRender3D:SetRelativeRotation(CFrameRotation)
	self.RelativeRotation = CFrameRotation or error("No CFrame rotation")
end

function ModelRender3D:GetModelWidth()
	local ModelSize = self.Model:GetExtentsSize() * self.Scale
	return math.max(ModelSize.X, ModelSize.Y, ModelSize.Z)--ModelSize.X-- math.sqrt(ModelSize.X^2+ModelSize.Z^2)
end

function ModelRender3D:UseScale(Scale)
	-- @param Scale Can be a Vector3 or Number value
	
	self.Scale = Scale -- A zoom factor, used to compensate when GetExtentsSize fails.
end

function ModelRender3D:GetPrimaryCFrame()
	if self.Gui and self.Model then
		local Frame = self.Gui
		
		local FrameAbsoluteSize = Frame.AbsoluteSize
		local FrameCenter = Frame.AbsolutePosition + FrameAbsoluteSize/2 -- Center of the frame.
		
		local Depth = ScreenSpace.GetDepthForWidth(FrameAbsoluteSize.X, self:GetModelWidth())
		
		local Position = ScreenSpace.ScreenToWorld(FrameCenter.X, FrameCenter.Y, Depth)
		
		local AdorneeCFrame = workspace.CurrentCamera.CoordinateFrame
			* (CFrame.new(Position, Vector3.new(0, 0, 0)) * self.RelativeRotation)

		return AdorneeCFrame
	else
		warn("ModelRender3D cannot update model render, GUI or model aren't there.")
	end
end

return ModelRender3D
--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @classmod Promise
-- See: https://promisesaplus.com/

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

local function _isCallable(Value)
	if type(Value) == "function" then
		return true
	elseif type(Value) == "table" then
		local Metatable = getmetatable(Value)
		return Metatable and type(Metatable.__call) == "function"
	end
end

local function _isSignal(Value)
	if typeof(Value) == "RBXScriptSignal" then
		return true
	elseif type(Value) == "table" and _isCallable(Value.Connect) then
		return true
	end

	return false
end

local function _isPromise(Value)
	if type(Value) == "table" and Promise.ClassName == "Promise" then
		return true
	end
	return false
end

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise

--- Construct a new promise
-- @constructor Promise.new()
-- @param Value, default nil
-- @treturn Promise
function Promise.new(Value)
	local self = setmetatable({}, Promise)

	self.PendingMaid = MakeMaid()

	self:_promisify(Value)

	return self
end

--- Returns the value of the first promise resolved
-- @constructor First
-- @tparam Array(Promise) Promises
-- @treturn Promise Promise that resolves with first result  
function Promise.First(Promises)
	local Promise2 = Promise.new()

	local function Syncronize(Method)
		return function(...)
			Promise2[Method](Promise2, ...)
		end
	end

	for _, Promise in pairs(Promises) do
		Promise:Then(Syncronize("Fulfill"), Syncronize("Reject"))
	end

	return Promise2
end

---
-- @constructor First
-- @treturn Promise
function Promise.Promisfy(Function)
	return function(...)
		local Args = {...}
		return Promise.new(function()
			Function(unpack(Args))
		end)
	end
end

---
-- @constructor First
-- @treturn Promise
function Promise.All(Promises)
	local RemainingCount = #Promises
	local Promise2 = Promise.new()
	local Results = {}
	local AllFuilfilled = true

	local function Syncronize(Index, IsFullfilled)
		return function(Value)
			AllFuilfilled = AllFuilfilled and IsFullfilled
			Results[Index] = Value
			RemainingCount = RemainingCount - 1
			if RemainingCount == 0 then
				local Method = AllFuilfilled and "Fulfill" or "Reject"
				Promise2[Method](Promise2, unpack(Results))
			end
		end
	end

	for Index, Item in pairs(Promises) do
		Item:Then(Syncronize(Index, true), Syncronize(Index, false))
	end

	return Promise2
end

--- Returns whether or not the promise is pending
-- @treturn bool True if pending, false otherwise
function Promise:IsPending()
	return self.PendingMaid ~= nil
end


---
-- Resolves a promise
-- @treturn nil
function Promise:Resolve(Value)
	if self == Value then
		self:Reject("TypeError: Resolved to self")
		return
	end

	if _isPromise(Value) then
		Value:Then(function(...)
			self:Fulfill(...)
		end, function(...)
			self:Reject(...)
		end)
		return
	end

	-- Thenable like objects
	if type(Value) == "table" and _isCallable(Value.Then) then
		Value:Then(self:_getResolveReject())
		return
	end

	self:Fulfill(Value)
end

--- Fulfills the promise with the value
-- @param ... Params to fulfill with
-- @treturn nil
function Promise:Fulfill(...)
	if not self:IsPending() then
		return
	end

	self.Fulfilled = {...}
	self:_endPending()
end

--- Rejects the promise with the value given
-- @param ... Params to reject with
-- @treturn nil
function Promise:Reject(...)
	if not self:IsPending() then
		return
	end

	self.Rejected = {...}
	self:_endPending()
end

--- Handlers when promise is fulfilled/rejected
-- @tparam[opt=nil] function OnFulfilled Called when fulfilled with parameters
-- @tparam[opt=nil] function OnRejected Called when rejected with parameters
-- @treturn Promise
function Promise:Then(OnFulfilled, OnRejected)
	local ReturnPromise = Promise.new()

	if self.PendingMaid then
		self.PendingMaid:GiveTask(function()
			self:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
		end)
	else
		self:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
	end
	
	return ReturnPromise
end

--- Catch errors from the promise
-- @treturn Promise
function Promise:Catch(Function)
	return self:Then(nil, Function)
end

--- Rejects the current promise. 
-- Utility left for Maid task
-- @treturn nil
function Promise:Destroy()
	self:Reject()
end

--- Modifies values into promises
-- @local
function Promise:_promisify(Value)
	if _isCallable(Value) then
		self:_promisfyYieldingFunction(Value)
	elseif _isSignal(Value) then
		self:_promisfySignal(Value)
	end
end

function Promise:_promisfySignal(Signal)
	if not self.PendingMaid then
		return
	end

	self.PendingMaid:GiveTask(Signal:Connect(function(...)
		self:Fulfill(...)
	end))

	return
end

function Promise:_promisfyYieldingFunction(YieldingFunction)
	if not self.PendingMaid then
		return
	end

	local Maid = MakeMaid()

	-- Hack to spawn new thread fast
	local BindableEvent = Instance.new("BindableEvent")
	Maid:GiveTask(BindableEvent)
	Maid:GiveTask(BindableEvent.Event:Connect(function()
		Maid:DoCleaning()
		self:Resolve(YieldingFunction(self:_getResolveReject()))
	end))
	self.PendingMaid:GiveTask(Maid)
	BindableEvent:Fire()
end

function Promise:_getResolveReject()
	local Called = false

	local function ResolvePromise(Value)
		if Called then
			return
		end
		Called = true
		self:Resolve(Value)
	end

	local function RejectPromise(Reason)
		if Called then
			return
		end
		Called = true
		self:Reject(Reason)
	end

	return ResolvePromise, RejectPromise
end

function Promise:_executeThen(ReturnPromise, OnFulfilled, OnRejected)
	local Results
	if self.Fulfilled then
		if _isCallable(OnFulfilled) then
			Results = {OnFulfilled(unpack(self.Fulfilled))}
		else
			ReturnPromise:Fulfill(unpack(self.Fulfilled))
		end
	elseif self.Rejected then
		if _isCallable(OnRejected) then
			Results = {OnRejected(unpack(self.Rejected))}
		else
			ReturnPromise:Reject(unpack(self.Rejected))
		end
	else
		error("Internal error, cannot execute while pending")
	end

	if Results and #Results > 0 then
		ReturnPromise:Resolve(Results[1])
	end
end

function Promise:_endPending()
	local Maid = self.PendingMaid
	self.PendingMaid = nil
	Maid:DoCleaning()
end

return Promise
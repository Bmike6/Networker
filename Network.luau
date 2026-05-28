--!strict
local _eventClass=require(script._eventClass)
local Network:Net={}::Net

--[[

	TODO
	
	Make rate limit of yieled threads so client cannot overwhelm server
	Also make player limit for running courutine yields so they cannot spam multiple threads
	

]]






export type Net = {
	isServer:boolean,
	create:()->Net,
	__index:Net,

	--[[   FIELDS          ]]
	_BoundEvents:{Event},
	_BoundEventID:{[string]:number},
	_Event:RemoteEvent,
	_ServerCrossComm:BindableEvent,


	--[[   COMMRENEC             ]]
	_Get:RemoteFunction,
	_ServerCrossCommGet:BindableEvent,
	playersConnected:{Player},
	
	post:(self:Net, _event:string, plr:Player?, ...any)->(),
	postAll:(Self:Net, _event:string, ...any)->(),
	
	get:(self:Net, _event:string, plr:Player?, ...any)->(),
	getAll:(self:Net, _event:string, ...any)->(),
	
	
	
}
type Event=_eventClass.Event
Network.__index=Network




Network.create = function():Net
	local IsServer=game:GetService("RunService"):IsServer()
	local events= IsServer and require(script._eventsServer) or require(script._eventsClient)
	local self={}
	
	self.IsServer=IsServer
	self._BoundEvents=events.eventData
	self._BoundEventID=events.eventDataID
	
	
	
	if not game.ReplicatedStorage:FindFirstChild("NetworkEvents") and self.IsServer then
		local NetworkEvents = Instance.new("Folder")
		local _Get=Instance.new("RemoteFunction")
		local _Event = Instance.new("RemoteEvent")		

		
		NetworkEvents.Name="NetworkEvents"
		NetworkEvents.Parent=game.ReplicatedStorage
		
		_Get.Name="_Get"
		_Get.Parent=NetworkEvents
		
		_Event.Name='_Event'
		_Event.Parent=NetworkEvents	
	end
	self._Get= (game.ReplicatedStorage:FindFirstChild("NetworkEvents")::Folder):FindFirstChild("_Get")
	self._Event = (game.ReplicatedStorage:FindFirstChild("NetworkEvents")::Folder):FindFirstChild("_Event")
	
	if self.IsServer then
		(self._Get :: RemoteFunction ).OnServerInvoke = function(plr:Player,_eventData:string,...:any)
			if not _eventData or typeof(_eventData)~="string" or not self._BoundEventID[_eventData] then plr:Kick("Unkown error has occured")  return end
			return self._BoundEvents[self._BoundEventID[_eventData] ]._callFunction(plr,...)
		end
		(self._Event :: RemoteEvent ).OnServerEvent:Connect(function(plr:Player,_eventData:string,...:any)
			if not _eventData or typeof(_eventData)~="string" or not self._BoundEventID[_eventData] then plr:Kick("Unkown error has occured") return  end
			 self._BoundEvents[self._BoundEventID[_eventData] ]._callFunction(plr,...)
		end)
	else
		(self._Get :: RemoteFunction ).OnClientInvoke = function(_eventData:string,...:any)
			return self._BoundEvents[self._BoundEventID[_eventData] ]._callFunction(false,...)
		end
		(self._Event :: RemoteEvent ).OnClientEvent:Connect(function(_eventData:string,...:any)
			self._BoundEvents[self._BoundEventID[_eventData] ]._callFunction(false,...)
		end)
	end
	

	return setmetatable(self,Network)::Net
end




function Network:post(eventName:string, plr:Player, ...:any)
	if self.isServer then
		self._Event:FireClient(plr,eventName, ...)
		return
	end
	self._Event:FireServer(eventName, ...)
end

function Network:postAll() -- serv only
	
end

function Network:get(eventName:string, plr:Player, ...:any) -- ALWAYS SPAWN THIS FUNNNNC!!!!!
	local ag={...}
	if self.isServer then
		return self._Get:InvokeClient(plr,eventName, ...)
	end
	return self._Get:InvokeServer(eventName, table.unpack(ag))
end

function Network:getAll(eventName:string, ...:any)
	
end



return Network::Net

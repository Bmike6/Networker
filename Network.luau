--!strict
local _eventClass=require(script._eventClass)
export type Event = { 
	_eventName:string,
	_callFunction:(plr:Player|boolean,...any)->any,
	_lastTimeCalled:number,
	_canBeClientActivated:boolean, -- if boolean<False> then server communicated with server
	_cooldownToBeCalled:number,
}

export type playerNetworkDataSettings={
	maxEventLengthTracker:number,
	canActivateServerEvents:boolean,
	bypassCooldown:boolean,

}

export type playerNetworkData = {
	Player:Player,
	lastCalledEventID:Event|string,
	eventsCalled:{Event},
	settings:playerNetworkDataSettings
}


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
	playersConnected:{[Player]:playerNetworkData},



	post:(self:Net, _event:string, plr:Player?, ...any)->(),
	postAll:(Self:Net, _event:string, ...any)->(),

	get:(self:Net, _event:string, plr:Player?, ...any)->(),
	getAll:(self:Net, _event:string, ...any)->(),
	
	bindNewClient:(self:Net, plr:Player?, playerNetworkDataSettings)->(),
	unbindClient:(self:Net, plr:Player)->(),
}


local Network:Net={}::Net
local adminUsers:{number}={}

--[[

	TODO
	Make rate limit of yieled threads so client cannot overwhelm server
	Also make player limit for running courutine yields so they cannot spam multiple threads
]]
Network.__index=Network




Network.create = function():Net
	local self={}
	local IsServer=game:GetService("RunService"):IsServer()
	local events= IsServer and require(script._eventsServer)(self::Net) or require(script._eventsClient)(self::Net)
	
	
	self.IsServer=IsServer
	self._BoundEvents=events.eventData
	self._BoundEventID=events.eventDataID
	self.playersConnected= {}::{[Player]:playerNetworkData}
	
	
		
	
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
	game.Players.PlayerRemoving:Connect(function(plr) -- cannot rely on client to clean up so server must take iniative
		(self::Net):unbindClient(plr)
	end)
	
	
	if self.IsServer then
		(self._Get :: RemoteFunction ).OnServerInvoke = function(plr:Player,_eventData:string,...:any)
			if not _eventData or typeof(_eventData)~="string" or not self._BoundEventID[_eventData] then plr:Kick("Unkown error has occured")  return end
			if not self.playersConnected[plr] then
				local admin=table.find(adminUsers, plr.UserId);
				(self::Net) :bindNewClient(plr::Player,{
					maxEventLengthTracker=10,
					canActivateServerEvents=admin~=nil,
					bypassCooldown=admin~=nil,
				}::playerNetworkDataSettings)
			end
			if not self._BoundEvents[self._BoundEventID[_eventData] ]._canBeClientActivated and self.playersConnected[plr].settings.canActivateServerEvents then
				plr:Kick("Player tried to activate server only event")
			end
			self.playersConnected[plr].eventsCalled[self.playersConnected[plr].settings.maxEventLengthTracker]=nil
			self.playersConnected[plr].lastCalledEventID=self._BoundEvents[self._BoundEventID[_eventData] ]
			
			table.insert(self.playersConnected[plr].eventsCalled, 1, self.playersConnected[plr].lastCalledEventID::Event )
			
			return self._BoundEvents[self._BoundEventID[_eventData] ]._callFunction(plr,...)
		end
		
		(self._Event :: RemoteEvent ).OnServerEvent:Connect(function(plr:Player,_eventData:string,...:any)
			if not _eventData or typeof(_eventData)~="string" or not self._BoundEventID[_eventData] then plr:Kick("Unkown error has occured") return  end
			if not self.playersConnected[plr] then
				local admin=table.find(adminUsers, plr.UserId);
				(self::Net) :bindNewClient(plr::Player,{
						maxEventLengthTracker=10,
						canActivateServerEvents=admin~=nil,
						bypassCooldown=admin~=nil,
					}::playerNetworkDataSettings)
			end
			
			self.playersConnected[plr].eventsCalled[self.playersConnected[plr].settings.maxEventLengthTracker]=nil
			self.playersConnected[plr].lastCalledEventID=self._BoundEvents[self._BoundEventID[_eventData] ]

			table.insert(self.playersConnected[plr].eventsCalled, 1, self.playersConnected[plr].lastCalledEventID::Event )
			if not self._BoundEvents[self._BoundEventID[_eventData] ]._canBeClientActivated and self.playersConnected[plr].settings.canActivateServerEvents then
				plr:Kick("Player tried to activate server only event")
			end
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


function Network:bindNewClient(player,setting)
	self.playersConnected[player::Player]= {
		eventsCalled={},
		lastCalledEventID="none",
		Player=player,
		settings=setting,
	}::playerNetworkData
end

function Network:unbindClient(plr:Player)
	self.playersConnected[plr]=nil
	--[[  Any client residue add to be rmeoved here  ]]
	
end




function Network:post(eventName:string, plr:Player, ...:any)
	if self.isServer then
		self._Event:FireClient(plr,eventName, ...)
		return
	end
	self._Event:FireServer(eventName, ...)
end

function Network:postAll(event:string, ...) -- serv only
	self._Event:FireAllClients(event,...)
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

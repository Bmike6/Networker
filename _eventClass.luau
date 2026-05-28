--!strict

export type Event = { 
	_eventName:string,
	_callFunction:(plr:Player|boolean,...any)->any,
	_lastTimeCalled:number,
	_canBeClientActivated:boolean, -- if boolean<False> then server communicated with server
}

local eventToID:{ [number]:string}={
	[1]="ReplicateClientScripts",
}




local function createEvent(name:string,clientActivation:boolean ,func:(plr:Player | boolean,...any)->any):Event
	local _eventStructure:Event={
		_eventName=name,
		_callFunction=func,
		_lastTimeCalled=0,
		_canBeClientActivated=clientActivation
	}
	return _eventStructure

end





return createEvent

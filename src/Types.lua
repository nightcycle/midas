-- Packages
local _Package = script.Parent
local _Packages = _Package.Parent
local _Maid = require(_Packages.Maid)
local _Signal = require(_Packages.Signal)

export type State = () -> any?
export type Midas = {
	Instance: Folder?,
	Loaded: boolean,

	OnLoad: _Signal.Signal,
	OnDestroy: _Signal.Signal,
	OnEvent: _Signal.Signal,

	_Maid: _Maid.Maid,

	_Profile: Profile?,
	_Path:string,
	_Player: Player,
	
	_OnClientFire: RemoteEvent?,
	_ClientRegister: RemoteEvent?,
	_GetRenderOutput: RemoteFunction?,

	_IsAlive: boolean,
	_RoundingPrecision: number,
	_Chance: number,
	_IsClientManaged: boolean,

	_Tags: {[string]: boolean},
	_Conditions: {[string]: () -> boolean},
	_States: {[string]: State},
	_FirstFireTick: {[string]: number},
	_LastFireTick: {[string]: number},
	_SeriesSignal: {[string]: _Signal.Signal},
	_Index: {[string]: number},
	_Repetitions: {[string]: number},
	_KeyCount: number,
	__index: Midas,
	__newindex: (self: Midas, index: any, value: State) -> nil,

	SetState: (self: Midas, name: string, state: State) -> nil,
	Destroy: (self: Midas) -> nil,
	SetTag: (self: Midas, tag: string) -> nil,
	RemoveTag: (self: Midas, tag: string) -> nil,
	SetCondition: (self: Midas, key: string, func: () -> boolean) -> nil,
	GetPath: (self: Midas) -> string,
	SetRoundingPrecision: (self: Midas, exp: number?) -> nil,
	Compile: (self: Midas) -> {[string]: any}?,
	GetUTC: (self: Midas, offset: number?) -> string,
	CanFire: (self: Midas) -> boolean,
	Fire: (self: Midas,eventName: string, seriesDuration: number?, includeEndEvent: boolean?) -> nil,
	SetChance: (self: Midas, val: number) -> nil,
	GetBoundStateCount: (self: Midas) -> number,
	new: (player: Player, path: string) -> Midas,
	_Compile: (self: Midas) -> {[string]: any}?,
	_FireSeries: (self: Midas, eventName: string, utc: string, waitDuration: number, includeEndEvent: boolean?) -> nil,
	_FireEvent: (self: Midas, eventName: string, utc: string) -> nil,
	_Fire: (self: Midas, eventName: string, utc: string, seriesDuration: number?, includeEndEvent: boolean?) -> nil,
	_Load: (self: Midas, player: Player, path: string, profile: Profile?, maid: _Maid.Maid, onLoad: _Signal.Signal) -> nil,
}

export type Profile = {
	_Maid: _Maid.Maid,
	Player: Player,
	Instance: Instance,
	EventsPerMinute: number,
	TimeDifference: number,
	_IsAlive: boolean,
	_ConstructionTick: number,
	_IsTeleporting: boolean,
	_WasTeleported: boolean,
	_Index: number,
	_Midaii: {[string]: Midas},
	_PreviousStates: {},
	_SessionId: string?,
	_PlayerId: string?,
	__index: Profile,
	Destroy: (self: Profile) -> nil,
	FireSeries: (self: Profile, midas: Midas, eventName: string, timeStamp: string, eventIndex: number, includeEndEvent: boolean) -> _Signal.Signal,
	Fire: (self: Profile, midas: Midas, eventName: string, timestamp: string, eventIndex: number, duration: number?) -> nil, 
	HasPath: (self: Profile, midas: Midas, path: string) -> boolean,
	DestroyPath: (self: Profile, path: string) -> nil,
	DestroyMidas: (self: Profile, path: string) -> nil,
	GetMidas: (self: Profile, path: string) -> Midas?,
	SetMidas: (self: Profile, midas: Midas) -> nil,
	Teleport: (self: Profile, mExit: Midas?) -> TeleportDataEntry,
	new: (player: Player) -> Profile,
	get:(userId: number) -> Profile?,
	getProfilesFolder: () -> Folder,
	_Fire: (self: Profile, eventFullPath: string, delta: {[string]: any}, tags: {[string]: boolean}, timestamp: string) -> nil,
	_Format: (self: Profile, midas: Midas, eventName: string, delta: {[string]: any}, eventIndex: number, duration: number?, timestamp: string) -> ({[string]: any}, string),
	_Export: (self: Profile) -> TeleportDataEntry,
}



--- @type ConfigurationData {Version: string,SendDeltaState: boolean,SendDataToPlayFab: boolean, Templates: {Join: boolean,Chat: boolean,Population: boolean,ServerPerformance: boolean,Market: boolean,Exit: boolean,Character: boolean,Demographics: boolean,Policy: boolean,ClientPerformance: boolean,Settings: boolean,},}
--- @within Interface

export type ConfigurationData = {
	Version: string,
	SendDeltaState: boolean,
	SendDataToPlayFab: boolean,
	Templates: {
		Join: boolean,
		Chat: boolean,
		Population: boolean,
		ServerPerformance: boolean,
		Market: boolean,
		Exit: boolean,
		Character: boolean,
		Demographics: boolean,
		Policy: boolean,
		ClientPerformance: boolean,
		Settings: boolean,
	},
}

export type TeleportDataEntry = {
	_PreviousStates: {[string]: any},
	_SessionId: string,
	_PlayerId: string,
}

return {}
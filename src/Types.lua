-- Packages
local Package = script.Parent
local Packages = Package.Parent
local _Maid = require(Packages.Maid)
local _Signal = require(Packages.Signal)

export type State = () -> any?

export type PublicMidas = {
	Player: Player,
	Path: string,
	SetState: (self: PublicMidas, name: string, state: State) -> nil,
	Destroy: (self: PublicMidas) -> nil,
	SetTag: (self: PublicMidas, tag: string) -> nil,
	RemoveTag: (self: PublicMidas, tag: string) -> nil,
	SetCondition: (self: PublicMidas, key: string, func: () -> boolean) -> nil,
	GetPath: (self: PublicMidas) -> string,
	SetRoundingPrecision: (self: PublicMidas, exp: number?) -> nil,
	CanFire: (self: PublicMidas) -> boolean,
	Fire: (
		self: PublicMidas,
		eventName: string,
		data: { [string]: any }?,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	SetChance: (self: PublicMidas, val: number) -> nil,
	GetBoundStateCount: (self: PublicMidas) -> number,
}

export type PrivateMidas = {
	_Loaded: boolean,
	_OnLoad: _Signal.Signal,
	_OnDestroy: _Signal.Signal,
	_OnEvent: _Signal.Signal,

	SetState: (self: PrivateMidas, name: string, state: State) -> nil,
	Destroy: (self: PrivateMidas) -> nil,
	SetTag: (self: PrivateMidas, tag: string) -> nil,
	RemoveTag: (self: PrivateMidas, tag: string) -> nil,
	SetCondition: (self: PrivateMidas, key: string, func: () -> boolean) -> nil,
	SetRoundingPrecision: (self: PrivateMidas, exp: number?) -> nil,
	_Compile: (self: PrivateMidas) -> { [string]: any }?,
	_HandleCompile: (self: PrivateMidas) -> { [string]: any }?,
	_GetUTC: (self: PrivateMidas, offset: number?) -> string,
	CanFire: (self: PrivateMidas) -> boolean,
	Fire: (
		self: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	SetChance: (self: PrivateMidas, val: number) -> nil,
	GetBoundStateCount: (self: PrivateMidas) -> number,

	Instance: Folder?,

	_Maid: _Maid.Maid,

	_Profile: Profile?,
	Path: string,
	_Player: Player,
	Player: Player,
	_PlayerName: string,

	_OnClientFire: RemoteEvent?,
	_ClientRegister: RemoteEvent?,
	_GetRenderOutput: RemoteFunction?,

	_IsAlive: boolean,
	_RoundingPrecision: number,
	_Chance: number,
	_IsClientManaged: boolean,

	_Tags: { [string]: boolean },
	_Conditions: { [string]: () -> boolean },
	_States: { [string]: State },
	_FirstFireTick: { [string]: number },
	_LastFireTick: { [string]: number },
	_SeriesSignal: { [string]: _Signal.Signal },
	_Index: { [string]: number },
	_Repetitions: { [string]: number },
	_KeyCount: number,
	__index: PrivateMidas,
	__newindex: (self: PrivateMidas, index: any, value: State) -> nil,

	_new: (player: Player, path: string) -> PrivateMidas,
	_FireSeries: (
		self: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		utc: string,
		waitDuration: number,
		includeEndEvent: boolean?
	) -> nil,
	_FireEvent: (self: PrivateMidas, eventName: string, data: { [string]: any }?, utc: string) -> nil,
	_Fire: (
		self: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		utc: string,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	_Load: (
		self: PrivateMidas,
		player: Player,
		path: string,
		profile: Profile?,
		maid: _Maid.Maid,
		onLoad: _Signal.Signal
	) -> nil,
}

export type Profile = {
	_Maid: _Maid.Maid,
	Player: Player,
	Instance: Instance,
	EventsPerMinute: number,
	TimeDifference: number,
	_IsLoaded: boolean,
	_IsAlive: boolean,
	_ConstructionTick: number,
	_IsTeleporting: boolean,
	_WasTeleported: boolean,
	_Index: number,
	_Midaii: { [string]: PrivateMidas },
	_PreviousStates: {},
	_SessionId: string?,
	_PlayerId: string?,
	__index: Profile,
	Destroy: (self: Profile) -> nil,
	_BytesRemaining: number,
	IncrementIndex: (self: Profile) -> number,
	FireSeries: (
		self: Profile,
		midas: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		timeStamp: string,
		eventIndex: number,
		index: number,
		includeEndEvent: boolean
	) -> _Signal.Signal,
	Fire: (
		self: Profile,
		midas: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		timestamp: string,
		eventIndex: number,
		index: number,
		duration: number?
	) -> nil,
	HasPath: (self: Profile, midas: PrivateMidas, path: string) -> boolean,
	DestroyPath: (self: Profile, path: string) -> nil,
	DestroyMidas: (self: Profile, path: string) -> nil,
	GetMidas: (self: Profile, path: string) -> PrivateMidas?,
	SetMidas: (self: Profile, midas: PrivateMidas) -> nil,
	Teleport: (self: Profile, mExit: PrivateMidas?) -> TeleportDataEntry,
	new: (player: Player) -> Profile,
	get: (userId: number) -> Profile?,
	getProfilesFolder: () -> Folder,
	_Fire: (
		self: Profile,
		eventFullPath: string,
		delta: { [string]: any },
		tags: { [string]: boolean },
		timestamp: string
	) -> nil,
	_Format: (
		self: Profile,
		midas: PrivateMidas,
		eventName: string,
		data: { [string]: any }?,
		delta: { [string]: any },
		eventIndex: number?,
		duration: number?,
		timestamp: string,
		index: number
	) -> ({ [string]: any }, string),
	_Export: (self: Profile) -> TeleportDataEntry,
}

--- @type ConfigurationData {Version: {Major: number,Minor: number,Patch: number,Hotfix: number?,Tag: string?,TestGroup: string?,},SendDeltaState: boolean,PrintLog: boolean,PrintEventsInStudio: boolean,SendDataToPlayFab: boolean, Templates: {Join: boolean,Chat: boolean,Population: boolean,ServerPerformance: boolean,Market: boolean,Exit: boolean,Character: boolean,Demographics: boolean,Policy: boolean,ClientPerformance: boolean,Settings: boolean,ServerIssues: boolean, ClientIssues: boolean, Group: {[string]: number}},}
--- @within Interface
type RecursiveDict<T> = {[string]: T | RecursiveDict<T>}

export type ConfigurationData = {
	Version: {
		Major: number,
		Minor: number,
		Patch: number,
		Hotfix: number?,
		Tag: string?,
		TestGroup: string?,
	},
	BytesPerMinutePerPlayer: number?,
	SendDeltaState: boolean?,
	SendDataToPlayFab: boolean?,
	PrintEventsInStudio: boolean?,
	PrintLog: boolean?,
	Encoding: {
		Marker: string,
		Dictionary: {
			Properties: {[string]: any},
			Values: RecursiveDict<{[string]: string}>
		},
		Arrays: RecursiveDict<{[number]: string}>,
	},
	Templates: {
		Join: boolean?,
		Chat: boolean?,
		Population: boolean?,
		ServerPerformance: boolean?,
		Market: boolean?,
		Exit: boolean?,
		Character: boolean?,
		Demographics: boolean?,
		Policy: boolean?,
		ClientPerformance: boolean?,
		Settings: boolean?,
		ServerIssues: boolean?,
		ClientIssues: boolean?,
		Group: { [string]: number }?,
	},
}

export type TeleportDataEntry = {
	_PreviousStates: { [string]: any },
	_SessionId: string,
	_PlayerId: string,
}

return {}

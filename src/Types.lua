--!strict
-- References
local Package = script.Parent
local Packages = Package.Parent

-- Packages
local Maid = require(Packages:WaitForChild("Maid"))
local Signal = require(Packages:WaitForChild("Signal"))

export type State = () -> any?

export type PublicTracker = {
	Player: Player,
	Path: string,
	SetState: (self: PublicTracker, name: string, state: State) -> nil,
	Destroy: (self: PublicTracker) -> nil,
	SetTag: (self: PublicTracker, tag: string) -> nil,
	RemoveTag: (self: PublicTracker, tag: string) -> nil,
	SetCondition: (self: PublicTracker, key: string, func: () -> boolean) -> nil,
	GetPath: (self: PublicTracker) -> string,
	SetRoundingPrecision: (self: PublicTracker, exp: number?) -> nil,
	CanFire: (self: PublicTracker) -> boolean,
	Fire: (
		self: PublicTracker,
		eventName: string,
		data: { [string]: any }?,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	SetChance: (self: PublicTracker, val: number) -> nil,
	GetBoundStateCount: (self: PublicTracker) -> number,
}

export type PrivateTracker = {
	_Loaded: boolean,
	_OnLoad: Signal.Signal,
	_OnDestroy: Signal.Signal,
	_OnEvent: Signal.Signal,

	SetState: (self: PrivateTracker, name: string, state: State) -> nil,
	Destroy: (self: PrivateTracker) -> nil,
	SetTag: (self: PrivateTracker, tag: string) -> nil,
	RemoveTag: (self: PrivateTracker, tag: string) -> nil,
	SetCondition: (self: PrivateTracker, key: string, func: () -> boolean) -> nil,
	SetRoundingPrecision: (self: PrivateTracker, exp: number?) -> nil,
	_Compile: (self: PrivateTracker) -> { [string]: any }?,
	_HandleCompile: (self: PrivateTracker) -> { [string]: any }?,
	_GetUTC: (self: PrivateTracker, offset: number?) -> string,
	CanFire: (self: PrivateTracker) -> boolean,
	Fire: (
		self: PrivateTracker,
		eventName: string,
		data: { [string]: any }?,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	SetChance: (self: PrivateTracker, val: number) -> nil,
	GetBoundStateCount: (self: PrivateTracker) -> number,

	Instance: Folder?,

	_Maid: Maid.Maid,

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
	_SeriesSignal: { [string]: Signal.Signal },
	_Index: { [string]: number },
	_Repetitions: { [string]: number },
	_KeyCount: number,
	__index: PrivateTracker,
	__newindex: (self: PrivateTracker, index: any, value: State) -> nil,

	_new: (player: Player, path: string, profile: Profile?) -> PrivateTracker,
	_FireSeries: (
		self: PrivateTracker,
		eventName: string,
		data: { [string]: any }?,
		utc: string,
		waitDuration: number,
		includeEndEvent: boolean?
	) -> nil,
	_FireEvent: (self: PrivateTracker, eventName: string, data: { [string]: any }?, utc: string) -> nil,
	_Fire: (
		self: PrivateTracker,
		eventName: string,
		data: { [string]: any }?,
		utc: string,
		seriesDuration: number?,
		includeEndEvent: boolean?
	) -> nil,
	_Load: (
		self: PrivateTracker,
		player: Player,
		path: string,
		profile: Profile?,
		maid: Maid.Maid,
		onLoad: Signal.Signal
	) -> nil,
}

export type Profile = {
	_Maid: Maid.Maid,
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
	_Midaii: { [string]: PrivateTracker },
	_PreviousStates: {},
	_SessionId: string?,
	_PlayerId: string?,
	__index: Profile,
	Destroy: (self: Profile) -> nil,
	_BytesRemaining: number,
	IncrementIndex: (self: Profile) -> number,
	FireSeries: (
		self: Profile,
		tracker: PrivateTracker,
		eventName: string,
		data: { [string]: any }?,
		timeStamp: string,
		eventIndex: number,
		index: number,
		includeEndEvent: boolean
	) -> Signal.Signal,
	Fire: (
		self: Profile,
		tracker: PrivateTracker,
		eventName: string,
		data: { [string]: any }?,
		timestamp: string,
		eventIndex: number,
		index: number,
		duration: number?
	) -> nil,
	HasPath: (self: Profile, tracker: PrivateTracker, path: string) -> boolean,
	DestroyPath: (self: Profile, path: string) -> nil,
	DestroyTracker: (self: Profile, path: string) -> nil,
	GetTracker: (self: Profile, path: string) -> PrivateTracker?,
	SetTracker: (self: Profile, tracker: PrivateTracker) -> nil,
	Teleport: (self: Profile, mExit: PrivateTracker?) -> TeleportDataEntry,
	new: (player: Player) -> Profile,
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
		tracker: PrivateTracker,
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
			Values: {[string]: any},
		},
		Arrays: any, --{[number]: any},
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
		ClientPerformance: boolean?,
		Group: { [string]: number }?,
	},
}

export type TeleportDataEntry = {
	_PreviousStates: { [string]: any },
	_SessionId: string,
	_PlayerId: string,
}

return {}

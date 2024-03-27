# Midas Wally Package
This is a package for the easy tracking and validation of analytics data. The goal is to allow you to track as much data as you want, so you can focus on solving problems with the data, rather than just storing and collecting it in the first place.

## Usage
To seamlessly integrate into the most common standards of data processing workflows, Midas has pivoted away from a free structured tree of data to that of tables.

### 1. Initialize Midas
```lua

	Midas.init()
	Midas.ProjectId = "abcdef1234567"

```

### 2. Define a Storage Solution

#### MongoDB
One solution I personally use is MongoDB Atlas. You can read how to set that up [here](https://www.mongodb.com/docs/atlas/getting-started/), remember to enabled the "Data API" under the "Services" menu. MongoDB offers a terabyte of storage at a reasonable price. To get the data out there are also [many official](https://www.mongodb.com/try/download/shell) MongoDB tools and solutions for that as well.

```lua
	local mongoDB = Midas.StorageProviders.MongoDB.new(
		"api-key-123", 
		"https://us-east-2.aws.data.mongodb-api.com/app/data-abcdef"
	)
	mongoDB.DebugPrintEnabled = RunService:IsStudio()
	Midas:SetOnBatchInsertInvoke(
		function(
			projectId: string,
			dataSetId: string,
			dataTableId: string,
			dataList: { [number]: { [string]: unknown } },
			format: { [string]: DataType },
			onPayloadSizeKnownInvoke:(number) -> ()
		): boolean
			return mongoDB:InsertMany(
				projectId, 
				dataSetId, 
				dataTableId, 
				dataList, 
				format, 
				onPayloadSizeKnownInvoke
			)
		end
	)
```

### 3. Define a Table
```lua
	-- midas accepts the rowData as a variadic type, allowing you to have type safety when recording data
	type RowData = {
		server_id: string,
		session_id: string,
		timestamp: DateTime,
		user_id: number,
		is_premium: boolean,
		friends_in_game: number?,
		pos_x: number?,
		pos_y: number?,
	}

	-- level of organization for datatables
	local dataSet = Midas:CreateDataSet("UserData", "abc123")

	-- a table with rows and columns
	local dataTable = dataSet:CreateDataTable("Session", "def456") :: Midas.DataTable<RowData>
	dataTable:AddColumn("server_id", "String", false)
	dataTable:AddColumn("session_id", "String", false)
	dataTable:AddColumn("timestamp", "Date", false)
	dataTable:AddColumn("user_id", "Int64", false)
	dataTable:AddColumn("friends_in_game", "Int32", true)
	dataTable:AddColumn("is_premium", "boolean", false)
	dataTable:AddColumn("pos_x", "Double", true)
	dataTable:AddColumn("pos_z", "Double", true)

```

### 4. Add Rows
```lua
	local playerPosition: Vector3?

	dataTable:AddRow({
		server_id = game.JobId,
		session_id = "abc-123",
		timestamp = DateTime.now(),
		user_id = 123456,
		is_premium = true,
		friends_in_game = nil,
		pos_x = if playerPosition then playerPosition.X else nil,
		pos_z = if playerPosition then playerPosition.Z else nil,
	})

```

### 5. Post

#### Manual
If you want to post all tables at once you can
```lua
	Midas:Post(50, 400, 1, false)
```

Otherwise if you want to post a specific table that is available as well.
```lua
	dataTable:Post(50, 400)
```

#### Automated
If you just want to forget about posting, you can tell Midas to try to manage it for you.
```lua
	Midas:Automate(RunService:IsStudio())
```


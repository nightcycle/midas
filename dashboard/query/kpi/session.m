let
	Source = events,
	// convert to single session entries
	#"Removed Other Columns" = Table.SelectColumns(
		Source,
		{"Timestamp", "UserId", "SessionId", "PlaceId", "AnalyticsId", "Version", "Index"}
	),
	#"Reordered Columns" = Table.ReorderColumns(
		#"Removed Other Columns",
		{"UserId", "SessionId", "PlaceId", "AnalyticsId", "Version", "Timestamp", "Index"}
	),
	#"Removed Columns" = Table.RemoveColumns(
		#"Reordered Columns",
		{"Index"}
	),
	#"Sorted Rows" = Table.Sort(
		#"Removed Columns",
		{
			{"Timestamp", Order.Ascending}
		}
	),
	#"Grouped Rows" = Table.Group(
		#"Sorted Rows", 
		{"SessionId"}, 
		{
			{
				"Rows", 
				each _, type table [
					UserId=text, 
					SessionId=text, 
					PlaceId=text, 
					AnalyticsId=nullable number, 
					Version=any, Timestamp=
					nullable datetime
				]
			}
		}
	),
	Indexed = Table.TransformColumns(
		#"Grouped Rows", 
		{
			{
				"Rows", 
				each Table.AddIndexColumn(
					_,
					"GroupIndex", 
					1, 
					1
				)
			}
		}
	),
	#"Expanded Rows" = Table.ExpandTableColumn(
		Merged, 
		"Rows", 
		{"UserId", "PlaceId", "AnalyticsId", "Version", "Timestamp", "GroupIndex"}, 
		{"UserId", "PlaceId", "AnalyticsId", "Version", "Timestamp", "GroupIndex"}
	),  
	Maxed = Table.RenameColumns(
		Table.AggregateTableColumn(
			Indexed, 
			"Rows", 
			{
				{"SessionId", List.Count, "RecordedEventCount"}
			}
		),
		{
			{"SessionId", "SessionId.1"}
		}
	),
	Merged = Table.RemoveColumns(
		Table.FuzzyJoin(
			Indexed, 
			{"SessionId"}, 
			Maxed, 
			{"SessionId.1"}, 
			JoinKind.LeftOuter
		) as table,
		{"SessionId.1"}
	),

	//Add duration   
	CleanedUp = Table.SelectColumns(
		Source,
		{"SessionId", "EventName", "Timestamp"}
	),
	Bookends = Table.SelectRows(
		CleanedUp, 
		each ([EventName] <> "UserCharacterDied")
	),
	Starts = Table.Group(
		Bookends, 
		{"SessionId"}, 
		{
			{
				"Start", 
				each List.Min([Timestamp]), 
				type datetime
			}
		}
	),
	Stops = Table.RenameColumns(
		Table.Group(
			Bookends, 
			{"SessionId"}, 
			{
				{
					"Stop", 
					each List.Max([Timestamp]), 
					type datetime
				}
			}
		),
		{
			{"SessionId", "SessionId.1"}
		}
	),
	Result = Table.FuzzyJoin(
		Starts, 
		{"SessionId"}, 
		Stops, 
		{"SessionId.1"}, 
		JoinKind.LeftOuter
	),
	Duration = Table.AddColumn(
		Table.RemoveColumns(
			Result,
			{"SessionId.1"}
		), 
		"Duration", 
		each Duration.TotalSeconds(
			[Stop] - [Start]
		)
	),
	OnlyDuration = Table.SelectColumns(
		Duration,
		{"SessionId", "Duration"}
	),
	DurationTable = Table.RenameColumns(
		Table.Distinct(OnlyDuration, "SessionId"), 
		{"SessionId", "SessionId.1"}
	),
	#"Removed Duplicates" = Table.Distinct(
		DurationTable, 
		{"SessionId.1"}
	), 
	FinalTable = Table.RemoveColumns(
		Table.FuzzyJoin(
			#"Expanded Rows", 
			{"SessionId"}, 
			#"Removed Duplicates", 
			{"SessionId.1"},
			JoinKind.Inner
		) as table,
		{"SessionId.1"}
	),
	#"Removed Duplicates1" = Table.Distinct(
		FinalTable, 
		{"SessionId"}
	),
	#"Changed Type" = Table.TransformColumnTypes(
		#"Removed Duplicates1",
		{
			{"GroupIndex", Int64.Type}, 
			{"Duration", Int64.Type}, 
			{"RecordedEventCount", Int64.Type}
		}
	),
	// add session index
	#"Sorted Rows1" = Table.Sort(
		#"Changed Type",
		{
			{
				"Timestamp", Order.Ascending
			}
		}
	),
	#"Grouped Rows1" = Table.Group(
		#"Sorted Rows1", 
		{"UserId"}, 
		{
			{
				"Rows", 
				each _, type table [
					SessionId=nullable text, 
					UserId=text, 
					PlaceId=text, 
					AnalyticsId=text, 
					Version=any, 
					Timestamp=datetime, 
					GroupIndex=nullable number, 
					RecordedEventCount=nullable number, 
					Duration=nullable number
				]
			}
		}
	),
	SessionIndexed = Table.TransformColumns(
		#"Grouped Rows1", 
		{
			{
				"Rows", 
				each Table.AddIndexColumn(
					_,
					"SessionIndex", 
					1, 
					1
				)
			}
		}
	),
    #"Expanded Rows1" = Table.ExpandTableColumn(
	    SessionIndexed, 
	    "Rows", 
	    {
		    "SessionId", 
		    "UserId", 
		    "PlaceId", 
		    "AnalyticsId", 
		    "Version", 
		    "Timestamp", 
		    "GroupIndex", 
		    "RecordedEventCount", 
		    "Duration", 
		    "SessionIndex"
		}, 
		{
			"SessionId", 
			"UserId.1", 
			"PlaceId", 
			"AnalyticsId", 
			"Version", 
			"Timestamp", 
			"GroupIndex", 
			"RecordedEventCount", 
			"Duration", 
			"SessionIndex"
		}
	),
    #"Removed Columns1" = Table.RemoveColumns(
	    #"Expanded Rows1",
	    {"UserId.1"}
	),
    #"Changed Type1" = Table.TransformColumnTypes(
	    #"Removed Columns1",
	    {
		    {"Duration", Int64.Type}, 
		    {"SessionIndex", Int64.Type}, 
		    {"RecordedEventCount", Int64.Type}, 
		    {"GroupIndex", Int64.Type}
		}
	)
in
    #"Changed Type1"
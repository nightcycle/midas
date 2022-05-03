let
	Source = Csv.Document(
		File.Contents("C:\Users\coyer\OneDrive\Documents\GitHub\strandead\analytics\export.csv"),
		[Delimiter=",", 
		Columns=5, 
		Encoding=65001, 
		QuoteStyle=QuoteStyle.None]
	),
	#"Promoted Headers" = Table.PromoteHeaders(
		Source, 
		[PromoteAllScalars=true]
	),
	#"Changed Type" = Table.TransformColumnTypes(
		#"Promoted Headers",
		{
			{
				"EventId", 
				type text
			}, {
				"Timestamp", 
				type datetime
			}, {
				"EventName", 
				type text
			}, {
				"State", 
				type text
			}, {
				"Version", 
				Int64.Type
			}
		}
	),
	#"Parsed JSON" = Table.TransformColumns(
		#"Changed Type",
		{
			{
				"State", 
				Json.Document  
			}  
		}
	),
	#"Expanded State" = Table.ExpandRecordColumn(
		#"Parsed JSON", 
		"State", 
		{
			"Duration", 
			"Index", 
			"Id", 
			"Chat", 
			"Performance", 
			"Spending", 
			"Population", 
			"Map", 
			"Onboarding", 
			"Gameplay", 
			"Character"
		}, 
		{
			"Duration", 
			"Index", 
			"Id", 
			"Chat", 
			"Performance", 
			"Spending", 
			"Population", 
			"Map", 
			"Onboarding", 
			"Gameplay", 
			"Character"
		}
	),
	#"Expanded Index" = Table.ExpandRecordColumn(
		#"Expanded State", 
		"Index", 
		{
			"Event", 
			"Total"
		}, {
			"EventIndex", 
			"Index"
		}
	),
	#"Renamed Columns" = Table.RenameColumns(
		#"Expanded Index",
		{
			{
				"Version", 
				"AnalyticsId"
			}
		}
	),
	#"Expanded Id" = Table.ExpandRecordColumn(
		#"Renamed Columns", 
		"Id", 
		{
			"Version", 
			"Place", 
			"Session", 
			"User"
		}, {
			"Version", 
			"PlaceId", 
			"SessionId", 
			"UserId"
		}
	),
	#"Renamed Columns1" = Table.RenameColumns(
		#"Expanded Id",
		{
			{
				"Duration", 
				"SeriesDuration"
			}
		}
	),
	#"Filtered Rows1" = Table.SelectRows(
		#"Renamed Columns1", 
		each ([SessionId] <> null)
	),
	#"Grouped Rows" = Table.Group(
		#"Filtered Rows1",
		{"SessionId"}, 
		{
			{
				"Rows", 
				each _, 
				type table [
					EventId=nullable text, 
					Timestamp=nullable datetime, 
					EventName=nullable text, 
					SeriesDuration=number, 
					EventIndex=number, 
					Index=number, 
					Version=nullable record, 
					PlaceId=text, 
					SessionId=text, 
					UserId=text, 
					Chat=nullable record, 
					Performance=nullable record, 
					Spending=nullable record, 
					Population=nullable record, 
					Map=nullable record, 
					Onboarding=nullable record, 
					Gameplay=nullable record, 
					Character=any, 
					AnalyticsId=nullable number
				]
			}
		}
	),
	#"Sorted Rows" = Table.Sort(
		#"Grouped Rows",{
			{
				"SessionId", 
				Order.Ascending
			}
		}
	),
	Sorted = Table.TransformColumns(
		#"Sorted Rows",
		{
			"Rows", 
			each Table.Sort(
				_,
				{
					"Timestamp", 
					Order.Ascending
				}
			)
		}
	),
	Indexed = Table.TransformColumns(
		Sorted, 
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
	Filled = Table.TransformColumns(
		Indexed,
		{
			"Rows", 
			each Table.FillDown(
				_, 
				{
					"Version", 
					"Chat", 
					"Spending", 
					"Map", 
					"Character", 
					"Gameplay", 
					"Performance", 
					"Population", 
					"Onboarding"
				}
			)
		}
	),
	#"Expanded Rows" = Table.ExpandTableColumn(
		Filled, 
		"Rows", 
		{
			"EventId", 
			"Timestamp", 
			"EventName", 
			"SeriesDuration", 
			"EventIndex", 
			"Index", 
			"Version", 
			"PlaceId", 
			"SessionId", 
			"UserId", 
			"Chat", 
			"Performance", 
			"Spending", 
			"Population", 
			"Map", 
			"Onboarding", 
			"Gameplay", 
			"Character", 
			"AnalyticsId", 
			"GroupIndex"
		}, {
			"EventId", 
			"Timestamp", 
			"EventName", 
			"SeriesDuration",
			"EventIndex", 
			"Index", 
			"Version", 
			"PlaceId", 
			"SessionId.1", 
			"UserId", 
			"Chat", 
			"Performance", 
			"Spending", 
			"Population", 
			"Map", 
			"Onboarding", 
			"Gameplay", 
			"Character", 
			"AnalyticsId", 
			"GroupIndex"
		}
	),
	#"Renamed Columns2" = Table.RenameColumns(
		#"Expanded Rows",
		{
			{
				"GroupIndex", 
				"RecordedIndex"
			}
		}
	),
	#"Changed Type1" = Table.TransformColumnTypes(
		#"Renamed Columns2",
		{
			{
				"SessionId", 
				type text
			}, {
				"EventId", 
				type text
			}, {
				"UserId", 
				type text
			}, {
				"PlaceId", 
				type text
			}, {
				"AnalyticsId", 
				type text
			}, {
				"Index", 
				Int64.Type
			}, {
				"EventIndex", 
				Int64.Type
			}, {
				"SeriesDuration", 
				Int64.Type
			}
		}
	),
	#"Removed Duplicates" = Table.Distinct(
		#"Changed Type1", 
		{
			"EventId"
		}
	),
	#"Reordered Columns" = Table.ReorderColumns(
		#"Removed Duplicates",
		{
			"SessionId", 
			"Timestamp", 
			"EventId", 
			"EventName", 
			"SeriesDuration", 
			"EventIndex", 
			"Index", 
			"Version", 
			"PlaceId", 
			"SessionId.1", 
			"UserId", 
			"Chat", 
			"Performance", 
			"Spending", 
			"Population", 
			"Map", 
			"Onboarding", 
			"Gameplay", 
			"Character", 
			"AnalyticsId", 
			"RecordedIndex"
		}
	),
	#"Removed Columns" = Table.RemoveColumns(
		#"Reordered Columns",
		{
			"SessionId.1"
		}
	)
in
	#"Removed Columns"
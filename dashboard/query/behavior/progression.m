let
	Source = events,
	// clean up data
	#"Removed Other Columns" = Table.SelectColumns(
		Source, 
		{
			"RecordedIndex", 
			"Index", 
			"EventIndex", 
			"EventName", 
			"EventId", 
			"Timestamp", 
			"SessionId"
		}
	), 
	#"Reordered Columns" = Table.ReorderColumns(
		#"Removed Other Columns", 
		{
			"Timestamp", 
			"RecordedIndex", 
			"Index", 
			"EventIndex", 
			"EventName", 
			"EventId", 
			"SessionId"
		}
	), 
	#"Sorted Rows" = Table.Sort(
		#"Reordered Columns", 
		{
			{
				"Timestamp", 
				Order.Ascending
			}
		}
	), 
	#"Reordered Columns1" = Table.ReorderColumns(
		#"Sorted Rows", 
		{
			"SessionId", 
			"EventId", 
			"Timestamp", 
			"EventName", 
			"Index", 
			"EventIndex", 
			"RecordedIndex"
		}
	), 
	// split event name into individual categories
	#"Split Column by Character Transition" = Table.SplitColumn(
		#"Reordered Columns1", 
		"EventName", 
		Splitter.SplitTextByCharacterTransition(
			{"a" .. "z"}, 
			{"A" .. "Z"}
		), 
		{
			"EventName.1", 
			"EventName.2", 
			"EventName.3", 
			"EventName.4"
		}
	), 
	#"Removed Columns" = Table.RemoveColumns(
		#"Split Column by Character Transition", 
		{
			"EventName.1"
		}		
	), 
	#"Renamed Columns" = Table.RenameColumns(
		#"Removed Columns", 
		{
			{
				"EventName.2", 
				"Category1"
			}, 
			{
				"EventName.3", 
				"Category2"
			}, 
			{
				"EventName.4", 
				"Category3"
			}
		}
	),
	#"Added Custom" = Table.AddColumn(
		#"Renamed Columns", 
		"Branch1", 
		each Text.Combine(
			{
				[Category1], 
				[Category2]
			}, 
			""
		)
	), 
	#"Removed Columns1" = Table.RemoveColumns(
		#"Added Custom", 
		{
			"Category2"
		}
	), 
	#"Renamed Columns1" = Table.RenameColumns(
		#"Removed Columns1", 
		{
			{
				"Branch1", 
				"Category2"
			}
		}
	), 
	#"Reordered Columns2" = Table.ReorderColumns(
		#"Renamed Columns1", 
		{
			"SessionId", 
			"EventId", 
			"Timestamp", 
			"Category1", 
			"Category2", 
			"Category3", 
			"Index", 
			"EventIndex", 
			"RecordedIndex"
		}
	), 
	// Recombine into categories of increasing specificity
	#"Renamed Columns2" = Table.RenameColumns(
		#"Reordered Columns2", 
		{
			{
				"Category3", 
				"Tag3"
			}, 
			{
				"Category1", 
				"Tag1"
			}, 
			{
				"Category2", 
				"Tag12"
			}
		}
	), 
	#"Added Custom1" = Table.AddColumn(
		#"Renamed Columns2", 
		"Tag123", 
		each Text.Combine(
			{
				[Tag12], 
				[Tag3]
			}, 
			""
		)
	), 
	#"Reordered Columns3" = Table.ReorderColumns(
		#"Added Custom1", 
		{
			"SessionId", 
			"EventId", 
			"Timestamp", 
			"Tag1", 
			"Tag12", 
			"Tag123", 
			"Tag3", 
			"Index", 
			"EventIndex", 
			"RecordedIndex"
		}
	), 
	#"Removed Columns2" = Table.RemoveColumns(
		#"Reordered Columns3", 
		{
			"Tag3"
		}
	), 
	// group and index for tag1
	ReadyForGrouping = Table.ReorderColumns(
		#"Removed Columns2", 
		{
			"SessionId", 
			"EventId", 
			"Timestamp", 
			"Index", 
			"RecordedIndex", 
			"EventIndex", 
			"Tag1", 
			"Tag12", 
			"Tag123"
		}
	), 
	GroupedBySessionId = Table.Group(
		ReadyForGrouping, 
		{"SessionId"}, 
		{
			{
				"Rows", 
				each _, 
				type table [
					SessionId = nullable text, 
					EventId = nullable text, 
					Timestamp = datetime, 
					Index = nullable number, 
					RecordedIndex = number, 
					EventIndex = nullable number, 
					Tag1 = nullable text, 
					Tag12 = text, 
					Tag123 = text
				]
			}
		}
	),
	SortedByTimestamp = Table.TransformColumns(
		GroupedBySessionId, 
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
	SubGroupedByTag1 = Table.TransformColumns(
		SortedByTimestamp, 
		{
			"Rows", 
			each Table.Group(
				_, 
				{"Tag1"}, 
				{
					{
						"Rows", 
						each _, 
						type table [
							EventId = nullable text, 
							Timestamp = datetime, 
							Index = nullable number, 
							RecordedIndex = number, 
							EventIndex = nullable number, 
							Tag12 = text, 
							Tag123 = text
						]
					}
				}
			)
		}
	),
	IndexSubgroupByTag1 = Table.TransformColumns(
		SubGroupedByTag1, 
		{
			"Rows", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddIndexColumn(
							_, 
							"Index1", 
							1, 
							1
						)
					}
				}
			)
		}
	),
	CreateNextIndexByTag1 = Table.TransformColumns(
		IndexSubgroupByTag1,
		{
			"Rows", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddColumn(
							_, 
							"NextIndex1", 
							each [Index1] + 1
						)
					}
				}
			)	
		}
	),
	ExpandTag1 = Table.ExpandTableColumn(
		CreateNextIndexByTag1, 
		"Rows", 
		{"Tag1", "Rows"}, 
		{"Tag1", "Rows.1"}
	), 
	// group and index for tag12
	SubGroupedByTag12 = Table.TransformColumns(
		ExpandTag1, 
		{
			"Rows.1", 
			each Table.Group(
				_, 
				{
					"Tag12"
				}, 
				{
					{
						"Rows", 
						each _, 
						type table [
							EventId = nullable text, 
							Timestamp = datetime, 
							Index = nullable number, 
							Index1 = nullable number, 
							NextIndex1 = nullable number, 
							RecordedIndex = number, 
							EventIndex = nullable number, 
							Tag1 = text, 
							Tag123 = text
						]
					}
				}
			)
		}
	),
	IndexSubgroupByTag12 = Table.TransformColumns(
		SubGroupedByTag12, 
		{
			"Rows.1", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddIndexColumn(
							_, 
							"Index12", 
							1, 
							1
						)
					}
				}
			)
		}
	), 
	CreateNextIndexByTag12 = Table.TransformColumns(
		IndexSubgroupByTag12,
		{
			"Rows.1", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddColumn(
							_, 
							"NextIndex12", 
							each [Index12] + 1
						)
					}
				}
			)	
		}
	),
	ExpandTag12 = Table.ExpandTableColumn(
		CreateNextIndexByTag12, 
		"Rows.1", 
		{"Tag12", "Rows"}, 
		{"Tag12", "Rows.1"}
	), 
	// group and index for tag123
	SubGroupedByTag123 = Table.TransformColumns(
		ExpandTag12, 
		{
			"Rows.1", 
			each Table.Group(
				_, 
				{
					"Tag123"
				}, 
				{
					{
						"Rows", 
						each _, 
						type table [
							EventId = nullable text, 
							Timestamp = datetime, 
							Index = nullable number, 
							Index1 = nullable number, 
							Index12 = nullable number, 
							NextIndex1 = nullable number, 
							NextIndex12 = nullable number, 
							RecordedIndex = number, 
							EventIndex = nullable number, 
							Tag1 = text, 
							Tag12 = text
						]
					}
				}
			)
		}
	),
	IndexSubgroupByTag123 = Table.TransformColumns(
		SubGroupedByTag123, 
		{
			"Rows.1", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddIndexColumn(
							_, 
							"Index123", 
							1, 
							1
						)
					}
				}
			)
		}
	), 
	CreateNextIndexByTag123 = Table.TransformColumns(
		IndexSubgroupByTag123,
		{
			"Rows.1", 
			each Table.TransformColumns(
				_, 
				{
					{
						"Rows", 
						each Table.AddColumn(
							_, 
							"NextIndex123", 
							each [Index123] + 1
						)
					}
				}
			)	
		}
	),
	ExpandTag123 = Table.ExpandTableColumn(
		CreateNextIndexByTag123, 
		"Rows.1", 
		{"Tag123", "Rows"}, 
		{"Tag123", "Rows.1"}
	), 
	FinalExpand = Table.ExpandTableColumn(
		ExpandTag123, 
		"Rows.1", 
		{
			"SessionId", 
			"EventId", 
			"Timestamp", 
			"Index", 
			"RecordedIndex", 
			"EventIndex", 
			"Tag1", 
			"Tag12", 
			"Tag123", 
			"Index1",
			"Index12",
			"Index123",
			"NextIndex1",
			"NextIndex12",
			"NextIndex123"
		}, 
		{
			"SessionId.1", 
			"EventId", 
			"Timestamp", 
			"Index", 
			"RecordedIndex", 
			"EventIndex", 
			"Tag1.1", 
			"Tag12.1", 
			"Tag123.1", 
			"Index1",
			"Index12",
			"Index123",
			"NextIndex1",
			"NextIndex12",
			"NextIndex123"
		}
	),
	Progress1 = Table.AddColumn(
		FinalExpand, 
		"Progress1", 
		each Text.Combine(
			{
				[Tag1], 
				Number.ToText([Index1])
			}, 
			""
		)
	), 
	Progress12 = Table.AddColumn(
		Progress1, 
		"Progress12", 
		each Text.Combine(
			{
				[Tag12], 
				Number.ToText([Index12])
			}, 
			""
		)
	), 
	Progress123 = Table.AddColumn(
		Progress12, 
		"Progress123", 
		each Text.Combine(
			{
				[Tag123], 
				Number.ToText([Index123])
			}, 
			""
		)
	),
	NextProgress1 = Table.AddColumn(
		Progress123, 
		"NextProgress1", 
		each Text.Combine(
			{
				[Tag1], 
				Number.ToText([NextIndex1])
			}, 
			""
		)
	), 
	NextProgress12 = Table.AddColumn(
		NextProgress1, 
		"NextProgress12", 
		each Text.Combine(
			{
				[Tag12], 
				Number.ToText([NextIndex12])
			}, 
			""
		)
	), 
	NextProgress123 = Table.AddColumn(
		NextProgress12, 
		"NextProgress123", 
		each Text.Combine(
			{
				[Tag123], 
				Number.ToText([NextIndex123])
			}, 
			""
		)
	),
	#"Removed Other Columns1" = Table.SelectColumns(
		NextProgress123,
		{
			"SessionId",
			"EventId", 
			"Timestamp",
			"Tag1", 
			"Tag12", 
			"Tag123", 
			"Progress1", 
			"Progress12", 
			"Progress123",
			"NextProgress1", 
			"NextProgress12", 
			"NextProgress123"
		}
	)
in
	#"Removed Other Columns1"
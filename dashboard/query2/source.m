let
	Source = AzureDataExplorer.Contents(
		"https://insights.playfab.com", 
		"92D06", 
		"['events.all'] #(lf)#(tab)| where FullName_Namespace == ""title.92D06""#(lf)#(tab)| project-keep EventData, Timestamp, EventId#(lf)#(tab)| extend EventName = EventData[""EventName""]#(lf)#(tab)| extend State = EventData[""State""]#(lf)#(tab)| extend Version = EventData[""Version""]#(lf)#(tab)| project-keep EventName, State, Version, Timestamp, EventId#(lf)#(tab)| where Version >= 9", 
		[MaxRows=null, MaxSize=null, NoTruncate=null, AdditionalSetStatements=null]
	)
in
	Source
let
    Source = session,
    #"Grouped Rows" = Table.Group(Source, {"UserId"}, {{"Duration", each List.Sum([Duration]), type number}, {"Sessions", each Table.RowCount(_), Int64.Type}}),
    #"Sorted Rows" = Table.Sort(#"Grouped Rows",{{"Duration", Order.Descending}})
in
    #"Sorted Rows"
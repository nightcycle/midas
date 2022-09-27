import numpy
import pandas
import fastparquet

dataFrame = pandas.read_csv('./dashboard/data/events.csv')

print(dataFrame)

dataFrame.to_parquet('./dashboard/data/events.parquet', engine='fastparquet')


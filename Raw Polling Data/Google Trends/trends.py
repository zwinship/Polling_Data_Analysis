import pandas as pd
import glob

'''
This is code takes each Google Trends CSV and combines them together into one long panel dataframe
The csv files for each state will be in the github folder. I personally got each csv file 
from the Google Trends Website using the serch term of fivethirtyeight.com
I also filtered the data for 0, to -48 days before the election so it can easily 
by merged with the other dataset.
'''





# Change file path for folder of trends csv
folder_path = r"C:\Users\zwins\OneDrive - Bentley University\pythonProject\Polling Study\trends"


files = glob.glob(f"{folder_path}/*.csv")

data_frames = []

for file in files:
    state_name = file.split("\\")[-1].replace("_Trends.csv", "").lower()
    df = pd.read_csv(file, skiprows=1)


    trends_column = [col for col in df.columns if col.startswith('FiveThirtyEight:')][0]
    df.rename(columns={'Day': 'day', trends_column: 'trends'}, inplace=True)


    df['state'] = state_name
    df['days_to_vote'] = (pd.to_datetime('2024-11-05') - pd.to_datetime(df['day'])).dt.days


    df = df[['state', 'days_to_vote', 'trends']]

    data_frames.append(df)


final_df = pd.concat(data_frames, ignore_index=True)

final_df.to_csv(f"{folder_path}/combined_trends.csv", index=False)


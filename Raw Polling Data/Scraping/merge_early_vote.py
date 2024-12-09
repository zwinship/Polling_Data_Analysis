import pandas as pd
import os
import numpy as np


'''
This code takes txt files from the early voting data from TargetSmart
The files are comma-separated but Target Smart does not give out its data for free
At least from what I found, So I manually went through each state and copied and pasted the table
Into a txt file with commas between each point, The txt files it pulls from are also
In the GitHub folder
'''




main_df = pd.read_csv('restructured_closeness.csv', low_memory=False)

def normalize_state_name(filename):
    name = filename.replace('.txt', '')
    name = name.replace('_2024_Party', '').lower()
    name = name.replace('_', '-')
    return name

def is_historical_voting_file(df):
    required_columns = ['Days out from election', '2020', '2022', '2024']
    return all(col in df.columns for col in required_columns)

def is_party_breakdown_file(df):
    required_columns = ['Days out from election', 'Dem', 'GOP', 'Other']
    return all(col in df.columns for col in required_columns)

state_data = {}

for filename in os.listdir():
    if not filename.endswith('.txt'):
        continue

    try:
        temp_df = pd.read_csv(filename, low_memory=False)
        if not is_historical_voting_file(temp_df):
            continue

        state_name = normalize_state_name(filename)
        historical_df = temp_df.copy()
        historical_df = historical_df.rename(columns={'Days out from election': 'days_until_vote'})

        state_data[state_name] = {
            'historical': historical_df[['days_until_vote', '2020', '2022', '2024']]
        }

    except Exception as e:
        continue

for filename in os.listdir():
    if not filename.endswith('.txt'):
        continue

    try:
        temp_df = pd.read_csv(filename, low_memory=False)
        if not is_party_breakdown_file(temp_df):
            continue

        state_name = normalize_state_name(filename)
        party_df = temp_df.copy()
        party_df = party_df.rename(columns={'Days out from election': 'days_until_vote'})

        if state_name in state_data:
            state_data[state_name]['party'] = party_df[['days_until_vote', 'Dem', 'GOP', 'Other']]
        else:
            state_data[state_name] = {
                'party': party_df[['days_until_vote', 'Dem', 'GOP', 'Other']]
            }

    except Exception as e:
        continue

merged_data = []

for _, state_main_df in main_df.groupby('state'):
    state_name = state_main_df['state'].iloc[0].lower()
    merged_state_df = state_main_df.copy()

    try:
        if state_name in state_data and 'historical' in state_data[state_name]:
            merged_state_df = pd.merge(
                merged_state_df,
                state_data[state_name]['historical'],
                on='days_until_vote',
                how='left'
            )

        if state_name in state_data and 'party' in state_data[state_name]:
            merged_state_df = pd.merge(
                merged_state_df,
                state_data[state_name]['party'],
                on='days_until_vote',
                how='left'
            )

        merged_data.append(merged_state_df)

    except Exception as e:
        merged_data.append(merged_state_df)

if merged_data:
    final_df = pd.concat(merged_data, ignore_index=True)

    if 'closeness' in final_df.columns and 'dem_trail' in final_df.columns:
        final_df.loc[final_df['closeness'].isna(), 'dem_trail'] = np.nan

    final_df.to_csv('final_polling_and_early_vote.csv', index=False)

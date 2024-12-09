import pandas as pd

'''
This code will transform the data in Long from the previous Python scrapping of closeness into
Long Panel Data, Originally the code also was used to scrape the variable dem_trail, mentioned in the paper
I was having problems with this as for some reason my code was identifying which polling number
Belonged to which candidate, Hence the code was giving the wrong value for dem_trail
This code leaves the column empty and I personally went to it and filled out these values
I did not take me more than an hour and is the easiest solution to solving this problem
'''


df = pd.read_csv('cleaned_polling_data.csv')


days_until_vote_range = range(-48, 1)
states = df.columns[1:]


output_data = []


for state in states:
    closeness_col = state
    dem_trail = 0


    state_data = df[[closeness_col, 'days_until_vote']].dropna()

    for day in days_until_vote_range:
        day_data = state_data[state_data['days_until_vote'] == day]
        closeness = 0

        if not day_data.empty:
            closeness = day_data.iloc[0][closeness_col]

        output_data.append([state, day, closeness, dem_trail])


output_df = pd.DataFrame(output_data, columns=['state', 'days_until_vote', 'closeness', 'dem_trail'])

output_df.to_csv('restructured_closeness.csv', index=False)

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
from datetime import datetime
import pandas as pd
import time

''' 
The scraping will avoid observations that do not include Harris as one of the candidates
Originally I was running into the problem of Biden's polling be collected since he was primarily being polled
Before he dropped out. If polls are missing on a given day then it will assume the value of the most 
Recently released poll. The logic behind this is that this would be the closeness value that individuals
Are seeing when accessing the website. If multiple polls are released on the same day it takes the average 
of those polls. The last debug I added was an error where the selenium driver was going so far back that it was
Including observations in Nov. 2023 and including this in the df, so in the code, the driver does not include
observations past the time of -90 to November 5, 2024
'''





# List of states to process
states = [
    'alabama', 'alaska', 'arizona', 'alaska', 'arkansas', 'california', 'colorado',
    'connecticut', 'delaware', 'florida', 'georgia', 'hawaii',
    'idaho', 'illinois', 'indiana', 'iowa', 'kansas',
    'kentucky', 'louisiana', 'maine', 'maryland', 'massachusetts',
    'michigan', 'minnesota', 'mississippi', 'missouri', 'montana',
    'nebraska', 'nevada', 'new hampshire', 'new jersey', 'new mexico',
    'new york', 'north carolina', 'north dakota', 'ohio', 'oklahoma',
    'oregon', 'pennsylvania', 'rhode island', 'south carolina', 'south dakota',
    'tennessee', 'texas', 'utah', 'vermont', 'virginia',
    'washington', 'west virginia', 'wisconsin', 'wyoming'
]

base_url = 'https://projects.fivethirtyeight.com/polls/president-general/2024/{}'

month_mapping = {
    'Jan.': 1, 'February': 2, 'Feb.': 2, 'March': 3, 'April': 4,
    'May': 5, 'June': 6, 'July': 7, 'Aug.': 8, 'August': 8,
    'Sept.': 9, 'September': 9, 'Oct.': 10, 'October': 10,
    'Nov.': 11, 'November': 11, 'Dec.': 12, 'December': 12,
}

def scrape_state_polls(state):
    driver = webdriver.Chrome(service=ChromeService(ChromeDriverManager().install()))
    url = base_url.format(state)
    driver.get(url)
    polling_data = []
    target_date = datetime(2024, 11, 5)
    last_closeness = None
# Using selenium to click the more polls button on the 538 webpage
    try:
        while True:
            try:
                show_more_button = driver.find_element(By.CLASS_NAME, "more-polls")
                show_more_button.click()
                time.sleep(2)
            except Exception:
                break

        soup = BeautifulSoup(driver.page_source, 'html.parser')
        polls = soup.find_all('tr', class_='visible-row')

        for poll in polls:
            date_td = poll.find('td', class_='dates hide-desktop')
            if not date_td:
                continue
            date = date_td.find('div', class_='date-wrapper').text.strip().replace('\u00a0', ' ')
            try:
                if '-' in date:
                    start_date, end_date = date.split('-')
                    start_parts = start_date.split()
                    end_parts = end_date.split()

                    if len(start_parts) == 2:
                        start_month_str, start_day = start_parts
                        start_month = month_mapping.get(start_month_str)
                        start_poll_date = datetime(2024, start_month, int(start_day))
                    if len(end_parts) == 2:
                        end_month_str, end_day = end_parts
                        end_month = month_mapping.get(end_month_str)
                        end_poll_date = datetime(2024, end_month, int(end_day))
                    else:
                        end_day = int(end_parts[0])
                        end_poll_date = datetime(2024, start_month, end_day)

                    days_until_vote = (end_poll_date - target_date).days
                else:
                    parts = date.split()
                    month = month_mapping.get(parts[0])
                    day = int(parts[1])
                    end_poll_date = datetime(2024, month, day)
                    days_until_vote = (end_poll_date - target_date).days
            except (ValueError, IndexError):
                continue

            if end_poll_date.month < 8:
                break

            candidates = poll.find_all('div', class_='mobile-answer')
            percentages = poll.find_all('div', class_='heat-map')

            if len(candidates) > 0:
                candidate1 = candidates[0].find('p').text.strip()
                if len(percentages) > 0:
                    candidate1_percentage = float(percentages[0].text.strip().rstrip('%'))
            if len(candidates) > 1:
                candidate2 = candidates[1].find('p').text.strip()
                if len(percentages) > 3:
                    candidate2_percentage = float(percentages[3].text.strip().rstrip('%'))

            if candidate1 and candidate2 and candidate1_percentage is not None and candidate2_percentage is not None:
                closeness = min(candidate1_percentage, candidate2_percentage)
                last_closeness = closeness
            else:
                closeness = last_closeness or float('nan')

            if 'Harris' in (candidate1, candidate2):
                polling_data.append({
                    'date': date,
                    'days_until_vote': days_until_vote,
                    'candidate1': candidate1,
                    'candidate1_percentage': candidate1_percentage,
                    'candidate2': candidate2,
                    'candidate2_percentage': candidate2_percentage,
                    'closeness': closeness
                })
    finally:
        driver.quit()

    return pd.DataFrame(polling_data)

def process_polling_data(states):
    state_data = {}
    for state in states:
        df = scrape_state_polls(state)
        if not df.empty:
            state_data[state] = df

    date_range = range(-90, 1)
    results = {'days_until_vote': list(date_range)}

    for state, df in state_data.items():
        state_values = []
        last_closeness_value = None
        for days in date_range:
            daily_polls = df[df['days_until_vote'] == days]
            if not daily_polls.empty:
                avg_value = daily_polls['closeness'].mean()
                state_values.append(round(avg_value, 1))
                last_closeness_value = round(avg_value, 1)
            else:
                state_values.append(last_closeness_value)
        results[state] = state_values

    return pd.DataFrame(results)

if __name__ == '__main__':
    results_df = process_polling_data(states)
    results_df.to_csv('state_polling_by_day.csv', index=False)

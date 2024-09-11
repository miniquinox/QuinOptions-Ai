import json
import yfinance as yf
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import os
import robin_stocks.robinhood as r
from dotenv import load_dotenv
import pyotp
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import base64

# Load environment variables
load_dotenv()

print("Starting at time: ", datetime.now())

# Firebase setup
firebase_key = os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY')
if not firebase_key:
    raise ValueError("FIREBASE_SERVICE_ACCOUNT_KEY not set or loaded properly.")

service_account_info = json.loads(base64.b64decode(firebase_key).decode('utf-8'))
cred = credentials.Certificate(service_account_info)
firebase_admin.initialize_app(cred)
db = firestore.client()

def track_market_data(test_symbol, test_expiration, test_strike, duration=12, sleep_interval=2, max_iterations=10):
    start_time = datetime.now()
    iterations = 0

    while True:
        current_time = datetime.now()
        elapsed_time = (current_time - start_time).total_seconds()

        if elapsed_time > duration or iterations >= max_iterations:
            break

        current_market_price = r.get_option_market_data(test_symbol, test_expiration, test_strike, optionType='call')
        my_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
        my_loop = f"Time: {my_time}\n"
        my_loop += f"{test_symbol} Last Trade Price {current_market_price[0][0]['last_trade_price']} \n"
        my_loop += f"{test_symbol} Ask Price {current_market_price[0][0]['ask_price']} \n"
        my_loop += f"{test_symbol} Bid Price {current_market_price[0][0]['bid_price']} \n"
        my_loop += f"{test_symbol} Mark Price {current_market_price[0][0]['mark_price']} \n"
        
        raw_open_price_data = r.get_option_historicals(test_symbol, test_expiration, test_strike, 'call', interval='5minute', span='day')
        try:
            open_price = float(raw_open_price_data[0]["open_price"].replace(',', ''))
        except:
            open_price = "N/A"
        my_loop += f"{test_symbol} Open Price {open_price} \n"
        
        print(my_loop)

        iterations += 1
        time.sleep(sleep_interval)

def update_firestore_with_new_data(date, new_options):
    doc_ref = db.collection('options_data').document(date)
    
    existing_doc = doc_ref.get()
    if existing_doc.exists:
        existing_data = existing_doc.to_dict()
        existing_options = existing_data.get('options', [])
    else:
        existing_options = []

    for new_option in new_options:
        updated = False
        for existing_option in existing_options:
            if existing_option['id'] == new_option['id']:
                existing_option['percentage'] = new_option['percentage']
                existing_option['high_price'] = new_option['high_price']
                existing_option['open_price'] = new_option['open_price']
                updated = True
                break
        if not updated:
            existing_options.append(new_option)

    doc_ref.set({
        'date': date,
        'options': existing_options
    })
    print(f"Data for {date} updated in Firestore.")

def fetch_and_calculate_option_price():
    # Explicitly set to the correct path for chromedriverGitHub
    chromedriver_path = "/usr/local/bin/chromedriver"  # Adjust this path
    
    # Set up Selenium with the local chromedriver
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    service = Service(chromedriver_path)
    driver = webdriver.Chrome(service=service, options=options)
    
    # The rest of your code
    driver.get('https://stockanalysis.com/stocks/screener/')
    wait = WebDriverWait(driver, 10)
    print("Page loaded")
    time.sleep(2)

    button = wait.until(EC.element_to_be_clickable((By.XPATH, "//div[contains(text(), 'Add Filters')]/ancestor::button")))
    button.click()
    time.sleep(0.5)

    marketCap = wait.until(EC.element_to_be_clickable((By.ID, "marketCap")))
    marketCap.click()
    time.sleep(0.5)
    
    postmarketChangePercent = wait.until(EC.element_to_be_clickable((By.ID, "premarketChangePercent")))
    postmarketChangePercent.click()
    time.sleep(0.5)

    afterHoursPrice = wait.until(EC.element_to_be_clickable((By.ID, "premarketPrice")))
    afterHoursPrice.click()
    time.sleep(0.5)

    marketClosePrice = wait.until(EC.element_to_be_clickable((By.ID, "close")))
    marketClosePrice.click()
    time.sleep(0.5)

    close_button = wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, 'button[aria-label="Close"]')))
    close_button.click()
    time.sleep(0.5)
    print("Filters added")

    first_any_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[span[text()='Any']]")))
    first_any_button.click()
    time.sleep(0.5)

    input_element = driver.find_element(By.CSS_SELECTOR, "input[placeholder='Value']")
    input_element.clear()
    input_element.send_keys("2B")
    time.sleep(0.5)
    
    second_any_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[span[text()='Any']]")))
    second_any_button.click()
    time.sleep(0.5)

    input_element = driver.find_element(By.CSS_SELECTOR, "input[placeholder='Value']")
    input_element.clear()
    input_element.send_keys("8")
    print("Filters set")
    
    time.sleep(0.5)

    filters_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//li/button[contains(@class, 'dont-move') and contains(text(), 'Filters')]")))
    filters_button.click()
    time.sleep(2)

    tbody = driver.find_element(By.CSS_SELECTOR, 'tbody')

    column_names = ['Symbol', 'Company Name', 'Market Cap', 'Premkt. Chg.', 'Premkt. Price', 'Close']
    data = []
    lines = tbody.text.strip().split('\n')

    for line in lines:
        match = re.match(r'(\w+)\s+([\w\s,.&-]+?)\s+(\d+\.\d+B)\s+(-?\d+\.\d+%)?\s+([\d,.]+)\s+(-|[\d,.]+)', line)
        if match:
            fields = match.groups()
            row_dict = {column_names[i]: fields[i] for i in range(len(column_names))}
            data.append(row_dict)

    driver.quit()
    print("Browser closed")

    json_data = data
    today_str = datetime.today().strftime('%Y-%m-%d')
    
    mfa_key = os.getenv('ROBIN_MFA')
    username = os.getenv('ROBIN_USERNAME')
    password = os.getenv('ROBIN_PASSWORD')
    if not all([mfa_key, username, password]):
        raise EnvironmentError("One or more environment variables are missing.")

    # Generate the MFA code using pyotp
    totp = pyotp.TOTP(os.getenv('ROBIN_MFA')).now()
    
    # Login to Robinhood using the MFA code
    login = r.login(username, password, store_session=False, mfa_code=totp)
   
    print("Logged in")

    new_data = {
        "date": today_str,
        "options": []
    }

    if json_data:
        for row in json_data:
            symbol = row["Symbol"]
            if symbol == "AS":
                continue

            preMarketPrice = row["Premkt. Price"]
            stock = yf.Ticker(symbol)

            if not stock.options:
                continue
            
            options = stock.option_chain(stock.options[0])
            calls = options.calls
            call_option = calls.iloc[(calls['strike'] - float(preMarketPrice.replace(',', ''))).abs().argsort()[:1]]        
            target_strike = call_option['strike'].iloc[0]
            target_expiration = datetime.strptime(stock.options[0], '%Y-%m-%d').strftime('%Y-%m-%d')
            
            target_expiration_date = datetime.strptime(target_expiration, '%Y-%m-%d')
            today = datetime.today()
            difference = (target_expiration_date - today).days

            if difference > 6:
                continue

            try:
                stock_close_price = r.get_stock_quote_by_symbol(symbol)['previous_close']
                current_stock_price = r.get_latest_price(symbol)[0]
                options = r.find_options_by_expiration_and_strike(symbol, target_expiration, target_strike, optionType='call')
                option_market_close = options[0]["previous_close_price"] 

            except:
                print(f"Error fetching data for {symbol}")
                continue

            print(f'\n\nStock price at market close: {stock_close_price} for {symbol}')
            print(f'Stock price before market open: {current_stock_price} for {symbol}')
            print(f'Option price at market close: {option_market_close} for {symbol}')

            option_id = f"{symbol} ${target_strike} Call {target_expiration}"

            # get time now
            now = datetime.now()
            time_difference = timedelta(hours=-7)
            
            # Adjust the current time by the time difference
            now = now + time_difference
            new_data["options"].append({
                "id": option_id,
                "percentage": 0,
                "time": now.strftime("%Y-%m-%d %H:%M:%S"),
            })

    else:
        print("No data found")
    
    update_firestore_with_new_data(today_str, new_data["options"])

    for option in new_data["options"]:
        test_symbol = option["id"].split()[0]
        test_expiration = option["id"].split()[3]
        test_strike = float(option["id"].split()[1].replace('$', ''))

        try:
            track_market_data(test_symbol, test_expiration, test_strike, duration=12, sleep_interval=2)
        except Exception as e:
            print(f"Error tracking market data for {test_symbol}: {e}")

        print("Done")
        
        break # For testing purposes we only need to track one option

###################################################
############## ROBINHOOD CODE #####################
###################################################

def get_high_option_price(symbol, exp_date, strike):
    options = r.find_options_by_expiration_and_strike(symbol, exp_date, strike, optionType='call')

    if not options:
        return None

    # Get option id
    option_id = options[0]['id']

    # Get market data
    market_data = r.get_option_market_data_by_id(option_id)

    # Get the high_price from the market data
    high_price = market_data[0].get('high_price')

    return float(high_price.replace(',', '')) if high_price else None

def check_and_update_high_price():
    # Reference to Firestore collection and document
    doc_ref = db.collection('options_data').order_by('date', direction=firestore.Query.DESCENDING).limit(1)
    docs = doc_ref.stream()

    last_doc = None
    for doc in docs:
        last_doc = doc.to_dict()

    if last_doc:
        date = last_doc['date']
        new_options = []

        start_time = datetime.now()

        while True:
            # Check if 3 hours and 30 minutes have passed
            elapsed_time = datetime.now() - start_time
            if elapsed_time > timedelta(minutes=30):
                break

            if not last_doc['options']:
                print("Nothing to update today. Exiting...")
                break

            for option in last_doc['options']:
                # Regex the option details from string format "SMCI $1040.0 Call 2024-03-08"
                option_string = option['id']

                match = re.match(r"(\w+)\s+\$(\d+\.\d+)\s+(\w+)\s+(\d{4}-\d{2}-\d{2})", option_string)

                if match:
                    symbol = match.group(1)
                    strike = float(match.group(2).replace(',', ''))
                    option_type = match.group(3)
                    exp_date = match.group(4)

                    # Get raw open price
                    raw_open_price_data = r.get_option_historicals(symbol, exp_date, strike, option_type, interval='5minute', span='day')
                    if not raw_open_price_data:
                        print(f"Could not fetch historical data for {symbol} {strike} {exp_date}")
                        continue

                    # Convert open price to float
                    open_price = float(raw_open_price_data[0]["open_price"].replace(',', ''))

                    # Get high price
                    high_price = get_high_option_price(symbol, exp_date, strike)
                    if high_price is None:
                        print(f"No registered trades for {symbol} {strike} {exp_date}")
                        continue

                    if high_price > open_price:
                        percentage = round((high_price - open_price) / open_price * 100, 2)
                        if percentage > option['percentage']:
                            option['percentage'] = percentage
                            option['high_price'] = high_price
                            option['open_price'] = open_price
                            print(f"Updating high price for {symbol} {strike} {exp_date} to {high_price} with a percentage of {percentage}%")
                            new_options.append(option)
                        else:
                            print(f"No update for {symbol} {strike} {exp_date} as the high price is {high_price} and the open price is {open_price}")
                    else:
                        print(f"No update for {symbol} {strike} {exp_date} as the high price is {high_price} and the open price is {open_price}")

            if new_options:
                update_firestore_with_new_data(date, new_options)

            # Wait for a minute before the next check
            time.sleep(10)
            print("\n\n\n\n")

if __name__ == "__main__":
    fetch_and_calculate_option_price()
    check_and_update_high_price()

import datetime
import time
import pyotp
import robin_stocks.robinhood as r
from dotenv import load_dotenv
import os
import re
import firebase_admin
from firebase_admin import credentials, firestore
import base64
import json

# Load environment variables
load_dotenv()
mfa_key = os.getenv('ROBIN_MFA')
username = os.getenv('ROBIN_USERNAME')
password = os.getenv('ROBIN_PASSWORD')
if not all([mfa_key, username, password]):
    raise EnvironmentError("One or more environment variables are missing.")

# Login to Robinhood
totp = pyotp.TOTP(os.environ['ROBIN_MFA']).now()
login = r.login(os.environ['ROBIN_USERNAME'],
                os.environ['ROBIN_PASSWORD'], store_session=False, mfa_code=totp)

print("Logged in")

# Decode the base64-encoded service account key from the environment variable
service_account_info = json.loads(base64.b64decode(os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY')).decode('utf-8'))

# Initialize Firebase Admin SDK
cred = credentials.Certificate(service_account_info)
firebase_admin.initialize_app(cred)
db = firestore.client()

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

def update_firestore_with_new_data(date, new_options):
    doc_ref = db.collection('options_data').document(date)
    
    # Check if the document already exists
    existing_doc = doc_ref.get()
    if existing_doc.exists:
        existing_data = existing_doc.to_dict()
        existing_options = existing_data.get('options', [])
    else:
        existing_options = []

    # Merge new options with existing options
    for new_option in new_options:
        updated = False
        for existing_option in existing_options:
            if existing_option['id'] == new_option['id']:
                existing_option['percentage'] = new_option['percentage']
                updated = True
                break
        if not updated:
            existing_options.append(new_option)

    # Update Firestore with merged data
    doc_ref.set({
        'date': date,
        'options': existing_options
    })
    print(f"Data for {date} updated in Firestore.")

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

        start_time = datetime.datetime.now()

        while True:
            # Check if 3 hours and 30 minutes have passed
            elapsed_time = datetime.datetime.now() - start_time
            if elapsed_time > datetime.timedelta(hours=3, minutes=30):
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

# Usage:
check_and_update_high_price()

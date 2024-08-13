import json

# Load the data from the file
with open('options_data_2.json', 'r') as f:
    data = json.load(f)

# Remove duplicates, keeping only the last occurrence
for date in data:
    date['options'].reverse()
    date['options'] = [dict(t) for t in set(tuple(option.items()) for option in date['options'])]
    date['options'].reverse()

# Write the cleaned data to a new file
with open('options_data_3.json', 'w') as f:
    json.dump(data, f, indent=4)
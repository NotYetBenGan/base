import pickle

model_C_10_file = 'model_C=10.bin'
with open(model_C_10_file, 'rb') as f_in:
    dv, model = pickle.load(f_in)

customer = {
    'AccountAge': '10',
    'MonthlyCharges': 15.0,
    'TotalCharges': 1000.0,
    'SubscriptionType': 'Premium',
    'PaymentMethod': 'Credit card',
    'PaperlessBilling': 'Yes',
    'ContentType': 'TV Shows',
    'MultiDeviceAccess': 'No',
    'DeviceRegistered': 'Computer',
    'ViewingHoursPerWeek': 10.0,
    'AverageViewingDuration': 5.0,
    'ContentDownloadsPerMonth': 30,
    'GenrePreference': 'Action',
    'UserRating': 5.0,
    'SupportTicketsPerMonth': 2,
    'Gender': 'Female',
    'WatchlistSize': 20,
    'ParentalControl': 'No',
    'SubtitlesEnabled': 'No',
    'CustomerID': 'Vas3k'
}

X = dv.transform([customer])
y_pred = model.predict_proba(X)[:, 1]

print('input customer', customer)
print('customer churn probability', y_pred)
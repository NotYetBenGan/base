# Midterm Project

## Description of the problem
- The idea is to predict customer churn rate, based on these "train" and "test" datasets https://www.kaggle.com/datasets/safrin03/predictive-analytics-for-customer-churn-dataset/
- The data includes various features such as TotalCharges, ContentDownloadsPerMonth, SubscriptionType, DeviceRegistered and other relevant attributes. 
- It consists of three files such as "test.csv", "train.csv", "data_descriptions.csv", but I use only first two
- The prediction is done by classification model, based on logistic regression


## How I run the project on my Win10 machine
To install the dependncies ruh these commands in CMD:
- python -mpip install numpy              #1.26.1 <-- type in CMD pip3 list | findstr numpy
- python -mpip install pandas             #2.1.2
- python -mpip install scikit-learn       #1.3.2
- python -mpip install seaborn            #0.13.0 
- python -mpip install IPython       
- python -mpip install Flask              #2.2.2

Then run these files in CMD:
- python train.py
- python predict.py

While predict.py is running on the localhost, run this code in Jupiter notebook for specific customer:
- import requests                         #2.28.1
- url = 'http://localhost:9696/predict'
- customer = {
	    "AccountAge": "10",
	    "MonthlyCharges": 15.0,
	    "TotalCharges": 1000.0,
	    "SubscriptionType": "Premium",
	    "PaymentMethod": "Credit card",
	    "PaperlessBilling": "Yes",
	    "ContentType": "TV Shows",
	    "MultiDeviceAccess": "No",
	    "DeviceRegistered": "Computer",
	    "ViewingHoursPerWeek": 10.0,
	    "AverageViewingDuration": 5.0,
	    "ContentDownloadsPerMonth": 30,
	    "GenrePreference": "Action",
	    "UserRating": 5.0,
	    "SupportTicketsPerMonth": 2,
	    "Gender": "Female",
	    "WatchlistSize": 20,
	    "ParentalControl": "No",
	    "SubtitlesEnabled": "No",
	    "CustomerID": "Vas3k"
	}
- requests.post(url, json = customer).json()

As we figured out during EDA (see respective plot in the Jupiter notebook), there is linear dependency - the bigger is ContentDownloadsPerMonth, the smaller becomes Churn probability 


## Work with virtual environment and dependencies
To install pipenv library run in CMD:
- python -mpip install pipenv				#2023.10.20

To create virtual environment run in CMD (this command will look into Pipfile and Pipfile.lock (attched to the Midterm project) to install the libraries with specified version):
- pipenv install numpy scikit-learn==1.3.2 flask
- pipenv install gunicorn

After installing the required libraries we can run the project in the virtual environment with command in CMD (this will go to the virtual environment's shell and then any command we execute will use the virtual environment's libraries):
- pipenv shell  


## Work with Docker
Run this command in CMD to build the Dockerfile into image called "midterm":
- docker build -t midterm .

Run this command in CMD to run the built Docker image called "midterm"
- docker run -it --rm midterm

Open anither CMD terminal and run this:
- python predict_example.py

And we have the Churn probability back from the predict app :)

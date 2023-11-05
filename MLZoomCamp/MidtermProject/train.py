import numpy as np
import pandas as pd
from sklearn.feature_extraction import DictVectorizer
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.model_selection import train_test_split
from sklearn.metrics import mutual_info_score, accuracy_score, roc_auc_score, mean_squared_error
import matplotlib.pyplot as plt
import seaborn as sns
from IPython.display import display
import pickle


#Set input parameters
C = 10.0
#n_splits = 5
model_C_10_file = 'model_C=10.bin'


# Get the train and test data
train = pd.read_csv(r'https://github.com/NotYetBenGan/base/raw/main/MLZoomCamp/MidtermProject/train.csv')
test = pd.read_csv(r'https://github.com/NotYetBenGan/base/raw/main/MLZoomCamp/MidtermProject/test.csv')


# Set categorical and numerical column arrays
categorical = list(train.select_dtypes(include=['object']).dtypes.index)
categorical.remove('CustomerID')
for col in categorical:
    print(col + ' - ' + str(train[col].nunique()))

numerical = list(train.select_dtypes(include=['int','float']).dtypes.index)
numerical.remove('Churn')
for col in numerical:
    print(col + ' - ' + str(train[col].nunique()))


#There are no NULLs in these datasets, so just convert strings to ints
train.PaperlessBilling = (train.PaperlessBilling == "Yes").astype(int)
train.MultiDeviceAccess = (train.MultiDeviceAccess == "Yes").astype(int)
train.ParentalControl = (train.ParentalControl == "Yes").astype(int)
train.SubtitlesEnabled = (train.SubtitlesEnabled == "Yes").astype(int)

test.PaperlessBilling = (test.PaperlessBilling == "Yes").astype(int)
test.MultiDeviceAccess = (test.MultiDeviceAccess == "Yes").astype(int)
test.ParentalControl = (test.ParentalControl == "Yes").astype(int)
test.SubtitlesEnabled = (test.SubtitlesEnabled == "Yes").astype(int)


# Set Validation framework
np.random.seed(2)

#Let's take 20% of train dataset as val dataset
n_train = int(0.8 * len(train))
n_val = int(0.2 * len(train))
n_test = len(test)

idx = np.arange(n_train+n_val)
np.random.shuffle(idx)

df_shuffled = train.iloc[idx]

df_train = df_shuffled.iloc[:n_train].copy()
df_val = df_shuffled.iloc[n_train:n_train+n_val].copy()
df_test = test.copy()

y_train = df_train.Churn.values
y_val = df_val.Churn.values

del df_train['Churn']
del df_val['Churn']


# Create train and predict functions
def train(df, y, C=10):
    dct = df[categorical+numerical].to_dict(orient='records')
    #Prepare one-hot encoding for train and validation datasets
    dv = DictVectorizer(sparse=False)
    X = dv.fit_transform(dct)
    #Train logistic regression model
    model = LogisticRegression(solver='liblinear', C=C, max_iter=1000, random_state=42)
    model.fit(X, y)
    return dv, model

def predict(df, dv, model):
    dct = df[categorical+numerical].to_dict(orient='records')
    X = dv.transform(dct)
    #Predict Churn rate for validation dataset
    y_pred = model.predict_proba(X)[:, 1]
    return y_pred


# Train the binary classification model for C = 10
print(f'Train the binary classification model for C = {C}')
dv, model_C_10 = train(df_train, y_train, C)
y_pred = predict(df_val, dv, model_C_10)

auc = roc_auc_score(y_val, y_pred)
print('auc = %.3f' % auc)


# Save the model
with open(model_C_10_file, 'wb') as f_out: 
    pickle.dump((dv, model_C_10), f_out)
print(f'the model is saved to {model_C_10_file}')



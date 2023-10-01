#Preparation:
data = pandas.read_csv(r'https://raw.githubusercontent.com/alexeygrigorev/mlbookcamp-code/master/chapter-02-car-price/data.csv')
categorical = ['Make','Model','Year','Engine HP','Engine Cylinders','Transmission Type','Vehicle Style','highway MPG','city mpg']
data.columns = data.columns.str.replace(' ', '_').str.lower()
for col in data.columns:
    data[col] = data[col].fillna(0).values
data.isna().sum()
data.rename(columns = {'msrp':'price'}, inplace = True)


#Question 1: What is the most frequent observation (mode) for the column transmission_type?
data.transmission_type.value_counts()


#Question 2: What are the two features that have the biggest correlation in this dataset?
f = plt.figure(figsize=(7, 7))
plt.matshow(data[data.select_dtypes(include=np.number).columns].corr(), fignum=f.number)
plt.xticks(range(data.select_dtypes(include=np.number).shape[1]), data.select_dtypes(include=np.number).columns, fontsize=10, rotation=45)
plt.yticks(range(data.select_dtypes(include=np.number).shape[1]), data.select_dtypes(include=np.number).columns, fontsize=10)
cb = plt.colorbar()
cb.ax.tick_params(labelsize=14)
plt.title('Correlation Matrix', fontsize=16);


#Make price binary
data['above_average'] = (data.price >= data.price.mean()).astype(int)

#Split the data
from sklearn.model_selection import train_test_split
df_train_full, df_test = train_test_split(data, test_size=0.2, random_state=42)
df_train, df_val = train_test_split(df_train_full, test_size=0.25, random_state=42)
len(df_train), len(df_val), len(df_test)

df_train = df_train.reset_index(drop = True)
df_val = df_val.reset_index(drop = True)
df_test = df_test.reset_index(drop = True)

y_train = df_train.above_average.values
y_val = df_val.above_average.values
y_test = df_test.above_average.values

del df_train['price']
del df_val['price']
del df_test['price']


#Question 3: Calculate the mutual information score
from sklearn.metrics import mutual_info_score
categorical = ['make','model','year','engine_hp','engine_cylinders','transmission_type','vehicle_style','highway_mpg','city_mpg']

def calculate_mi(series):
    return mutual_info_score(series, df_train.above_average)

df_mi = df_train[categorical].apply(calculate_mi).round(2)
df_mi = df_mi.sort_values(ascending=False)


#Q4
#Prepare one-hot encoding for train and validation datasets
from sklearn.feature_extraction import DictVectorizer
dv = DictVectorizer(sparse=False)

train_dict = df_train[categorical].to_dict(orient='records')
X_train = dv.fit_transform(train_dict) 
val_dict = df_val[categorical].to_dict(orient='records')
X_val = dv.transform(val_dict)

dv.get_feature_names_out() #return names of the columns in the sparse one-hot encoding matrix X_train
list(X_train[0])

#Train logistic regression model
from sklearn.linear_model import LogisticRegression
model = LogisticRegression(solver='liblinear', C=10, max_iter=1000, random_state=42)
model.fit(X_train, y_train)
model.predict_proba(X_val)
y_pred = model.predict_proba(X_val)[:, 1] #second column for 1 predictions
churn = y_pred > 0.5
(y_val == churn).mean().round(2)

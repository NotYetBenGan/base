#Preparation:
import matplotlib.pyplot as plt
%matplotlib inline
import seaborn as sns
housing = pandas.read_csv(r'https://raw.githubusercontent.com/alexeygrigorev/datasets/master/housing.csv')  
hsb = housing.loc[housing['ocean_proximity'].isin(['<1H OCEAN','INLAND']) , ['latitude','longitude','housing_median_age','total_rooms','total_bedrooms','population','households','median_income','median_house_value']]
sns.histplot(hsb.median_house_value)

####################################

#Question 1: There's one feature with missing values. What is it?
hsb.columns[hsb.isnull().any()].tolist()

####################################

#Question 2: What's the median (50% percentile) for variable 'population'?
hsb['population'].median()

n = len(hsb)
n_val = int(n*0.2)
n_test = int(n*0.2)
n_train = n - n_test - n_val

#Create and shuffle index:
idx = np.arange(n)
np.random.seed(42) #determenistic randomiser
np.random.shuffle(idx)

#Prepare and split the dataset in (0.6, 0.2, 0.2):
hsb_train = hsb.iloc[idx[0:n_train]]
hsb_val = hsb.iloc[idx[n_train:n_train+n_val]]
hsb_test = hsb.iloc[idx[n_train+n_val:n]]

#Apply the log transformation:
y_train = np.log1p(hsb_train.median_house_value)
y_val = np.log1p(hsb_val.median_house_value)
y_test = np.log1p(hsb_test.median_house_value)


#Question 3:
def train_linear_regression(X, y):
    ones = np.ones(X.shape[0])
    X = np.column_stack([ones, X])

    XTX = X.T.dot(X)
    XTX_inv = np.linalg.inv(XTX)
    w_full = XTX_inv.dot(X.T).dot(y)
    
    return w_full[0], w_full[1:]

#Replace with 0 
#Train dataset
X_train_0 = hsb_train[hsb_train.columns].fillna(0).values
w0_0, w_0 = train_linear_regression(X_train_0, y_train)
#Validate dataset (20% of full dataset hsb) 
X_val_0 = hsb_val[hsb_val.columns].fillna(0).values
y_pred_0 = w0_0 + X_val_0.dot(w_0)

#Replace with mean()
#Train dataset
X_train_mean = hsb_train[hsb_train.columns].fillna(hsb_train['total_bedrooms'].mean()).values
w_mean_0, w_mean = train_linear_regression(X_train_mean, y_train)
#Validate dataset (20% of full dataset hsb) 
X_val_mean = hsb_val[hsb_val.columns].fillna(hsb_val['total_bedrooms'].mean()).values
y_pred_mean = w_mean_0 + X_val_mean.dot(w_mean)

#RMSE
def rmse(y, y_pred):
    se = (y - y_pred) ** 2
    mse = se.mean()
    return np.sqrt(mse)

rmse(y_val, y_pred_0).round(2)
rmse(y_val, y_pred_mean).round(2)

####################################

#Question 4:
def train_linear_regression_reg(X, y, r):
    ones = np.ones(X.shape[0])
    X = np.column_stack([ones, X])

    XTX = X.T.dot(X)
    XTX = XTX + r * np.eye(XTX.shape[0])

    XTX_inv = np.linalg.inv(XTX)
    w_full = XTX_inv.dot(X.T).dot(y)
    
    return w_full[0], w_full[1:]

#Replace with 0 
#Train and validate dataset for different r parameter
for r in [0, 0.000001, 0.0001, 0.001, 0.01, 0.1, 1, 5, 10]:
    X_train_0 = hsb_train[hsb_train.columns].fillna(0).values
    w0_0, w_0 = train_linear_regression_reg(X_train_0, y_train, r)
    
    X_val_0 = hsb_val[hsb_val.columns].fillna(0).values
    y_pred_0 = w0_0 + X_val_0.dot(w_0)
    
    score = rmse(y_val, y_pred_0).round(2)
    print(r, w0, score)

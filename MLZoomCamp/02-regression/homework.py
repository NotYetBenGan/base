#Preparation:
import matplotlib.pyplot as plt
%matplotlib inline
import seaborn as sns
housing = pandas.read_csv(r'https://raw.githubusercontent.com/alexeygrigorev/datasets/master/housing.csv')  
hsb = housing.loc[housing['ocean_proximity'].isin(['<1H OCEAN','INLAND']) , ['latitude','longitude','housing_median_age','total_rooms','total_bedrooms','population','households','median_income','median_house_value']]
sns.histplot(hsb.median_house_value)

#Question 1: There's one feature with missing values. What is it?
hsb.columns[hsb.isnull().any()].tolist()

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
median_house_value_log = np.log1p(hsb.median_house_value)
sns.histplot(median_house_value_log)

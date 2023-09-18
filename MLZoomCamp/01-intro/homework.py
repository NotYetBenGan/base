#Preparation:
import pandas
housing = pandas.read_csv(r'https://raw.githubusercontent.com/alexeygrigorev/datasets/master/housing.csv')  

#Question 1: Version of Pandas
pandas.__version__

#Question 2: Number of columns in the dataset
len(housing.columns)

#Question 3: Select columns with missing data
housing.columns[housing.isnull().any()].tolist()

#Question 4: Number of unique values in the 'ocean_proximity' column
housing.ocean_proximity.nunique()

#Question 5: Average value of the 'median_house_value' for the houses near the bay
housing.median_house_value[housing['ocean_proximity'] == 'NEAR BAY'].mean()

#Question 6: Has the mean value changed after filling missing values?
housing.total_bedrooms.mean()
housing_filled = housing.fillna(housing.total_bedrooms.mean())
housing_filled.total_bedrooms.mean()

Questions 7: Value of the last element of w
import numpy as np
housing_island = housing.loc[housing['ocean_proximity'] == 'ISLAND', ['housing_median_age', 'total_rooms', 'total_bedrooms']]
X = housing_island.to_numpy() #(5 rows 3 cols)
XTX = X.T.dot(X)   #(3*3)
XTXinv = np.linalg.inv(XTX)  #(3*3)
y = np.array([950, 1300, 800, 1000, 1300]) #(1 row 5 cols)
w = XTXinv.dot(X.T).dot(y) #(1 row 3 cols)

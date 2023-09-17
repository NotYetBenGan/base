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

Questions 7: Value of the last element of w
#What is w in the question?

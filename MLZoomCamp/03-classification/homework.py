#Preparation:
data = pandas.read_csv(r'https://raw.githubusercontent.com/alexeygrigorev/mlbookcamp-code/master/chapter-02-car-price/data.csv')
data.columns = data.columns.str.replace(' ', '_').str.lower()
for col in data.columns:
    data[col] = data[col].fillna(0).values
data.isna().sum()
data.rename(columns = {'msrp':'price'}, inplace = True)

#Question 1: What is the most frequent observation (mode) for the column transmission_type?
data.transmission_type.value_counts()

#Split the data
from sklearn.model_selection import train_test_split
df_train_full, df_test = train_test_split(data, test_size=0.2, random_state=42)
df_train, df_val = train_test_split(df_train_full, test_size=0.25, random_state=42)
len(df_train), len(df_val), len(df_test)

df_train = df_train.reset_index(drop = True)
df_val = df_val.reset_index(drop = True)
df_test = df_test.reset_index(drop = True)

y_train = df_train.price.values
y_val = df_val.price.values
y_test = df_test.price.values

del df_train['price']
del df_val['price']
del df_test['price']

#Question 2: What are the two features that have the biggest correlation in this dataset?
f = plt.figure(figsize=(7, 7))
plt.matshow(df_train[df_train.select_dtypes(include=np.number).columns].corr(), fignum=f.number)
plt.xticks(range(df_train.select_dtypes(include=np.number).shape[1]), df_train.select_dtypes(include=np.number).columns, fontsize=10, rotation=45)
plt.yticks(range(df_train.select_dtypes(include=np.number).shape[1]), df_train.select_dtypes(include=np.number).columns, fontsize=10)
cb = plt.colorbar()
cb.ax.tick_params(labelsize=14)
plt.title('Correlation Matrix', fontsize=16);

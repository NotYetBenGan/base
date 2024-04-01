import pandas as pd
from pandas import DataFrame

df_list_transfrom = []

@transformer
def transform_df(df_list_extract):

    #df2 is (dataset, df) list
    for df2 in df_list_extract:

        df = pd.DataFrame(df2[1])
        dataset = df2[0]

        #For ALL datasets during csv_to_gcs there is new first column Unnamed:_0  
        del df[df.columns[0]]

        #use first row as a header
        if dataset == 'player':
            df.columns = df.iloc[0]
            df = df[1:]


        #Set camelCase column names
        df.columns = df.columns.str.replace('.', '_')
        df.columns = df.columns.str.replace('(', '')
        df.columns = df.columns.str.replace(')', '')
        df.columns = (df.columns.str.lower()
                    .str.replace('_(.)', lambda x: x.group(1).upper(),
                                regex=True)
                )

        #remove duplicated column
        if dataset == 'club_stats':
            del df['offsides1']

        #replace \N with None
        df.replace({'\\N': None},inplace = True)


        df_list_transfrom.append((dataset,df))

    return df_list_transfrom
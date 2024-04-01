from mage_ai.settings.repo import get_repo_path
from mage_ai.io.bigquery import BigQuery
from mage_ai.io.config import ConfigFileLoader
import pandas as pd
from pandas import DataFrame
from os import path

if 'data_exporter' not in globals():
    from mage_ai.data_preparation.decorators import data_exporter

config_path = path.join(get_repo_path(), 'io_config.yaml')
config_profile = 'default'
   
bq_config = ConfigFileLoader(config_path, config_profile)
bq_storage = BigQuery.with_config(bq_config)


@data_exporter
def load_to_bq(df_list_transfrom):

    #df2 is (dataset, df) list
    for df2 in df_list_transfrom:

        df = pd.DataFrame(df2[1])
        dataset = df2[0]

        #add partitioning column - if I do in transformation block - it will be string :(
        if 'season' in df.columns:
            df['seasonStartYear'] = df['season'].str[:4].apply(pd.to_datetime).dt.date
  
        #rename to BQ naming convention
        if dataset == 'club':
            dataset = 'DimClub'
        if dataset == 'manager':
            dataset = 'DimManager' 
        if dataset == 'manager_club':
            dataset = 'DimManagerClub'
        if dataset == 'club_stats':
            dataset = 'DimMatchStats'
        if dataset == 'player':
            dataset = 'DimPlayer'
        if dataset == 'player_club':
            dataset = 'DimPlayerClub'
        if dataset == 'player_performance':
            dataset = 'DimPlayerPerf'
        if dataset == 'player_stats':
            dataset = 'DimPlayerStats'
        if dataset == 'stadium':
            dataset = 'DimStadium'
        if dataset == 'match':
            dataset = 'FactMatch'

        bq_tablename = f'english-premier-league-417019.Stg.{dataset}'

        bq_storage.export(
            df,
            bq_tablename,
            if_exists='replace',  # Specify resolution policy if table name already exists
        )


from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader
from mage_ai.io.google_cloud_storage import GoogleCloudStorage
import pandas as pd
from pandas import DataFrame
from os import path

if 'data_exporter' not in globals():
    from mage_ai.data_preparation.decorators import data_exporter

config_path = path.join(get_repo_path(), 'io_config.yaml')
config_profile = 'default'

gcp_config = ConfigFileLoader(config_path, config_profile)
gcp_storage = GoogleCloudStorage.with_config(gcp_config)
   
df_list_extract = []

@data_loader
def gcp_to_df():

    bucket_name = 'english-premier-league-417019-terraform-bucket'
    datasource = 'DataSource1'

    for dataset in ['manager_club','match']:
    #for dataset in ['club','manager','manager_club','club_stats','player','player_club','player_performance','player_stats','stadium','match']:
        object_path = f'{datasource}/{dataset}.csv'
        df = gcp_storage.load(
            bucket_name,
            object_path
        )

        df_list_extract.append((dataset,df))

    return df_list_extract


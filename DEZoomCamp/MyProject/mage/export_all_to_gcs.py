from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader
from mage_ai.io.google_cloud_storage import GoogleCloudStorage
from pandas import DataFrame
import pandas as pd
from os import path

if 'data_exporter' not in globals():
    from mage_ai.data_preparation.decorators import data_exporter

#google config
config_path = path.join(get_repo_path(), 'io_config.yaml')
config_profile = 'default'

gcp_config = ConfigFileLoader(config_path, config_profile)
gcp_storage = GoogleCloudStorage.with_config(gcp_config)
    


def csv_to_gcs(datasource,dataset):
    
    config_path = path.join(get_repo_path(), 'io_config.yaml')
    config_profile = 'default'
    bucket_name = 'english-premier-league-417019-terraform-bucket'

    url = f'https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/{datasource}/{dataset}.csv?raw=True'        
    csv_file = pd.read_csv(url, encoding='cp1252')
    object_path = f'{datasource}/{dataset}.csv'

    gcp_storage.export(
            csv_file,
            bucket_name,
            object_path,
    )

 

@data_exporter
def output():
    csv_to_gcs('DataSource1','club')
    csv_to_gcs('DataSource1','club_stats')
    csv_to_gcs('DataSource1','manager')  
    csv_to_gcs('DataSource1','manager_club')       
    csv_to_gcs('DataSource1','match')
    csv_to_gcs('DataSource1','player') #'utf-8' codec can't decode byte 0xe9 in position 422: invalid continuation byte
    csv_to_gcs('DataSource1','player_club')
    csv_to_gcs('DataSource1','player_performance')
    csv_to_gcs('DataSource1','player_stats')
    csv_to_gcs('DataSource1','stadium')

    csv_to_gcs('DataSource2','team_discipline')
    csv_to_gcs('DataSource2','matches')
    csv_to_gcs('DataSource2','goal_leaders')  
    csv_to_gcs('DataSource2','events')       
    csv_to_gcs('DataSource2','assist_leaders')
    csv_to_gcs('DataSource2','all_tables')

       
    
# MyProject


## Description of the problem
- This is data engineering project about English Premier League stats, which I love very much
- In this project we will try figure out:
- Who from the players scored the most goals in season range?
- Which team has the best possession in away games in season range?



## Dataset Information 
- [Dataset link](https://www.kaggle.com/datasets/narekzamanyan/barclays-premier-league)

General information
- There were two data sources originally, but I've decided to use only one of them, let's call it [`DataSource1`](DataSource1).
- There are 10 csv files, with match/player stats + dictionaries on players/managers/stadiums + relations between them
- The data is collected since season 1992/1993, but some metrics srted being collected later


## 0. Reproduce preparations
- If you want to reproduce the project, please create new GCP project and service account
- Create Service account credentials JSON keyfile with Role = Owner


## 1. Terrafrom 
- [`main.tf`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/terraform/main.tf) has instructions to create:
  - Bucket in GCP
  - Service account credentials JSON keyfile - need to add Role = Owner to project = "english-premier-league-417019"

- Run in your work directory (WD): 

   ```terraform init```
  
   #Terraform has been successfully initialized!
  
   ```terraform plan```
  
   ```terraform apply```
	
- Now we have bucket in GCP + Service account credentials JSON keyfile in this WD
- Enable APIs for your project:

	https://console.cloud.google.com/apis/library/iam.googleapis.com
	https://console.cloud.google.com/apis/library/iamcredentials.googleapis.com
- Set GOOGLE_APPLICATION_CREDENTIALS variable 


## 2. Mage
- Files used to run up container with Mage (from mage-ai/mage-zoomcamp git hub repo): 
  - [`docker-compose.yml`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/docker-compose.yml) - has instructions from .env and Dockerfile
  - [`Dockerfile`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/Dockerfile) - standard file to create Mage project
- Run:

   ```docker-compose build```
  
   ```docker-compose up```
- Open Mage studio in your browser:
  
   ```http://localhost:6789/``` 

- There are two pipelines in the mage projects
  - epl_github_to_gcs (GitHub to GCS): 
    -- Just one file to upload all csv files to GCS  [`export_all_to_gcs.py`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/export_all_to_gcs.py)
	![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/MageRun_epl_github_to_gcs.jpg)

  - GCS 

	![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/GCS.jpg)

  - epl_gcs_to_bqstg (GCS to BQ) - 3 steps DAG:
  
    -- Extract - load all csv files in the DataFrames [`load_all_from_gcs.py`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/load_all_from_gcs.py)
    
    -- Transform - clean data, remove redundant columns, add partitioning column, based on season [`transform_all.py`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/transform_all.py)
    
    -- Load all prepared DataFrames with camelCase table names to BQ Stg schema [`export_all_to_bqstg`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/mage/export_all_to_bqstg.py)

	![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/MageRun_epl_gcs_to_bqstg.jpg)

- To call the Mage trigger - run this in CLI:
  
  ```curl -i -X POST http://localhost:6789/api/pipeline_schedules/3/pipeline_runs/d7a5c8b8aeaf4322bbdded58a6b4d62d```


## 3. BigQuery:
- There are 2 schemas in our datawarehouse - Stg and Dwh
- All tables in Stg are loaded via Mage ETL
  
	![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/BQ_Stg.jpg)	
- All tables in Dwh are:
  - created by dbt as models
  - partitioned by seasonStartYear, which is sintetic year column for season (for ex seasonStartYear = 2002 where season = 2002/2003)
  - clustered by their PK (playerId, matchId, etc..)
  - Fact table with matches is created from this DBT model [`FactMatch`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/dbt_english_premier_league/models/stg/FactMatch.sql)
  - Dimension tables are started with Dim% prefix
 
	![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/BQ_Dwh.jpg)

[Here should be picture with schema of table relation]


## 4. DBT
- I've created the [DBT Cloud project](https://cloud.getdbt.com/develop/245008/projects/349219)
- The transformations are implemented to prepare:
  - Dwh Tables - see the description above
  - Data Marts - views, based on Dwh.tables:
 
  
    - [`MrtGoalScorers`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/dbt_english_premier_league/models/dwh/MrtGoalScorers.sql) - to collect data about the players scored the most goals in season range
    ![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/DBT_MrtGoalScorers.jpg)


    - [`MrtAwayGames`](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/dbt_english_premier_league/models/dwh/MrtAwayGames.sql) - to collect data about teams, that has the best possession in away games in season range
    ![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/DBT_MrtAwayGames.jpg)  	


## 5. Google Looker Studio
- ReportGoalScorers
  - [https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD](https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD)
    ![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/ReportGoalScorers.jpg)
 
- ReportAwayGames
  - [https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD](https://lookerstudio.google.com/reporting/3db9bd35-d2dc-4866-9067-98a3085b2754/page/622uD)
    ![alt text](https://github.com/NotYetBenGan/base/blob/main/DEZoomCamp/MyProject/images/ReportAwayGames.jpg)

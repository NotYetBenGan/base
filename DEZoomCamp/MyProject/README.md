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
- [`main.tf`](main.tf) has instructions to create:
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
  - docker-compose.yml - has instructions from .env and Dockerfile
  - .env
  - Dockerfile
  - requirements.txt - empty file just to avoid errors
- Run:
  ```docker-compose build```
  ```docker-compose up```
- Open Mage studio in your browser:
  ```http://localhost:6789/``` 

- There are two pipelines in the mage projects
  1. epl_github_to_gcs (GitHub to GCS): 
    - Just one file to upload all csv files  [`export_all_to_gcs.py`](\Data_Engineering\Projects\MyProject\english-premier-league-project\data_exporters\export_all_to_gcs.py)
  2. epl_gcs_to_bqstg (GCS to BQ) - 3 steps DAG: 
    - Extract - load all csv files in the DataFrames
    - Transform - clean data, remove redundant columns, add partitioning column, based on season
    - Load all prepared DataFrames to BQ Stg schema
- To call the Mage trigger - run this in CLI:
  ```curl -i -X POST http://localhost:6789/api/pipeline_schedules/3/pipeline_runs/d7a5c8b8aeaf4322bbdded58a6b4d62d```


## 3. BigQuery:
- There are 2 schemas in our datawarehouse - Stg and Dwh
- All tables in Stg are loaded via Mage ETL
- All tables in Dwh are:
  - created by dbt as models
  - partitioned by seasonStartYear, which is sintetic year column for season (for ex seasonStartYear = 2002 where season = 2002/2003)
  - clustered by their PK (playerId, matchId, etc..)
  - Fact table with matches is FactMatches
  - Dimension tables are started with Dim% prefix

[Here should be picture with schema]


## 4. DBT
- I've created the [DBT Cloud project](https://cloud.getdbt.com/develop/245008/projects/349219)
- The transformations are implemented to prepare:
  - Dwh object - see the description above
  - Data Marts:
    - 'MrtGoalScorers' - to collect data about the players scored the most goals in season range
    - 'MrtAwayGames' - to collect data about teams, that has the best possession in away games in season range


## 5. Google Looker Studio
- ReportGoalScorers
  - [https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD](https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD)
  - [image]
 
- ReportAwayGames
  - [https://lookerstudio.google.com/reporting/65123d92-abf5-4b86-b2ce-1a5be6ddce37/page/fh1uD](https://lookerstudio.google.com/reporting/3db9bd35-d2dc-4866-9067-98a3085b2754/page/622uD)
  - [image]

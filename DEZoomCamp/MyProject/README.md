# MyProject


## Description of the problem
- This is data engineering project about English Premier League stats, which I love very much
- In this project we will try figure out:
	- Who from the players scored the most goals in season range?
	- Which team has the best possession in away games in season range?



## Dataset Information 
- [Dataset link]([https://www.kaggle.com/datasets/narekzamanyan/barclays-premier-league])

General information
- There were two data sources originally, but I've decided to use only one of them, let's call it [`DataSource1`](DataSource1).
- There are 10 csv files, with match/player stats + dictionaries on players/managers/stadiums + relations between them
- The data is collected since season 1992/1993, but some metrics srted being collected later

## 1. Terrafrom
	- main.tf has instructions to create:
		- Bucket in GCP
		- Service account credentials JSON keyfile - need to add Role = Owner to project = "english-premier-league-417019"

	- Run in your work directory (WD):
		```terrafrom init```
		#Terraform has been successfully initialized!
		```terraform plan```
		```terrafrom apply```	
	- Now we have bucket in GCP + Service account credentials JSON keyfile in this WD 


## 2. Mage
	- Files used to run up container with Mage (from mage-ai/mage-zoomcamp git hub repo): 
		- docker-compose.yml - has instructions from .env and Dockerfile
		- .env
		- Dockerfile
		- requirements.txt - empty file just to avoid errors
	- Run:
		```docker-compose build```
		```docker-compose up```
		```http://localhost:6789/``` <- open Mage studio in your browser
  
	- New folder english-premier-league-project is created 

	- GitHub to GCS: 
		- Just one file will upload all csv files  c:\Users\vpere\Desktop\Data_Engineering\Projects\MyProject\english-premier-league-project\data_exporters\export_all_to_gcs.py
	- GCS to BQ: 
		- First option: 3 steps DAG to extract (67s) + transform (87s) + load (128s) all files to BQ
		- Alternative option: Just one file will upload all csv files: export_all_to_bqstg2.py
	- To call the trigger - run this in CLI: C:\Users\vpere>curl -i -X POST http://localhost:6789/api/pipeline_schedules/3/pipeline_runs/d7a5c8b8aeaf4322bbdded58a6b4d62d


## 3. BigQuery:
	- All tables in Dwh are:
		- partitioned by seasonStartYear, which is sintetic year column for season (for ex seasonStartYear = 2002 where season = 2002/2003)
		- clustered by their PK (playerId, matchId, etc..)


Project english-premier-league

0. Prerequisites:
	- Start Docker desktop
	- Working Directory (WD) = C:/Users/vpere/Desktop/Data_Engineering/Projects/MyProject


1. Terrafrom
	- main.tf has instructions to create:
		- Bucket in GCP
		- Service account credentials JSON keyfile
	- Run:
		cd WD
		terrafrom init
		#Terraform has been successfully initialized!
		terraform plan
		terrafrom apply	
	- Now we have bucket in GCP + Service account credentials JSON keyfile service_account_key_file.json in the WD :)


2. Mage
	- Files used to run up container with Mage (from mage-ai/mage-zoomcamp git hub repo): 
		- docker-compose.yml - has instructions from .env and Dockerfile
		- .env
		- Dockerfile
		- requirements.txt - empty file just to avoid errors
	- Run:
		docker-compose build
		docker-compose up
		http://localhost:6789/ 
	- Set GOOGLE_SERVICE_ACC_KEY_FILEPATH: "/home/src/service_account_key_file.json" and remove other google variables

FROM python:3.10-slim

# Install pipenv library in Docker 
RUN pip install pipenv

# create a directory in Docker named app and we're using it as work directory 
WORKDIR /app                                                                

# Copy the Pip files into our working derectory /app
COPY ["Pipfile", "Pipfile.lock", "./"]

# Install the pipenv dependencies for the project and deploy them
RUN pipenv install --deploy --system

# Copy "predict.py", "train.py" and the model we had to the working directory of Docker 
COPY ["predict.py", "train.py", "model_C=10.bin", "./"]

# We need to expose the 9696 port because we're not able to communicate with Docker outside it
EXPOSE 9696

# If we run the Docker image, we want our predict app to be running
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:9696", "predict:app"]
# Capstone1 Project


## Description of the problem
- This is classical image classification problem - to distinguish input images dataset between 2 categories. In this project we try to classify humans and horses.
- We will train the CNN model, save it and use via lambda function in the Docker container


## Dataset Information and EDA (Exploratory Data Analysis)
- [Dataset link](http://laurencemoroney.com/horses-or-humans-dataset)

General information
- All Images are 300×300 pixels in 24-bit color.
- They’re arranged into sub folders within the zip that makes it easy to auto label them using a Keras ImageGenerator
- There is diversity of humans, so there are both men and women and Asian, Black, South Asian, and Caucasians present in the training set.

Information about the train dataset [`horse-or-human`](horse-or-human):
- Contains 500 rendered images of various species of horse in multiple poses in multiple locations.
- It also includes 527 rendered images of humans in different poses and backgrounds.

Information about the validation dataset [`validation-horse-or-human`](validation-horse-or-human):
- Adds six different figures to ensure breadth of data.
- Contains 128 horse images and 128 human images.


## Model Training
Model training was done in a Jupyter Notebook in the [Saturn Cloud](https://app.community.saturnenterprise.io/dash/o/community/resources). Please, follow [`notebook.ipynb`](notebook.ipynb) file in this github project. In this notebook I took as example a model from homework #8, it is based on Keras:
- The shape for input should be (150, 150, 3)
- Convolutional layer to produce a tensor of outputs
  - (Conv2D) with 32 filters, Kernel size (3, 3), 'relu' activation function
- Pooling layer to reduce the dimensionality of the feature map with max pooling
  - (MaxPooling2D) with pooling size (2, 2)
- Flatten layer to convert all the resultant 2D arrays from pooled feature maps into a single linear vector
- Dense layer #1
  - with 64 neurons and 'relu' activation function
- Dense layer #2 (additional)
  - with 1 neuron and sigmoid activation function
- Optimizer
  - SGD with parametrized learning_rate (0.02 as default) and momentum=0.8
 
Tuning:
- added extra inner layer
- adjusting learning rate [0.002, 0.02, 0.2]

On my choise the learning_rate = 0.02 shows the best performance [`Choose_best_Learning_rate.png`](Choose_best_Learning_rate.png)

The model was trained for 10 epochs based on the [Dataset](http://laurencemoroney.com/horses-or-humans-dataset)


## Exporting notebook to script
In the notebook I've created the final model and saved it as separate file on my machine for local testing.
- We create the same model running [`train.py`](train.py). As an output we have `model_lr_0_02_0X_0.YYY.h5` file, where X - epoch number and YYY - validation accuracy. I already use learning_rate = 0.02 inside, as it shows the best performace. The best validation accuracy was 0.895 
- Next we convert the model to tensorflow lite format in [`convert_lite.py`](convert_lite.py). As an output we have `model.tflite` file
- Then we can use the model via [`predict.py`](predict.py) on the test image located [here](https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png)


## Reproducibility
- Download [`train.py`](train.py), [`convert_lite.py`](convert_lite.py), [`predict.py`](predict.py) scripts in your location
- Start CMD in this location
- Run in CMD ```python train.py ``` (some TF warnings could appear during the run)
- Choose the file with MAX(YYY) in model_lr_0_02_0X_0.YYY.h5 - this will be the best validation accuracy
- Open convert_lite.py script and amend the line #13 to set the real X and YYY numbers there 
- Run in CMD ```python convert_lite.py ```
- Run in CMD ```python predict.py ```
- Run in CMD ```ipython ```
- Run in CMD ```import predict ```
- Run in CMD ```url = f'https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png' ```
- Run in CMD ```predict.predict(url) ```

As a result, you will get some small number which is close to 0. As we have 2 classes: {'horses': 0, 'humans': 1} - highly likley we have a hourse on the picture :) 


## Model Deployment and enviroment management
Create a new virtual environment for testing the deployment.

- Run in Anaconda CMD - to create new environment 
    ```bash
    conda create --name deployment-capstone1 python=3.10.12
    ```	
- Run in Anaconda CMD - to activate the virtual environment
    ```bash
    conda activate deployment-capstone1
    ```
- Go to your location, where you already have [`predict.py`](predict.py)
- Within the activated virtual environment `(deployment-capstone1)` install the requirements from the [`deployment-requirements.txt`](deployment-requirements.txt) 
    ```bash
    pip install -r deployment-requirements.txt
    ```
- Run in Anaconda CMD ```python predict.py ```
- Run in Anaconda CMD ```ipython ```
- Run in Anaconda CMD ```import predict ```
- Run in Anaconda CMD ```url = f'https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png' ```
- Run in Anaconda CMD ```predict.predict(url) ```

A a result you again will get the classification number close to 0.


## Containerization
I use Docker Desktop preinstalled on my machine. Let's put the prediction in a Docker container. 

1. I've prepared [`Dockerfile`](Dockerfile) with instructions. Unfortunately, I was not able to avoid ```RUN pip install tensorflow``` command. It took less than 2 minutees to install it during the build. If you know how to avoid this, please write in the review 

2. Running the Docker Container and testing

- Run in CMD building the Docker image based on [`Dockerfile`](Dockerfile)
    ```bash
    docker build -t model .
    ```

- Run in CMD the Docker container itself
    ```bash	
    docker run -it --rm -p 8080:8080 model
    ```

- Open CLI for running container the in Docker Desktop and run
    ```bash
    python predict.py
    python test.py	
    ```
- We have our prediction float number again :)

# Capstone1 Project


## Description of the problem
- This is classical image classification problem - to distinguish input images dataset between 2 categories. In this project we try to classify humans and horses.
- We will train the CNN model, save it and use via lambda function


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
- 128 horse images and 128 human images.


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
- extra inner layers
- adjusting learning rate
- size of the inner layer

On my choise the learning_rate = 0.02 shows the best performance [`Choose_best_Learning_rate.png`](Choose_best_Learning_rate.png)


The model was trained for 10 epochs based on the [Dataset](http://laurencemoroney.com/horses-or-humans-dataset)


## Exporting notebook to script
In the notebook I've created the final model and saved it to as separate file [`model_lr_0_02_05_0.895.h5`](model_lr_0_02_05_0.895.h5),
- We can create the same model running [`train.py`](train.py) in CMD
- Next we convert the model to tensorflow lite format. Run [`convert_lite.py`](convert_lite.py) in CMD
- Then we can use the model via [`predict.py`](predict.py) on the test image located [here](https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png)


## Reproducibility
- Download [`train.py`](train.py), [`convert_lite.py`](convert_lite.py), [`predict.py`](predict.py) scripts in your location
- Download [`model_lr_0_02_05_0.895.h5`](model_lr_0_02_05_0.895.h5) - the best model I got so far - in your location
- Start CMD in this location
- Steps to run in CMD:
1. _python train.py_ (some TF warnings could appear during the run)
2. _python convert_lite.py_
3. _python predict.py_
4. _ipython_
5. _import predict_
6. _url = f'https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png'_
7. _predict.predict(url)_

As a result, we get some small number ~0.003, which is close to 0. As we have 2 classes: {'horses': 0, 'humans': 1} - highly likley we have a hourse on the picture :) 


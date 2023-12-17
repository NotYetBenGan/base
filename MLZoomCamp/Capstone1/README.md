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

Information about the train dataset [horse-or-human]:
- Contains 500 rendered images of various species of horse in multiple poses in multiple locations.
- It also includes 527 rendered images of humans in different poses and backgrounds.

Information about the validation dataset [validation-horse-or-human]:
- Adds six different figures to ensure breadth of data.
- 128 horse images and 128 human images.

In this github project there is a folder [horse-or-human] with some samples


## Model Training
Model training was done in a Jupyter Notebook in Saturn Cloud. Please, follow [`notebook.ipynb`](notebook.ipynb) file in this github project. In this notebook I took as example a model from homework #8, it is based on Keras:
- The shape for input should be (150, 150, 3)
- Convolutional layer to produce a tensor of outputs
  - (Conv2D) with 32 filters, Kernel size (3, 3), 'relu' activation function
- Pooling layer to reduce the dimensionality of the feature map with max pooling
  - (MaxPooling2D) with pooling size (2, 2)
- Flatten layer to convert all the resultant 2D arrays from pooled feature maps into a single linear vector
- Dense layer #1
  - with 64 neurons and 'relu' activation function
- Dense layer #2 (optional)
  - with 1 neuron and sigmoid activation function
- Optimizer
  - SGD with parametrized learning_rate (0.002 as default) and momentum=0.8
 
Tuning:
- extra inner layers
- adjusting learning rate
- size of the inner layer

The model was trained for 10 epochs

## Exporting notebook to script
In the notebook I've created the final model and saved it to as separate file [`model.bin`](model.bin), same code used in [`train.py`](train.py). You can see both in this github project.


TF_ENABLE_ONEDNN_OPTS=0

import tensorflow as tf
from tensorflow import keras

TF_ENABLE_ONEDNN_OPTS=0

import numpy as np
import matplotlib.pyplot as plt
%matplotlib inline
from tensorflow.keras.preprocessing.image import load_img

#This is only for first load
!wget https://github.com/SVizor42/ML_Zoomcamp/releases/download/bee-wasp-data/data.zip
!unzip data.zip

#Test 1 image load
path = './data/train/wasp/'
name = '9982947853_6a7a859cd6_n.jpg'
fullname = f'{path}/{name}'
load_img(fullname)
img = load_img(fullname, target_size=(299, 299))

x = np.array(img)
x.shape

### Develop the model with following structure
###################################################################
input_shape=(150,150,3) # (height, width, channels)

#Run this 2 times! The first time is some error!
inputs = keras.Input(shape=input_shape)

# Create a Convolutional layer to produce a tensor of outputs
conv_2d_out = tf.keras.layers.Conv2D(32, #filters
                           (3, 3), #kernel_size
                           activation='relu', 
                           input_shape=input_shape)(inputs)
print(conv_2d_out.shape) # batch_size + (new_rows, new_cols, filters)

# Create a Pooling layer to reduce the dimensionality of the feature map with max pooling 
max_pool_2d_out = tf.keras.layers.MaxPooling2D(pool_size=(2, 2),input_shape=input_shape)(conv_2d_out)
print(max_pool_2d_out.shape)

# Create Flatten layer to convert all the resultant 2D arrays from pooled feature maps into a single linear vector
vectors = tf.keras.layers.Flatten()(max_pool_2d_out)
print(vectors.shape)

# Create Dense layer of 64
outputs_dense_1 = tf.keras.layers.Dense(64, activation='relu')(vectors)
print(outputs_dense_1.shape)

# Create Dense layer of 1 with sigmoid activation function
outputs = tf.keras.layers.Dense(1, activation='sigmoid')(outputs_dense_1)
print(outputs.shape)

model2 = keras.Model(inputs, outputs)

###################################################################

# Define learning rate
learning_rate = 0.002

# Create optimizer
optimizer = keras.optimizers.SGD(learning_rate=learning_rate, momentum=0.8)

# Define loss function
loss = tf.keras.losses.BinaryCrossentropy()

# Compile the model
model2.compile(optimizer=optimizer,
              loss=loss,
              metrics=['accuracy']) # evaluation metric accuracy

model2.summary()

###################################################################

### Generators and Training

from tensorflow.keras.preprocessing.image import ImageDataGenerator

# Build image generator for training (takes preprocessing input function)
train_gen = ImageDataGenerator(rescale=1./255)
target_size = (150, 150) #homework requirement
batch_size = 20          #homework requirement
class_mode='binary'

# Load in train dataset into train generator
train_ds = train_gen.flow_from_directory(
    './data/train/',
    target_size=target_size,
    batch_size=batch_size, 
    shuffle=True   
    ,class_mode=class_mode
)

val_gen = ImageDataGenerator(rescale=1./255)

val_ds = val_gen.flow_from_directory(
    './data/test/',
    target_size=target_size,
    batch_size=batch_size, 
    shuffle=True   
    ,class_mode=class_mode
)

# Train the model, validate it with validation data, and save the training history
history = model2.fit(train_ds, epochs=10, validation_data=val_ds)

###################################################################

### Check the statistics

import statistics
round(statistics.median(history.history['accuracy']),3)
round(statistics.stdev(history.history['loss']),3)



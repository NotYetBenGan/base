TF_ENABLE_ONEDNN_OPTS=0

import tensorflow as tf
from tensorflow import keras
import numpy as np
import matplotlib.pyplot as plt
from tensorflow.keras.preprocessing.image import load_img
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os
import zipfile,fnmatch,urllib.request, shutil
from pathlib import Path




# Download train and validation image datasets
train_folder = Path('/horse-or-human')
val_folder = Path('/validation-horse-or-human')
url = 'https://storage.googleapis.com/learning-datasets'

if not train_folder.exists():
    file_name_train = 'horse-or-human.zip'
    url_train = f'{url}/{file_name_train}'
    with urllib.request.urlopen(url_train) as response, open(file_name_train, 'wb') as out_file:
        shutil.copyfileobj(response, out_file)

if not val_folder.exists():        
    file_name_val = 'validation-horse-or-human.zip'
    url_val = f'{url}/{file_name_val}'
    with urllib.request.urlopen(url_val) as response, open(file_name_val, 'wb') as out_file:
        shutil.copyfileobj(response, out_file)

# Unzip to respective folders
rootPath = os.getcwd()
pattern = '*.zip'
for root, dirs, files in os.walk(rootPath):
    for filename in fnmatch.filter(files, pattern):
        print(os.path.join(root, filename))
        zipfile.ZipFile(os.path.join(root, filename)).extractall(os.path.join(root, os.path.splitext(filename)[0]))


def make_model(learning_rate=0.02):
    input_shape=(150,150,3) # (height, width, channels)

    #Run this 2 times! The first time is some error!
    inputs = keras.Input(shape=input_shape)

    # Create a Convolutional layer to produce a tensor of outputs
    conv_2d_out = tf.keras.layers.Conv2D(32, #filters
                               (3, 3), #kernel_size
                               activation='relu', 
                               input_shape=input_shape)(inputs)
    #print(conv_2d_out.shape) # batch_size + (new_rows, new_cols, filters)

    # Create a Pooling layer to reduce the dimensionality of the feature map with max pooling 
    max_pool_2d_out = tf.keras.layers.MaxPooling2D(pool_size=(2, 2),input_shape=input_shape)(conv_2d_out)
    #print(max_pool_2d_out.shape)

    # Create Flatten layer to convert all the resultant 2D arrays from pooled feature maps into a single linear vector
    vectors = tf.keras.layers.Flatten()(max_pool_2d_out)
    #print(vectors.shape)

    # Create Dense layer of 64
    outputs_dense_1 = tf.keras.layers.Dense(64, activation='relu')(vectors)
    #print(outputs_dense_1.shape)

    # Create Dense layer of 1 with sigmoid activation function
    outputs = tf.keras.layers.Dense(1, activation='sigmoid')(outputs_dense_1)
    #print(outputs.shape)

    model = keras.Model(inputs, outputs)

    ###################################################################

    # Define learning rate
    #learning_rate = learning_rate

    # Create optimizer
    optimizer = keras.optimizers.SGD(learning_rate=learning_rate, momentum=0.8)

    # Define loss function
    loss = tf.keras.losses.BinaryCrossentropy()

    # Compile the model
    model.compile(optimizer=optimizer,
                  loss=loss,
                  metrics=['accuracy']) # evaluation metric accuracy
    
    return model



target_size = (150, 150) #homework requirement
batch_size = 20          #homework requirement
class_mode='binary'

# Build image generator for training 
train_gen = ImageDataGenerator(rescale=1./255)

# Load in train dataset into train generator
train_ds = train_gen.flow_from_directory(
    './horse-or-human/',
    target_size=target_size,
    batch_size=batch_size, 
    shuffle=True   
    ,class_mode=class_mode
)    

val_gen = ImageDataGenerator(rescale=1./255)

# Always keep validation as is - not to confuse the model
val_ds = val_gen.flow_from_directory(
    './validation-horse-or-human/',
    target_size=target_size,
    batch_size=batch_size, 
    shuffle=True   
    ,class_mode=class_mode
)


chechpoint = keras.callbacks.ModelCheckpoint(
    'model_lr_0_02_{epoch:02d}_{val_accuracy:.3f}.h5',
    save_best_only=True,
    monitor='val_accuracy',
    mode='max'
)


# Train the model, validate it with validation data, and save the training history
scores = {}
for lr in [0.02]:#[0.002, 0.02, 0.2]:
    print(lr)

    model = make_model(learning_rate=lr)
    history = model.fit(train_ds, epochs=10, validation_data=val_ds, callbacks=[chechpoint])
    scores[lr] = history.history

    print()
    print()


# Save the model
model.save('model_lr_0_02_05_0.895.h5', save_format='h5')
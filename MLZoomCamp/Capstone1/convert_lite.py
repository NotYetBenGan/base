#Run in CMD
#Use this advice in case of error https://stackoverflow.com/questions/63404192/pip-install-tensorflow-cannot-find-file-called-client-load-reporting-filter-h

#pip install tensorflow
#ipython

import numpy as np
import tensorflow as tf
from tensorflow import keras
import os
import tensorflow.lite as tflite

model = keras.models.load_model('model_lr_0_02_05_0.895.h5')

#Convert this model from Keras to TF-Lite format
converter = tf.lite.TFLiteConverter.from_keras_model(model)
model_lite = converter.convert()
with open('model.tflite', 'wb') as f_out:
    f_out.write(model_lite)


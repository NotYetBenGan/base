import numpy as np
import tensorflow as tf
from tensorflow import keras
import os
import tensorflow.lite as tflite

model = keras.models.load_model('model_lr_0_02_08_0.785.h5') #Put your numbers instead of 08 (X) and 785 (YYY)

#Convert this model from Keras to TF-Lite format
converter = tf.lite.TFLiteConverter.from_keras_model(model)
model_lite = converter.convert()
with open('model.tflite', 'wb') as f_out:
    f_out.write(model_lite)


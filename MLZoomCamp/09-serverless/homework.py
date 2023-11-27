#Run in CMD
pip install tensorflow
ipyton
import tensorflow as tf
from tensorflow import keras
model = keras.models.load_model('bees-wasps.h5')

#Convert this model from Keras to TF-Lite format
converter = tf.lite.TFLiteConverter.from_keras_model(model)
model_lite = converter.convert()
with open('model.tflite', 'wb') as f_out:
    f_out.write(model_lite)

#Q1. Get the new format size
import os
filesize = os.path.getsize('model.tflite')
print(f'{ filesize / (1024**2)} MB')


#Q2. Get the index of the output
import tensorflow.lite as tflite
interpreter = tflite.Interpreter(model_path='model.tflite')
interpreter.allocate_tensors()
input_index = interpreter.get_input_details()[0]['index']
output_index = interpreter.get_output_details()[0]['index']

print(output_index)


#Preparing the image


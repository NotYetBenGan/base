#Run in CMD
#Use this advice in case of error https://stackoverflow.com/questions/63404192/pip-install-tensorflow-cannot-find-file-called-client-load-reporting-filter-h
pip install tensorflow
ipython

import numpy as np
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
!pip install pillow

from io import BytesIO
from urllib import request
from PIL import Image

def download_image(url):
    with request.urlopen(url) as resp:
        buffer = resp.read()
    stream = BytesIO(buffer)
    img = Image.open(stream)
    return img


def prepare_image(img, target_size):
    if img.mode != 'RGB':
        img = img.convert('RGB')
    img = img.resize(target_size, Image.NEAREST)
    return img

img = prepare_image(
    download_image('https://habrastorage.org/webt/rt/d9/dh/rtd9dhsmhwrdezeldzoqgijdg8a.jpeg'),
    (150, 150)
)


#Q4. Get the value in the first pixel, the R channel?
x = np.array(img, dtype='float32')
x = x/ 255
x[0,0,0] 


#Q4. Get preds
X = np.array([x])
interpreter.set_tensor(input_index, X)
interpreter.invoke()
preds = interpreter.get_tensor(output_index)
preds

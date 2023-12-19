# Base image
FROM public.ecr.aws/lambda/python:3.10 

# Install necessary libraries in Docker
# It doesn't work without tensorflow - 475MB took 100sec to install for me 
RUN pip install tensorflow
RUN pip install keras-image-helper
RUN pip install https://github.com/alexeygrigorev/tflite-aws-lambda/raw/main/tflite/tflite_runtime-2.14.0-cp310-cp310-linux_x86_64.whl

COPY model.tflite .
COPY predict.py .
COPY test.py .

CMD [ "predict.lambda_handler" ]
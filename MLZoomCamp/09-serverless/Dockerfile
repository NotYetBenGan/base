FROM agrigorev/zoomcamp-bees-wasps:v2

RUN pip install pillow
RUN pip install https://github.com/alexeygrigorev/tflite-aws-lambda/raw/main/tflite/tflite_runtime-2.14.0-cp310-cp310-linux_x86_64.whl

COPY predict.py .

CMD [ "predict.lambda_handler" ]
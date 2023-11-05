from flask import Flask, request, jsonify
import pickle

def load_model(model_file):
    with open(model_C_10_file, 'rb') as f_in:
        dv, model = pickle.load(f_in)
        return dv, model

def predict_single(customer, dv, model):
  X = dv.transform([customer])
  y_pred = model.predict_proba(X)[:, 1]
  return y_pred[0]

app = Flask('Midterm Churn prediction')
model_C_10_file = 'model_C=10.bin'

@app.route('/predict', methods=['POST'])
def predict():
    customer = request.get_json()

    dv, model = load_model(model_C_10_file)
    prediction_single = predict_single(customer, dv, model)
    
    churn = prediction_single >= 0.5

    #Prepare response in JSON format
    result = {
        'customer_churn_probability': float(prediction_single),
        'churn': bool(churn)
    }

    return jsonify(result)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=9696)
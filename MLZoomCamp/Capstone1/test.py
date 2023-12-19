import requests

url = 'http://localhost:8080/2015-03-31/functions/function/invocations'
event = {'url': 'https://habrastorage.org/webt/h9/l5/yj/h9l5yjjbhyo8ocvulhlmg6gbcni.png'  }

result = requests.post(url, json=event).json()
print(result)

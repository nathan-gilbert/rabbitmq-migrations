#!/bin/bash
apt update -y
apt install -y python3 python3-pip
pip3 install flask boto3

cat <<EOL > /home/ubuntu/app.py
from flask import Flask, request
import boto3
import json

app = Flask(__name__)

@app.route("/", methods=["GET", "POST"])
def sns_handler():
    if request.method == "POST":
        message = json.loads(request.data)
        print("Received message:", message)
        return "Message received", 200
    return "SNS Subscription Active", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOL

nohup python3 /home/ubuntu/app.py &

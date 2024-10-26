#!/bin/bash
apt update -y
apt install -y python3 python3-pip python3-flask python3-boto3

cat <<EOL > /home/ubuntu/app.py
from flask import Flask, request, jsonify
import json
import boto3
import logging

app = Flask(__name__)

# Set up logging
logging.basicConfig(level=logging.INFO)

@app.route("/", methods=["POST"])
def sns_handler():
    # Parse the incoming request JSON data
    sns_message = request.get_json()

    # Validate SNS message type
    message_type = request.headers.get("x-amz-sns-message-type")
    if message_type == "SubscriptionConfirmation":
        # Handle the Subscription Confirmation
        token = sns_message["Token"]
        topic_arn = sns_message["TopicArn"]

        # Confirm the subscription
        client = boto3.client("sns")
        response = client.confirm_subscription(
            TopicArn=topic_arn,
            Token=token
        )
        logging.info("Subscription confirmed: %s", response)
        return jsonify({"message": "Subscription confirmed"}), 200

    elif message_type == "Notification":
        # Process SNS Notification
        notification_message = sns_message["Message"]
        logging.info("Received SNS message: %s", notification_message)
        return jsonify({"message": "Notification received"}), 200

    else:
        logging.warning("Unknown message type: %s", message_type)
        return jsonify({"error": "Unknown message type"}), 400

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOL

nohup python3 /home/ubuntu/app.py &

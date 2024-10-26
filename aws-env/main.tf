provider "aws" {
  region = "us-west-1"
}

resource "aws_sns_topic" "example_topic1" {
  name = "my_example_topic1"
}

resource "aws_iam_role" "ec2_sns_role" {
  name = "ec2_sns_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "sns_access_policy" {
  name = "sns_access_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sns:Subscribe",
          "sns:Receive",
          "sns:ListSubscriptionsByTopic"
        ]
        Resource = aws_sns_topic.example_topic1.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_sns_policy" {
  role       = aws_iam_role.ec2_sns_role.name
  policy_arn = aws_iam_policy.sns_access_policy.arn
}

resource "tls_private_key" "ec2_instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a Private Key and encode it as PEM.
resource "aws_key_pair" "ec2_instance_key_pair" {
  key_name   = "${replace(lower(var.instance_name), " ", "-")}_key"
  public_key = tls_private_key.ec2_instance_key.public_key_openssh

  provisioner "local-exec" {
    command     = "echo '${tls_private_key.ec2_instance_key.private_key_pem}' > ./${var.instance_name}_key.pem"
    interpreter = ["pwsh", "-Command"]
  }
}

resource "aws_instance" "flask_app" {
  ami           = "ami-0da424eb883458071" # Ubuntu 22.04
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_instance_key_pair.id

  user_data = <<-EOF
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
  EOF

  tags = {
    Name = var.instance_name
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_sns_role.name
}

resource "aws_sns_topic_subscription" "flask_app_subscription" {
  topic_arn = aws_sns_topic.example_topic1.arn
  protocol  = "http"
  endpoint  = "http://${aws_instance.flask_app.public_ip}:5000/"
}

# Cloud-Computing-Illinois-Tech Assignments
Assignment Repository for Coursera's Cloud Computing by Illinois Tech.

## Architecture
1. For **Autoscaling** of **EC2 Instances** using *Auto Scaling Group*, *Application ELB*, and *Target Group:*
![aws assignment architecture](architecture.png)

## Requirements
We need to install some packages into Vagrant box:
```bash
sudo apt update
sudo apt install python3-dev python3-setuptools python3-pip python3-venv
```

Then to install required python packages:
```python
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r ./requirements.txt
```

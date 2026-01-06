# Zabbix AWS Architecture with Docker Compose

A production-ready Zabbix monitoring stack deployed on an AWS EC2 instance using Docker Compose. This setup provides a fast and scalable way to monitor your infrastructure with minimal configuration.

---

## Project Overview

This repository contains a `docker-compose.yml` file that sets up a full Zabbix monitoring environment on an Ubuntu-based EC2 instance. It includes:

- Zabbix Server
- Zabbix Web Interface (Apache + PHP)
- Zabbix Agent
- MySQL Database

---

## Quick Start

### 1. Clone the Repository

```bash

git clone https://github.com/chraibimo/zabbix-aws-architecture.git
cd zabbix-aws-architecture


2. Launch the Stack
docker-compose up -d



3. Access the Zabbix Web Interface
Open your browser and go to:
http://<your-ec2-public-ip>:8080


Default credentials:
- Username: Admin
- Password: zabbix

<img width="1248" height="796" alt="login" src="https://github.com/user-attachments/assets/cfb1d71c-cb79-4ce8-a189-f9b9efcfd057" />

Requirements
- AWS EC2 instance (Ubuntu 20.04 or later)
- Docker and Docker Compose installed
- Open ports: 8080 (Web UI), 10050 (Agent), 10051 (Server), 3306 (MySQL), 80 (HTTP) , 443 (HTTPS),

File Structure
zabbix-aws-architecture/
├── docker-compose.yml
├── README.md
└── screenshots/
    ├── zabbix-login.png
    └── zabbix-dashboard.png


Place your screenshots in the screenshots/ folder. You can create it manually or upload images directly via GitHub.


Screenshots


Useful Commands
|  |  | 
|  | docker-compose up -d | 
|  | docker-compose down | 
|  | docker-compose logs -f | 
|  | docker ps | 
|  | docker-compose up --build -d | 



Customization
You can modify the docker-compose.yml file to:
- Change database credentials
- Add persistent volumes
- Enable email alerts or integrations
- Scale services

Troubleshooting
- Zabbix not loading?
Run docker ps to ensure all containers are up.
- Database errors?
Check MySQL container logs:
docker-compose logs mysql
- Port conflicts?
Make sure ports 8080, 10050, and 10051 are not in use.

Something Special
This project was built with simplicity and scalability in mind. Whether you're monitoring a single server or a growing cloud infrastructure, this setup gives you a solid foundation to build on. Contributions, ideas, and improvements are always welcome.

License
This project is licensed under the MIT License.

---

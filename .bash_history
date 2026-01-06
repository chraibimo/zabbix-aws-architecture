sudo apt update
sudo apt install zabbix-agent
apt list --upgradable
sudo apt install zabbix-agent
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.gpg | sudo tee /etc/apt/trusted.gpg.d/zabbix.asc
echo "deb https://repo.zabbix.com/zabbix/6.0/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt update
curl -fsSL https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX | sudo tee /etc/apt/trusted.gpg.d/zabbix.asc
sudo apt update
sudo apt install zabbix-agent
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.gpg | sudo tee /etc/apt/trusted.gpg.d/zabbix.asc
echo "deb https://repo.zabbix.com/zabbix/6.0/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/zabbix.list
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.gpg | sudo tee /etc/apt/trusted.gpg.d/zabbix.asc
wget https://repo.zabbix.com/zabbix-official-repo.gpg
sudo mv zabbix-official-repo.gpg /etc/apt/trusted.gpg.d/
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
nano docker-compose.yml
docker-compose up -d
sudo usermod -aG docker $USER
newgrp docker
docker info
docker-compose up -d
sudo systemctl status docker
sudo systemctl start docker
docker-compose --version
docker ps
docker logs zabbix-web
docker-compose down
docker-compose up -d
docker exec -it zabbix-web sh
docker logs zabbix-web
docker ps
docker logs zabbix-web
docker logs zabbix-db
docker-compose down -v
docker-compose up --build -d
docker logs zabbix-web
docker logs zabbix-db
docker exec -it zabbix-db sh
docker-compose up -d
docker ps -a
docker ps
docker logs zabbix-web
**** PostgreSQL server is not available. Waiting 5 seconds...
ubuntu@ip-10-0-1-156:~$
docker inspect --format '{{json .State.Health}}' zabbix-web
docker exec -it zabbix-web sh
ping zabbix-server
docker inspect zabbix-db
docker exec -it zabbix-db psql -U postgres
docker exec -it zabbix-db sh
docker exec -it zabbix-db psql -U zabbix
docker exec -it zabbix-db psql -U postgres
docker logs zabbix-web
docker logs zabbix-server
docker logs zabbix-db
sudo apt update
sudo apt install zabbix-agent -y
sudo rm /etc/apt/sources.list.d/zabbix.list
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-6+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_6.0-6+ubuntu24.04_all.deb
sudo apt update
sudo apt install zabbix-agent -y
sudo nano /etc/zabbix/zabbix_agentd.conf
sudo systemctl restart zabbix-agent
sudo systemctl enable zabbix-agent
sudo systemctl status zabbix-agent
sudo nano /etc/zabbix/zabbix_agentd.conf
sudo systemctl restart zabbix-agent
ping 174.129.178.235
telnet 174.129.178.235 10051
ping 174.129.178.235
telnet 174.129.178.235 10051
sudo systemctl status zabbix-agent
sudo systemctl status zabbix-agent
sudo nano /etc/zabbix/zabbix_agentd.conf
sudo tail -f /var/log/zabbix/zabbix_agentd.log
sudo nano /etc/zabbix/zabbix_agentd.conf

ping zabbix-server
sudo apt update
sudo apt install git -y
cd ~/EC2Launch
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from Linux"
git branch -M main
git push -u origin main
cd ~/EC2Launch
git init
cd /mnt/c/Users/motah/Desktop
ls
ls /mnt/c/Users
cp -r EC2Launch ~/EC2Launch
cd ~/EC2Launch
pwd
ls
ls /mnt/c/Users
ls /mnt/c/Users/motah/Desktop
uname -a
exit
cd ~/ec2launch
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
cd ~/ec2launch
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
cd ~/ec2launch
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
cd ~/ec2launch
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
-bash: cd: /home/ubuntu/ec2launch: No such file or directory
Reinitialized existing Git repository in /home/ubuntu/.git/
error: remote origin already exists.
On branch main
nothing to commit, working tree clean
From https://github.com/chraibimo/zabbix-aws-architecture
Current branch main is up to date.
Username for 'https://github.com': chraibimo
Password for 'https://chraibimo@github.com':
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/chraibimo/zabbix-aws-architecture.git/'
ubuntu@ip-10-0-1-156:~$
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
-bash: cd: /home/ubuntu/ec2launch: No such file or directory
Reinitialized existing Git repository in /home/ubuntu/.git/
error: remote origin already exists.
On branch main
nothing to commit, working tree clean
From https://github.com/chraibimo/zabbix-aws-architecture
Current branch main is up to date.
Username for 'https://github.com': chraibimo
Password for 'https://chraibimo@github.com':
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/chraibimo/zabbix-aws-architecture.git/'
ubuntu@ip-10-0-1-156:~$
git init
git remote add origin https://github.com/chraibimo/zabbix-aws-architecture.git
git add .
git commit -m "Initial commit from EC2"
git pull origin main --rebase
git push -u origin main
-bash: cd: /home/ubuntu/ec2launch: No such file or directory
Reinitialized existing Git repository in /home/ubuntu/.git/
error: remote origin already exists.
On branch main
nothing to commit, working tree clean
From https://github.com/chraibimo/zabbix-aws-architecture
Current branch main is up to date.
Username for 'https://github.com': chraibimo
Password for 'https://chraibimo@github.com':
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/chraibimo/zabbix-aws-architecture.git/'
ubuntu@ip-10-0-1-156:~$

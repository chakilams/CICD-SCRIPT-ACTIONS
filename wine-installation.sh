dpkg --add-architecture i386
wget -nc https://dl.winehq.org/wine-builds/winehq.key
apt-key add winehq.key
apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ xenial main'
apt update
apt install -y --install-recommends winehq-stable

mkdir -p /home/AADDS/svc_hermes_prod/sparkparser
cp -R /home/sshuser/exe/ /home/AADDS/svc_hermes_prod/sparkparser/
chown svc_hermes_prod:svc_hermes_prod -R /home/AADDS/svc_hermes_prod/sparkparser/* 
chmod 755 -R /home/AADDS/svc_hermes_prod/sparkparser/exe/ 
ll /home/AADDS/svc_hermes_prod/sparkparser/exe/

mkdir /home/.wine
chown svc_hermes_prod:svc_hermes_prod -R /home/.wine 
chmod 755 -R /home/.wine 

mkdir /home/.local
chown svc_hermes_prod:svc_hermes_prod -R /home/.local 
chmod 755 -R /home/.local

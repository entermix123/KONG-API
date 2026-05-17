Download and extract zip file from this lecture resource

1. For prometheus configuration, use prometheus.yml
2. Put prometheus.yml into some folder (example : C:/prometheus or /usr/home/user/prometheus)
3. Use the docker-script.txt for creating docker containers. Adjust the docker script for prometheus (1st script
4. Change the d:/development/api-management/prometheus.yml (in docker script) into the location where you put prometheus.yml, so for example it become like this :

docker run -d --name prometheus ... -v c:/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml ...

or

docker run -d --name prometheus ... -v /usr/home/user/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml ...

5. Run the script to create docker prometheus & grafana
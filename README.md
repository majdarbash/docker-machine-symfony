# docker-machine-symfony

## Running the command
1. Navigate to the directory where your project is based
2. Copy-paste the below command
```
bash <(curl -s  https://raw.githubusercontent.com/majdarbash/docker-machine-symfony/master/run.sh)
```

# Accessing the container
1. Get inside docker machine
``` docker-machine ssh symfony ```
2. Access container
``` docker exec -e COLUMNS=$COLUMNS -it app bash ```

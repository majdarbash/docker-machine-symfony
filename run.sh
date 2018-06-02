#!/bin/sh

set -o errexit

# @info:    Prints property messages
# @args:    property-message
echoProperties ()
{
  printf "\t\033[0;35m- $1 \033[0m"
}

# @info:    Prints info messages
# @args:    info-message
echoInfo ()
{
  printf "\033[1;34m[INFO] \033[0m$1\n"
}


# @info:    Prints error messages
# @args:    error-message
echoError ()
{
  printf "\033[0;31mFAIL\n\n$1 \033[0m"
}

# @info:    Prints warning messages
# @args:    warning-message
echoWarn ()
{
  printf "\033[0;33m[WARN] $1 \033[0m"
}

# @info:    Prints success messages
# @args:    success-message
echoSuccess ()
{
  printf "\033[0;32m$1 \033[0m"
}

dockerMachineCommandExists()
{
    docker-machine ssh $1 command -v $2 &> /dev/null
}

dockerMachineFileExists()
{
    docker-machine ssh $1 test -e $2 &> /dev/null
}


initMachine()
{

    echoInfo "Initializing docker machine"

    is_machine_created=$(docker-machine ls | grep $1 | wc -l)

    if [ "$is_machine_created" -eq "1" ]; then
        echoInfo "Docker machine already exists"
    else
        echoInfo "Creating docker machine"
        docker-machine create -d virtualbox --virtualbox-hostonly-cidr "172.10.99.1/24" $1
    fi

    is_machine_running=$(docker-machine ls | grep $1 | grep "Running" | wc -l)
     if [ "$is_machine_running" -eq "1" ]; then
        echoInfo "Docker machine is running"
    else
        echoInfo "Starting up docker-machine $1"
        docker-machine start $1
    fi

    is_directory_mounted=$(docker-machine ssh $1 mount | grep $2 | grep nfs | wc -l)
    if [ "$is_directory_mounted" -eq "1" ]; then
        echoInfo "$2 directory is already mounted using NFS"
    else
        echoInfo "Mounting $2 directory"
        docker-machine-nfs $1 --shared-folder=$2
    fi

    ip_address=$(docker-machine ip $1)
    echoInfo "Docker machine has the ip: $ip_address"


    echoSuccess "Machine is running with NFS share\n"
}

applicationStart()
{
    echoInfo "Starting docker containers"

    echoInfo "Getting php docker image"
    docker-machine ssh $1 "docker pull php"

    echoInfo "Starting up the container"
    container_exists=$(docker-machine ssh $1 "docker container ls --format='{{.Names}}' -a | grep app | wc -l")
    if [ "$container_exists" -eq "1" ]; then
        echoInfo "Container exists, skipping creating it"
        echoInfo "Starting docker container"
        docker-machine ssh $1 "docker container start app"
    else
        echoInfo "Container not found, creating it"
        docker-machine ssh $1 "docker run -d -p 80:80 --name='app' -v $PWD:/app --entrypoint='php'  php:7.1-cli -r \"while(true) { echo 'Running'; sleep(1); }\""
    fi

    echoInfo "Downloading installation files"
    docker-machine ssh $1 "docker exec -t app bash -c 'curl https://raw.githubusercontent.com/majdarbash/docker-machine-symfony/master/install_composer.sh --output /tmp/install_composer.sh && chmod a+x /tmp/install_composer.sh'"
    docker-machine ssh $1 "docker exec -t app bash -c 'curl https://raw.githubusercontent.com/majdarbash/docker-machine-symfony/master/install_packages.sh --output /tmp/install_packages.sh && chmod a+x /tmp/install_packages.sh'"

    echoInfo "Installing composer"
    docker-machine ssh $1 "docker exec -t app bash -c '/tmp/install_composer.sh'"
    
    echoInfo "Installing required packages"
    docker-machine ssh $1 "docker exec -t app bash -c '/tmp/install_packages.sh'"

    echoSuccess "All great, application started, enjoy your day;)\n"
}

setDefaultProperties()
{
    current_directory=$PWD
    parent_directory="$(dirname "$PWD")"
    machine_name="symfony"
}

usage(){
    cat <<EOF
Usage: $0

Examples:

  $ ./docker-machine-symfony.sh -f

    > Requires composer and other installations

EOF
    exit 0
}

commandHint()
{
    cat <<EOF
    this was just a hint
EOF
}

parseCli()
{
    [ "$#" -ge 0 ] || usage

    for i in "${@:1}"
    do
        case $i in
            -h|--help|help)
                usage
            ;;
        esac
    done

    echoProperties "CURRENT DIRECTORY: $current_directory"
    echoProperties "PARENT DIRECTORY: $current_directory"
    echoProperties "MACHINE NAME: $machine_name"

}

setDefaultProperties
parseCli "$@"
initMachine $machine_name $parent_directory
applicationStart $machine_name

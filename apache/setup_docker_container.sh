#!/bin/bash
# Description: Docker container (webserver) setup script, that will setup a container with a default folder structure, file permissions, selinux context and a compose file.
# Author: Sanjay kumar Srikakulam
# Changelog:
# 26-05-2017 Init

usage() {
        echo ""
        echo "Usage: $0 <OPTIONS>"
        echo "Required Parameters:"
        echo "-p <path>                 Provide a path to create the container"
        echo "-d <directory_name>       Provide a name for the container directory"
        echo "Optional Parameters:"
        echo "-c <container_name>       Provide a name for the container"
        echo "Example:"
        echo "./setup_docker_container.sh -p <> -d <> -c <>"
        exit 1
}

while getopts ":p:d:c:" i; do
        case "${i}" in
        p)
                path=$OPTARG
        ;;
        d)
                directory_name=$OPTARG
        ;;
        c)
                container_name=$OPTARG
        ;;
        esac
done

if [[ "$path" == "" || "$directory_name" == "" ]] ; then
        usage
fi

if [[ "$container_name" == "" ]] ; then
        container_name=$directory_name
fi

# Creates the default folder structure
if [[ -d "$path" ]] ; then
        mkdir -p $path/$directory_name/{extra-conf.d,apache-log,certs,htdocs}
fi

# Setup the default selinux context exclusively for the above created sub-directories
chcon system_u:object_r:container_share_t:s0 "$path/$directory_name/extra-conf.d"
chcon system_u:object_r:container_share_t:s0 "$path/$directory_name/apache-log"
chcon system_u:object_r:container_share_t:s0 "$path/$directory_name/certs"
chcon system_u:object_r:container_share_t:s0 "$path/$directory_name/htdocs"

# Creates a default compose file with required selinux contexts for "Volumes"
touch "$path/$directory_name/docker-compose.yml" ; chmod +x "$path/$directory_name/docker-compose.yml"

echo "version: '2'
services:
    apache:
        image: docker.io/sanjaysrikakulam/alpine-apache:latest
        restart: unless-stopped
        container_name: $container_name
        hostname: <Please add the hostname name here>
        ports:
            - \"80\"
            - \"443\"
        cap_add:
            - NET_ADMIN
            - NET_RAW
        volumes:
            - ./extra-conf.d:/etc/apache2/extra-conf.d:ro
            - ./htdocs:/var/www/htdocs:Z
            - ./certs:/etc/ssl/apache2:ro
            - ./apache-log:/var/www/logs:Z
        environment:
            SERVER_NAME: <Please add the Server name here>
            REDIRECT_HTTP_TO_HTTPS : \"true\"
            ENABLE_HSTS: \"true\"
            ENABLE_MOD_PROXY: \"true\"
" > $path/$directory_name/docker-compose.yml

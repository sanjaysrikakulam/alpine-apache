# alpine-apache
# What is Apache?

> The Apache HTTP server is a software (or program) that runs in the background under an appropriate operating system, which supports multi-tasking, and provides services to other applications that connect to it, such as client web browsers. The goal of this project is to provide a secure, efficient and extensible server that provides HTTP services in sync with the current HTTP standards.

[http://httpd.apache.org/](http://httpd.apache.org/)

# Why use this image?

* This apache image was built on a light weight operating system, that is alpine linux, with apache and mysql specific packages for any CMS (wordpress, typo3, mediawiki)
* The image is constantly tested with all these CMS and bugs are fixed if any
* Configuration approach is very simple and straight forward using a compose file
* This image comes with a firewall setting, allowing the access to your website only through ports 80 or 443 and all the other ports are blocked

# To get this image

The recommended way to get this Alpine Apache Docker Image is to pull the prebuilt image from the [Docker Hub Registry](https://hub.docker.com/r/sanjaysrikakulam/alpine-apache/).

```bash
$ docker pull docker.io/sanjaysrikakulam/alpine-apache:latest
```
Once you pulled the image, you can use docker-compose to create/start the container

## Docker Compose

```bash
$ docker-compose up -d
```

# Hosting a website

- Use the utility script [setup_docker_container.sh](https://github.com/sanjaysrikakulam/alpine-apache/blob/master/apache/setup_docker_container.sh) to create base setup and configuration

```bash
$ setup_docker_container.sh -p </docker/docker-containers/> -d <alpine-apache> -c <alpine-apache>
```

- This script will create a folder structure, docker-compose.yml file and will change the selinux context of them
```
└── alpine-apache
    ├── apache-log
    ├── certs
    ├── docker-compose.yml
    ├── extra-conf.d
    └── htdocs
```
## Directory setup explanation

- **apache-log:** This is where apache will write its error and ssl_access log
- **certs:** Before starting the container please add in your servers certificate (.crt) and key (.key) files in a specific format [<SERVERNAME-cert.pem>, <SERVERNAME-key.pem>]
- **docker-compose.yml:** This compose file contains default setup and configuration, to provide a basic idea on how you can setup the rest of the environment variables to enable some apache configuration
- **extra-conf.d:** Before starting the container, you can add in any additional apache configuration, if it wasn't already implemented/enabled using the environment variables
- **htdocs:** Add in all your app specific or website specific files to this folder
- **NOTE: All these volumes are bind mounted**

## Accessing your server from the host

To access your web server from your host machine you can manually specify the ports you want to be forwarded from your host to the container by editing this section of the docker-compose.yml file

```yaml
    ports:
      - '8080:80'
      - '443:443'
```

If you can assign every Docker container a valid public IP address, then configure your container with this compose setup

```yaml
version: '2'
services:
    apache:
        image: docker.io/sanjaysrikakulam/alpine-apache:latest
        restart: unless-stopped
        container_name: $container_name
        hostname: <Please add the hostname name here>
        ports:
            - "80"
            - "443"
        cap_add:
            - NET_ADMIN
            - NET_RAW
        volumes:
            - ./extra-conf.d:/etc/apache2/extra-conf.d:ro
            - ./htdocs:/var/www/htdocs:Z
            - ./certs:/etc/ssl/apache2:ro
            - ./apache-log:/var/www/logs:Z
        networks:
            outside:
                ipv4_address: <Please add the ip address for this container here>
        environment:
            SERVER_NAME: <Please add the Server name here>
            REDIRECT_HTTP_TO_HTTPS : "true"
            ENABLE_HSTS: "true"
            ENABLE_MOD_PROXY: "true"
	    
networks:
    outside:
        external:
            name: <docker network name>
```

# Configuration

## Environment variables

When you start the alpine-pache image, you can adjust the configuration of the instance by enabling or disabling one or more environment variable in the docker-compose file

* Add the variable name and value under the environment section
* The possible environment variables can be found in this [docker-compose-template](https://github.com/sanjaysrikakulam/alpine-apache/blob/master/apache/docker-compose-template/docker-compose.yml) file

## SSL Certificates

* As specified earlier, you will have to either provide a self signed certificate and a key file or the one signed by a proper CA. You will have to add them to *certs* directory in a specific format *SERVERNAME-cert.pem* and *SERVERNAME-key.pem*

# Issues

If you encountered a problem running this container, you can file an [issue](https://github.com/sanjaysrikakulam/alpine-apache/issues). For me to provide any form of support, be sure to include the following information in your issue:

- Host OS and version
- Docker version (`docker version`)
- Output of `docker info` and `docker logs <container-name>`

# License

GNU GENERAL PUBLIC LICENSE v2.0

# Possible implementations (environment variable based)

- Adding configuration for ldap/active directory (with access control for groups)
- Adding file explorer (with access control using ldap/active directory)
- Alias configuration (assuming certificates are available for every alias name)
- FCGID configuration (required for some CMS)
- Configuration for restricting the website's access to be available only from certain ip addresses


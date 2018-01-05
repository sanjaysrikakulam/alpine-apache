#!/bin/bash
# Description: Docker entrypoint script to configure the webserver. All ENV variables are set in the "docker-compose.yml" file
# Author: Sanjay kumar Srikakulam

set -euo pipefail

# Variable declarations
tab='   '
confd_path="/etc/apache2/conf.d"


######## Check Functions ########

check_certificate() {
    server_name=$1
    if [ ! -f /etc/ssl/apache2/${server_name}-cert.pem ] && [ ! -f /etc/ssl/apache2/${server_name}-key.pem ]; then
        echo "Either certificate or key for ${server_name} not found, aborting!"
        exit 1
    fi
   
    cert_md5=$(openssl x509 -noout -modulus -in /etc/ssl/apache2/${server_name}-cert.pem | openssl md5 | awk '{print $2}')
    key_md5=$(openssl rsa -noout -modulus -in /etc/ssl/apache2/${server_name}-key.pem | openssl md5 | awk '{print $2}')
    if [[ "$cert_md5" != "$key_md5" ]]; then
        echo "Certificate and key does not match for ${server_name}, aborting!"
        exit 1
    fi
}

######## Check Functions Done ########

######## Configuration Functions ########

# Firewall configuration
configure_firewall() {
    echo "Configuring initial firewall for the container ...."
    
    iptables -N TCP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -P INPUT DROP

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    # Allow new incoming ICMP echo requests (ping)
    iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
    # Attach the TCP chain to the INPUT chain to handle all new incoming connections
    iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
    
    echo "Firewall has been configured successfully!"
}

# Configures/sets up the timezone inside the container
configure_timezone() {
	cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime
	echo "Container timezone set to: Europe/Berlin"
}

# Configures php.ini file for file upload sizes and execution times
configure_php_ini() {
    file_path="/etc/php7/php.ini"
    sed -i s/upload_max_filesize.*/"upload_max_filesize = 1024M"/ $file_path
    sed -i s/max_execution_time.*/"max_execution_time = 240"/ $file_path
    sed -i s/post_max_size.*/"post_max_size = 1024M"/ $file_path
}

# Configures htdocs ownership to apache 
configure_htdocs_ownership() {
	chown -R apache "/var/www/htdocs"
}

# Apache2 configuration
configure_apache() {
    echo "Configuring default Apache configuration for the container ...."
    # Removing all default Apache configuration files
    rm -r ${confd_path}/*.conf &>/dev/null
    
    # Creating httpd.conf with the following configuration
    echo '#Apache HTTPD server configuration file.
ServerTokens Prod
ServerRoot /var/www

Listen 80

LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_core_module modules/mod_authn_core.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule deflate_module modules/mod_deflate.so
LoadModule filter_module modules/mod_filter.so
LoadModule expires_module modules/mod_expires.so
LoadModule reqtimeout_module modules/mod_reqtimeout.so
LoadModule mime_module modules/mod_mime.so
LoadModule mime_magic_module modules/mod_mime_magic.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule logio_module modules/mod_logio.so
LoadModule env_module modules/mod_env.so
LoadModule headers_module modules/mod_headers.so
LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule status_module modules/mod_status.so
LoadModule dir_module modules/mod_dir.so
LoadModule alias_module modules/mod_alias.so
LoadModule socache_memcache_module modules/mod_socache_memcache.so
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
LoadModule unique_id_module modules/mod_unique_id.so
LoadModule authnz_ldap_module modules/mod_authnz_ldap.so
LoadModule ldap_module modules/mod_ldap.so
LoadModule php7_module modules/mod_php7.so
LoadModule ssl_module modules/mod_ssl.so
LoadModule slotmem_shm_module modules/mod_slotmem_shm.so
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule cache_module modules/mod_cache.so

PidFile "/run/httpd.pid"
StartServers             5
MinSpareServers          5
MaxSpareServers         10
MaxRequestWorkers      250
MaxConnectionsPerChild   0

Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
UseCanonicalName Off
AccessFileName .htaccess
HostnameLookups Off
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500

LogLevel warn
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
CustomLog logs/ssl_access.log combined
ErrorLog logs/error.log

User apache
Group apache

TypesConfig /etc/apache2/mime.types
AddType application/x-compress .Z
AddType application/x-gzip .gz .tgz
MIMEMagicFile /etc/apache2/magic

DocumentRoot "/var/www/htdocs"

DirectoryIndex index.php index.html
AddHandler application/x-httpd-php .php
AddHandler application/x-httpd-php-source .phps

<Directory />
    Options FollowSymLinks    
    AllowOverride none
    Require all denied
</Directory>

<Directory /var/www/htdocs>
    Options FollowSymLinks
    AllowOverride none
    Require all granted
</Directory>

<Files ".ht*">
    Require all denied
</Files>

IncludeOptional /etc/apache2/conf.d/*.conf
IncludeOptional /etc/apache2/extra-conf.d/*.conf' > /etc/apache2/httpd.conf

    echo "Apache has been configured successfully for the server ${SERVER_NAME}"
}

# SSL configuration
configure_ssl() {
    echo "Configuring default SSL configuration for HTTPD ...."

    echo '#SSL configuration for HTTPD
Listen 443 https

SSLPassPhraseDialog builtin

SSLSessionCache         "shmcb:/var/cache/mod_ssl/scache(512000)"
SSLSessionCacheTimeout  300
SSLRandomSeed startup file:/dev/urandom 512
SSLRandomSeed connect file:/dev/urandom 512
SSLCryptoDevice builtin

SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite          EECDH:ECDH:EDH:-MD5:-DES:-SHA1:@STRENGTH

SSLHonorCipherOrder on
SSLInsecureRenegotiation off

SSLUseStapling on
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off
SSLStaplingCache "shmcb:/run/apache2/ssl_stapling(32768)"' > ${confd_path}/00-ssl.conf

    echo "SSL has been configured successfully for HTTPD!"
}

# Firewall configurations for HTTPS and HTTP
configure_https_firewall() {
    iptables -A TCP -p tcp --dport 443 -j ACCEPT
    echo "Firewall has been configured to accept HTTPS"
}

configure_http_firewall() {        
    iptables -A TCP -p tcp --dport 80 -j ACCEPT
    echo "Firewall has been configured to accept HTTP!"
}

# Vhost configurations
configure_https_virtualhost() {
    vhost_name=$1

    echo "
<VirtualHost *:443>

        SSLEngine on
        SSLCertificateFile /etc/ssl/apache2/${vhost_name}-cert.pem
        SSLCertificateKeyFile /etc/ssl/apache2/${vhost_name}-key.pem

        ServerName ${vhost_name}

</VirtualHost>" > ${confd_path}/${vhost_name}.https.conf

     echo "HTTPS virtualhost has been configured successfully for ${vhost_name}!"
}

configure_http_virtualhost() {
    vhost_name=$1

    echo "
<VirtualHost *:80>

        ServerName ${vhost_name}

</VirtualHost>" > ${confd_path}/${vhost_name}.http.conf

     echo "HTTP virtualhost has been configured successfully for ${vhost_name}!"
}

configure_alias_forward_to_servername() {
    vhost_name=$1
    protocol=$2
    sed -i "$ i	\\\tRedirect permanent / https://${SERVER_NAME}/" ${confd_path}/${vhost_name}.${protocol}.conf
    echo "${vhost_name} alias forwarding to server name ${SERVER_NAME} is enabled!"
}

########## Access control configurations ##########
#Note: Further configuration for ldap/active directory can be implemented if required to restrict the access to the website

configure_access_control() {
    echo -e "<Directory /var/www/htdocs>" > ${confd_path}/000-access_control.conf

    # Configures Options directive that controls which server features are available in Document root
    if [[ -v ENABLE_OPTIONS_DIRECTIVES && "$ENABLE_OPTIONS_DIRECTIVES" != "null" ]]; then
		echo -e "$tab Options +FollowSymLinks $ENABLE_OPTIONS_DIRECTIVES" >> ${confd_path}/000-access_control.conf
    else
        echo -e "$tab Options +FollowSymLinks" >> ${confd_path}/000-access_control.conf
    fi

    # Configures override via .htaccess files to "all" directives
    if [[ -v ENABLE_ALLOWOVERRIDE && "$ENABLE_ALLOWOVERRIDE" == "true" ]]; then
		echo -e "$tab AllowOverride all" >> ${confd_path}/000-access_control.conf
		echo "Configuration override via .htaccess is enabled for ${SERVER_NAME}"
    else
        echo -e "$tab AllowOverride none" >> ${confd_path}/000-access_control.conf
    fi

    # Override configuration via .htaccess files will be further restricted to specific directives
    if [[ -v ENABLE_ALLOWOVERRIDE_DIRECTIVES && "$ENABLE_ALLOWOVERRIDE_DIRECTIVES" != "null" && "$ENABLE_ALLOWOVERRIDE_DIRECTIVES" != "" ]]; then
        sed -i s/"AllowOverride all"/"AllowOverride $ENABLE_ALLOWOVERRIDE_DIRECTIVES"/ ${confd_path}/000-access_control.conf
    fi

    # Configures AddOutputFilterByType directive, which will allow output compression for the given specific file formats
    if [[ -v ENABLE_ADD_OUTPUT_FILTER_BY_TYPE && "$ENABLE_ADD_OUTPUT_FILTER_BY_TYPE" != "null" && "$ENABLE_ADD_OUTPUT_FILTER_BY_TYPE" != "" ]]; then
		echo -e "$tab AddOutputFilterByType DEFLATE $ENABLE_ADD_OUTPUT_FILTER_BY_TYPE" >> ${confd_path}/000-access_control.conf
    fi
    
    echo -e "$tab Require all granted\n</Directory>" >> ${confd_path}/000-access_control.conf
}

########## Access control configurations done ##########

########## Additional Apache configurations ##########

configure_redirect() {
    sed -i "$ i	\\\tRedirect permanent / https://${SERVER_NAME}/" ${confd_path}/${SERVER_NAME}.http.conf
}

# Creating server status configuration to be used by any monitoring system
configure_server_status() {
    echo "
<Location /server-status >
        SetHandler server-status
        require ip 127.0.0.1
</Location>" > ${confd_path}/01-server_status.conf
    if [[ $? == 0 ]]; then
        echo "Server status configuration has been enabled"      
    else
        echo "Server status configuration has not been properly configured. Aborting!"
        exit 1
    fi
}

########## Additional Apache configurations done ##########

######## Configuration Functions Done! ########

######## Verifying and Enabling the features as required ########

# Abort if both HTTPS and HTTP is disabled
if [[ -v DISABLE_HTTPS && "$DISABLE_HTTPS" == "true" ]] && [[ -v DISABLE_HTTP && "$DISABLE_HTTP" == "true" ]]; then
        echo "Both HTTPS and HTTP have been disabled. Aborting"
        exit 1
fi

# Initializing Apache configuration
configure_timezone
configure_php_ini
configure_apache
configure_htdocs_ownership
configure_ssl
configure_server_status
configure_firewall

# Checks and configures HTTP
if [[ ! -v DISABLE_HTTP || "$DISABLE_HTTP" != "true" ]]; then
    configure_http_virtualhost $SERVER_NAME
    configure_http_firewall
fi

# Checks and configures HTTPS
if [[ ! -v DISABLE_HTTPS || "$DISABLE_HTTPS" != "true" ]]; then
    check_certificate $SERVER_NAME
    configure_https_virtualhost $SERVER_NAME
    configure_https_firewall

    # Configures http to https redirect
    if [[ -v REDIRECT_HTTP_TO_HTTPS && "$REDIRECT_HTTP_TO_HTTPS" == "true" ]]; then
        configure_redirect
    fi

    # Adds HSTS configuration
    if [[ -v ENABLE_HSTS && "$ENABLE_HSTS" == "true" ]]; then
        echo -e "# Use HTTP Strict Transport Security to force client to use secure connections only
        Header always set Strict-Transport-Security 'max-age=31536000'" > ${confd_path}/000-hsts.conf
    fi

    # Configures access control
    configure_access_control
fi

# Enables proxy and http proxy module
if [[ -v ENABLE_MOD_PROXY && "$ENABLE_MOD_PROXY" == "true" ]]; then
    echo "LoadModule proxy_module modules/mod_proxy.so 
    LoadModule proxy_http_module modules/mod_proxy_http.so" > ${confd_path}/00-proxy.conf       
fi
    
# Enables autoindex module
if [[ -v ENABLE_MOD_AUTOINDEX && "$ENABLE_MOD_AUTOINDEX" == "true" ]]; then
    echo "LoadModule autoindex_module modules/mod_autoindex.so" > ${confd_path}/00-autoindex.conf
fi

# Enables negotiation module
if [[ -v ENABLE_MOD_NEGOTIATION && "$ENABLE_MOD_NEGOTIATION" == "true" ]]; then
    echo "LoadModule negotiation_module modules/mod_negotiation.so" > ${confd_path}/00-negotiation.conf
fi

######## Verification and Enabling of the features are done ########

echo "***Container configuration done, starting  $@ ***"

exec "$@"

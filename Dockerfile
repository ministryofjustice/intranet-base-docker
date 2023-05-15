FROM phusion/baseimage:jammy-1.0.1

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Set system locale
ENV LC_ALL="en_GB.UTF-8" \
    LANG="en_GB.UTF-8" \
    LANGUAGE="en_GB.UTF-8"

# PHP version
ARG phpv=8.2
# Node version
ARG nv=18.x
# MariaDB version
ARG mdbv=10.6
# PHP package shortname (ps)
ARG ps=php${phpv}

# Upgrade & install packages
RUN add-apt-repository -y ppa:ondrej/php && \
    add-apt-repository -y ppa:ondrej/nginx && \
    curl -sL https://deb.nodesource.com/setup_${nv} | bash - && \
    apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get install -y \
        ${ps}-cli ${ps}-curl ${ps}-fpm ${ps}-gd ${ps}-mbstring ${ps}-mysql ${ps}-readline ${ps}-xml ${ps}-zip ${ps}-imagick \
        nginx nginx-extras\
        mariadb-client-${mdbv} \
        python3-pip libfuse-dev git nano nodejs build-essential unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /init

# Install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Install yas3fs
RUN pip3 install git+https://github.com/danilop/yas3fs.git

# Copy all required files
COPY conf/ /tmp/conf
COPY init/ /etc/my_init.d/
COPY service/ /etc/service/
COPY build/ /tmp/build

# Configure nginx
RUN mv /tmp/conf/nginx/server.conf /etc/nginx/sites-available/ && \
    mv /tmp/conf/nginx/php-fpm.conf /etc/nginx/ && \
    mkdir /etc/nginx/allow-lists/ && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    echo "# No frontend IP allow-list configured. Come one, come all!" > /etc/nginx/allow-lists/site-wide.conf && \
    echo "# No login IP allow-list configured. Come one, come all!" > /etc/nginx/allow-lists/wp-login.conf && \
    echo "# This file is configured at runtime." > /etc/nginx/real_ip.conf && \
    rm /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/server.conf /etc/nginx/sites-enabled/server.conf && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Configure php-fpm
RUN mv /tmp/conf/php-fpm/php-fpm.conf /etc/php/${phpv}/fpm && \
    mv /tmp/conf/php-fpm/php.ini /etc/php/${phpv}/fpm && \
    mv /tmp/conf/php-fpm/pool.conf /etc/php/${phpv}/fpm/pool.d && \
    rm /etc/php/${phpv}/fpm/pool.d/www.conf

# Configure cron tasks
RUN mv /tmp/conf/cron.d/* /etc/cron.d/

# Configure bash
RUN echo "export TERM=xterm" >> /etc/bash.bashrc && \
    echo "alias wp=\"wp --allow-root\"" > /root/.bash_aliases && \
    sed -i -e 's/@\\h:/@\$\{SERVER_NAME\}:/' /root/.bashrc && \

    # Configure ImageMagick & Cleanup /tmp/conf
    mv /tmp/conf/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml && \
    rm -Rf /tmp/conf

# Configure Services
RUN chmod +x /etc/my_init.d/* && \
    mkdir /etc/service/nginx /etc/service/php-fpm /etc/service/yas3fs && \
    mv /etc/service/nginx.sh /etc/service/nginx/run;     chmod +x /etc/service/nginx/run && \
    mv /etc/service/php-fpm.sh /etc/service/php-fpm/run; chmod +x /etc/service/php-fpm/run && \
    mv /etc/service/yas3fs.sh /etc/service/yas3fs/run;   chmod +x /etc/service/yas3fs/run && \

    # Put a dummy file in /tmp directory to stop yas3fs from deleting /tmp
    # This can be removed once the bug with yas3fs is fix, and the version of yas3fs used in this image is updated
    # Issue: https://github.com/danilop/yas3fs/issues/150
    echo "This file exists to ensure that yas3fs doesn't delete the /tmp directory. For more info see comments in the wordpress-base Dockerfile." > /tmp/keeptmp

# Generate the Pingdom IP address allow-lists
RUN chmod +x /tmp/build/generate-pingdom-allow-list.sh && sleep 1 && \
    /tmp/build/generate-pingdom-allow-list.sh /etc/nginx/allow-lists/pingdom.conf && \
    rm -rf /tmp/build

# Create bedrock directory
RUN mkdir /bedrock

EXPOSE 80

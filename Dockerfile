FROM phusion/baseimage:0.9.15
MAINTAINER Open Knowledge

# set UTF-8 locale
RUN locale-gen en_US.UTF-8 && \
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale

RUN apt-get -qq update

ENV HOME /root
ENV CKAN_HOME /usr/lib/ckan/default
ENV CKAN_CONFIG /etc/ckan/default
ENV CONFIG_FILE ckan.ini
ENV CONFIG_OPTIONS custom_options.ini
ENV CKAN_DATA /var/lib/ckan

# Install required packages
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
        python-minimal \
        python-dev \
        python-virtualenv \
        libevent-dev \
        libpq-dev \
        postfix \
        build-essential \
        git \
        libxml2-dev \
        libxslt1-dev \
        libgeos-c1 \
        supervisor

# Create directories & virtual env for CKAN
RUN virtualenv $CKAN_HOME
RUN mkdir -p $CKAN_CONFIG $CKAN_DATA /var/log/ckan
RUN chown www-data:www-data $CKAN_DATA

# copy CKAN and any extenstions in the source directory
ADD docker/ckan/pip_install_req.sh /usr/local/sbin/pip_install_req

# copy CKAN and any extenstions in the source directory
ADD _src/ $CKAN_HOME/src/
ONBUILD ADD _src/ $CKAN_HOME/src/
# install what we've just copied
RUN pip_install_req
ONBUILD RUN pip_install_req
RUN ln -s $CKAN_HOME/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini
ONBUILD RUN ln -s $CKAN_HOME/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini

# Make config file
RUN $CKAN_HOME/bin/paster make-config ckan ${CKAN_CONFIG}/${CONFIG_FILE}

# Configure postfix
COPY _etc/postfix/main.cf /etc/postfix/main.cf
ONBUILD COPY _etc/postfix/main.cf /etc/postfix/main.cf

# Configure supervisor
COPY _etc/supervisor/conf.d/ /etc/supervisor/conf.d/
ONBUILD COPY _etc/supervisor/conf.d/ /etc/supervisor/conf.d/

# Configure cron
COPY _etc/cron.d/ /etc/cron.d/
ONBUILD COPY _etc/cron.d/ /etc/cron.d/

# Configure runit
ADD docker/ckan/my_init.d/ /etc/my_init.d/
ONBUILD COPY _etc/my_init.d/ /etc/my_init.d/
ADD docker/ckan/svc/ /etc/service/

CMD ["/sbin/my_init"]

VOLUME ["/usr/lib/ckan", "/etc/ckan"]
EXPOSE 80 8800

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

FROM registry.access.redhat.com/ubi9/ubi

LABEL maintainer="GeekWho <geekwho_eth@outlook.com>"
LABEL version="1.0"
LABEL description="A 1Panel Docker Image Base on CentOS stream10"

RUN yum -y update && \
    yum -y install \
    ca-certificates \
    #curl \ # use curl-minimal
    git \
    gnupg2 \
    wget \
    unzip \
    openssh-server \
    sed \
    sudo \
    iproute \
    net-tools \
    which && \
    yum clean all && \
    rm -rf /var/cache/yum /tmp/* /var/tmp/*

# install docker cli
RUN yum install -y yum-utils && \
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    yum install -y docker-ce-cli && \
    yum clean all && \
    rm -rf /var/cache/yum

# set work dir
WORKDIR /1panel

# set docker.sock as Docker out of Docker
VOLUME /var/run/docker.sock

COPY {%OnePanel_Type%}/quick_start.sh /1panel/quick_start.sh
RUN chmod +x /1panel/quick_start.sh

COPY {%OnePanel_Type%}/fix_systemctl_start_cmd.sh /1panel/fix_systemctl_start_cmd.sh
RUN chmod +x /1panel/fix_systemctl_start_cmd.sh

RUN bash /1panel/quick_start.sh v{%OnePanel_Version%}

# use supervisord start 1panel
# Install supervisor
RUN yum update -y && \
    #    yum install -y epel-release && \
    # Error: Unable to find a match: supervisor
    yum install -y python3 python3-pip && \
    pip3 install supervisor && \
    #yum install -y supervisor && \
    yum clean all && \
    rm -rf /var/cache/yum /tmp/* /var/tmp/*

# Copy supervisord configuration
COPY hack/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# remove no use files
RUN rm -rf 1panel-v*-linux-*.tar.gz 1panel-v*-linux-*/

# 指定端口
EXPOSE 80 443

# Run supervisord in exec form
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# pyVer - python versions as 'python' or 'python3' (default: python3)
# branch - user repository branch to clone (default: master, other option: test)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .

ARG tag=1.4-cuda10.1-cudnn7-runtime

# Base image, e.g. tensorflow/tensorflow:1.12.0-py3
#FROM pytorch/pytorch:1.2-cuda10.0-cudnn7-runtime
FROM pytorch/pytorch:${tag}


LABEL maintainer='Silke Donayre'
LABEL version='0.0.0'
# Object detection with pytorch

# python version
ARG pyVer=python3

# What user branch to clone (!)
ARG branch=master

# If to install JupyterLab
ARG jlab=true

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         $pyVer-setuptools \
         $pyVer-pip \
         $pyVer-wheel && \ 
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    if [ "$pyVer" = "python3" ] ; then \
       if [ ! -e /usr/bin/pip ]; then \
          ln -s /usr/bin/pip3 /usr/bin/pip; \
       fi; \
       if [ ! -e /usr/bin/python ]; then \
          ln -s /usr/bin/python3 /usr/bin/python; \
       fi; \
    fi && \
    python --version && \
    pip --version


# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*


# Install DEEPaaS from PyPi
# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --no-cache-dir \
        'deepaas>=1.0.0' \
        flaat && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*


# install it manually due to a bug in the installation of pycocotools
RUN pip install cython==0.29.14


#Run opencv architecture
RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 &&\
	apt-get update &&\
	apt-get  -y install libgtk2.0-dev

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER no

# EXPERIMENTAL: install deep-start script
# N.B.: This repository also contains run_jupyter.sh
# For compatibility, create symlink /srv/.jupyter/run_jupyter.sh
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start && \
    ln -s /srv/.deep-start/run_jupyter.sh /usr/local/bin/run_jupyter && \
    mkdir -p /srv/.jupyter && \
    ln -s /srv/.deep-start/run_jupyter.sh /srv/.jupyter/run_jupyter.sh

# Install JupyterLab
ENV JUPYTER_CONFIG_DIR /srv/.deep-start/
# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash
RUN if [ "$jlab" = true ]; then \
       pip install --no-cache-dir jupyterlab ; \
    else echo "[INFO] Skip JupyterLab installation!"; fi

# Install user app:
RUN git clone -b $branch https://github.com/deephdc/obj_detect_pytorch && \
    cd  obj_detect_pytorch && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..


# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring and Jupyter ports
EXPOSE 6006  8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
CMD ["deepaas-run", "--openwhisk-detect", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]

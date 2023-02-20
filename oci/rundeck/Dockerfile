FROM rundeck/rundeck:4.6.0

# Kubernetes support
USER root
RUN apt-get update && sudo apt-get install -y apt-transport-https gnupg2
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && apt-get install -y \
  kubectl \
  apt-transport-https \
  gnupg2 \
  python3-pip \
  awscli \
  && rm -rf /var/lib/apt/lists/*
RUN pip3 install kubernetes requests==2.22.0
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install aws-iam-authenticator
RUN curl -o aws-iam-authenticator \
  https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator && \
  chmod +x ./aws-iam-authenticator && \
  mv aws-iam-authenticator /usr/local/bin

USER rundeck
ADD --chown=rundeck:root https://github.com/rundeck-plugins/kubernetes/releases/download/2.0.8/kubernetes-plugin-2.0.8.zip ./libext/

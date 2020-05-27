# https://hub.docker.com/r/jenkins/jenkins/tags?page=1
FROM jenkins/jenkins:2.199-alpine

ENV KUBECTL_VERSION=v1.16.0
ENV TERRAFORM_VERSION=0.12.20

USER root

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh gettext make docker ncurses curl openssl jq
#RUN apk add terraform=0.12.20

RUN apk -Uuv add groff less python py-pip
RUN pip install awscli
RUN apk --purge -v del py-pip

# install terraform
# wget https://releases.hashicorp.com/terraform/0.12.20/terraform_0.12.20_linux_amd64.zip && unzip terraform_0.12.20_linux_amd64.zip -d /usr/local/bin && chmod +x /usr/local/bin/terraform
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    chmod +x /usr/local/bin/terraform

# install kubectl
# curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl && kubectl version --client
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl
RUN kubectl version --client

# install aws-iam-authenticator
# curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator && chmod +x ./aws-iam-authenticator && mv aws-iam-authenticator /usr/local/bin
RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator
RUN chmod +x ./aws-iam-authenticator
RUN mv aws-iam-authenticator /usr/local/bin

# install helm
# curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh && helm version
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh
RUN helm version

#install istioctl
# curl -sL https://istio.io/downloadIstioctl | sh - && chmod +x $HOME/.istioctl/bin/istioctl && mv $HOME/.istioctl/bin/istioctl /usr/local/bin/ && istioctl version
RUN curl -sL https://istio.io/downloadIstioctl | sh -
RUN chmod +x $HOME/.istioctl/bin/istioctl
RUN mv $HOME/.istioctl/bin/istioctl /usr/local/bin/
RUN istioctl version

RUN rm /var/cache/apk/*

# Allow the jenkins user to run docker
RUN adduser jenkins docker

# Drop back to the regular jenkins user
USER jenkins

# 1. Disable Jenkins setup Wizard UI. The initial user and password will be supplied by Terraform via ENV vars during infrastructure creation
# 2. Set Java DNS TTL to 60 seconds
# http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/java-dg-jvm-ttl.html
# http://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# https://aws.amazon.com/articles/4035
# https://stackoverflow.com/questions/29579589/whats-the-recommended-way-to-set-networkaddress-cache-ttl-in-elastic-beanstalk
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.DNSMultiCast.disabled=true -Djava.awt.headless=true -Dsun.net.inetaddr.ttl=60 -Duser.timezone=PST -Dorg.jenkinsci.plugins.gitclient.Git.timeOut=60"

# Preinstall plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

# Setup Jenkins initial admin user, security mode (Matrix), and the number of job executors
# Many other Jenkins configurations could be done from the Groovy script
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/

# Configure `Amazon EC2` plugin to start slaves on demand
COPY init-ec2.groovy /usr/share/jenkins/ref/init.groovy.d/

EXPOSE 8080

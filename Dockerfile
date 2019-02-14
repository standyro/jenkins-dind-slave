FROM docker:1.12.0-dind
MAINTAINER Ovi Isai <ovidiu.isai@gmail.com>

ENV JENKINS_HOME /home/jenkins
ENV JENKINS_REMOTNG_VERSION 2.7.1

ENV DOCKER_HOST tcp://0.0.0.0:2375

# Install requirements
RUN apk --update add \
    curl \
    bash \
    git \
    openjdk8-jre \
    sudo \
    openssh

# Add jenkins user
RUN adduser -D -h $JENKINS_HOME -s /bin/sh jenkins jenkins \
    && chmod a+rwx $JENKINS_HOME

# Allow jenkins user to run docker as root
RUN echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/docker" > /etc/sudoers.d/00jenkins \
    && chmod 440 /etc/sudoers.d/00jenkins

# Install Jenkins Remoting agent
RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar http://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/2.52/remoting-2.52.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

USER jenkins
COPY jenkins-slave /usr/local/bin/jenkins-slave

USER root
RUN chmod +x /usr/local/bin/jenkins-slave
RUN chown root:jenkins /usr/local/bin/docker
#RUN chown root:jenkins -R /root
#RUN chmod g+wr -R /root

# INSTALL GO AND DEPS
RUN apk add --no-cache ca-certificates

ENV GOLANG_VERSION 1.7.4
ENV GOLANG_SRC_URL https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz
ENV GOLANG_SRC_SHA256 4c189111e9ba651a2bb3ee868aa881fab36b2f2da3409e80885ca758a6b614cc

# https://golang.org/issue/14851
COPY no-pic.patch /
# https://golang.org/issue/17847
COPY 17847.patch /

RUN set -ex \
	&& apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
		openssl \
		go \
	\
	&& export GOROOT_BOOTSTRAP="$(go env GOROOT)" \
	\
	&& wget -q "$GOLANG_SRC_URL" -O golang.tar.gz \
	&& echo "$GOLANG_SRC_SHA256  golang.tar.gz" | sha256sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz \
	&& cd /usr/local/go/src \
	&& patch -p2 -i /no-pic.patch \
	&& patch -p2 -i /17847.patch \
	&& ./make.bash \
	\
	&& rm -rf /*.patch \
	&& apk del .build-deps

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN go get -u github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cli/docker-credential-ecr-login

RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER jenkins
VOLUME $JENKINS_HOME
WORKDIR $JENKINS_HOME

ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
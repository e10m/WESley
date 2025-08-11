FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    software-properties-common \
    openjdk-11-jdk \
    wget \
    unzip \
    apt-transport-https \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download the cromwell jar and mutect2.wdl file
RUN cd /app && \
    wget https://github.com/broadinstitute/cromwell/releases/download/60/cromwell-60.jar -O /app/cromwell-60.jar && \
    wget https://raw.githubusercontent.com/broadinstitute/gatk/master/scripts/mutect2_wdl/mutect2.wdl -O mutect2.wdl && \
    wget https://github.com/broadinstitute/gatk/releases/download/4.2.0.0/gatk-4.2.0.0.zip -O gatk-4.2.0.0.zip && \
    unzip gatk-4.2.0.0.zip && \
    mv gatk-4.2.0.0/gatk-package-4.2.0.0-local.jar /app/ && \
    rm -rf gatk-4.2.0.0.zip gatk-4.2.0.0/

CMD ["/bin/bash"]
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git g++ cmake autoconf libtool liblzma-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libssl-dev \
    ca-certificates cpp make libltdl-dev wget unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create directory for installation
RUN mkdir -p /opt/MuSE

# Download and install MuSE
WORKDIR /opt/MuSE
RUN wget https://github.com/wwylab/MuSE/raw/refs/heads/master/oldversions/MuSE-1.0.zip && \
    unzip MuSE-1.0.zip && \
    cd MuSE-1.0-rc && \
    make && \
    chmod +x MuSE

# Add MuSE to PATH
ENV PATH="/opt/MuSE/MuSE-1.0-rc:${PATH}"

# Set working directory for when container runs
WORKDIR /data
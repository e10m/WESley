FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git g++ cmake autoconf libtool liblzma-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libssl-dev \
    ca-certificates cpp make libltdl-dev wget unzip \
    libncurses5-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /tmp

# Download samtools-1.10 from GitHub
RUN wget https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2 \
    && tar -xjf samtools-1.10.tar.bz2 \
    && rm samtools-1.10.tar.bz2

# Build and install samtools
WORKDIR /tmp/samtools-1.10
RUN ./configure \
    && make \
    && make install

# Set working directory
WORKDIR /tmp

# Download BWA 0.7.17 from GitHub
RUN wget https://github.com/lh3/bwa/releases/download/v0.7.17/bwa-0.7.17.tar.bz2 \
    && tar -xjf bwa-0.7.17.tar.bz2 \
    && rm bwa-0.7.17.tar.bz2

# Build and install BWA
WORKDIR /tmp/bwa-0.7.17
RUN make
RUN cp bwa /usr/local/bin/

# Clean up
WORKDIR /
RUN rm -rf /tmp/samtools-1.10 && \
rm -rf /tmp/bwa-0.7.17

# Set default command
CMD ["bash"]
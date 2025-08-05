FROM perl:5.30.0

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    build-essential \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libncurses5-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required Perl modules
RUN cpanm --notest \
    List::Util \
    IO::File \
    Getopt::Long \
    File::Basename \
    File::Copy \
    File::Path \
    Archive::Extract \
    Archive::Zip \
    LWP::Simple \
    HTTP::Tiny

WORKDIR /app

# Download and compile htslib (includes tabix and bgzip)
RUN wget https://github.com/samtools/htslib/releases/download/1.10.2/htslib-1.10.2.tar.bz2 && \
    tar -xjf htslib-1.10.2.tar.bz2 && \
    cd htslib-1.10.2 && \
    ./configure --prefix=/app/htslib && \
    make && \
    make install && \
    cd .. && \
    rm -rf htslib-1.10.2 htslib-1.10.2.tar.bz2

# Download and compile samtools 1.10
RUN wget https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2 && \
    tar -xjf samtools-1.10.tar.bz2 && \
    cd samtools-1.10 && \
    ./configure --prefix=/app/samtools && \
    make && \
    make install && \
    cd .. && \
    rm -rf samtools-1.10 samtools-1.10.tar.bz2

# Download and extract vcf2maf
RUN wget https://github.com/mskcc/vcf2maf/archive/refs/tags/v1.6.19.zip && \
    unzip v1.6.19.zip && \
    rm v1.6.19.zip && \
    mv vcf2maf-1.6.19/* .

# Make scripts executable
RUN chmod +x *.pl

# Add all tools to PATH
ENV PATH="/app:/app/samtools/bin:/app/htslib/bin:$PATH"

CMD ["/bin/bash"]
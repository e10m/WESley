FROM ubuntu:20.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up timezone information to avoid tzdata configuration prompts
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Install dependencies for building R from source
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    locales \
    wget \
    build-essential \
    gfortran \
    libreadline-dev \
    libx11-dev \
    libxt-dev \
    libpng-dev \
    libjpeg-dev \
    libcairo2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libpcre2-dev \
    libbz2-dev \
    liblzma-dev \
    libicu-dev \
    zlib1g-dev \
    libnetcdf-dev \
    libhdf5-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Download and install R 4.4.1
# Note: Replace the URL with the correct one for version 4.4.1 when it's available
# Current example is for R 4.3.2 which is available
WORKDIR /tmp
RUN wget https://cran.r-project.org/src/base/R-4/R-4.4.1.tar.gz && \
    tar -xf R-4.4.1.tar.gz && \
    cd R-4.4.1 && \
    ./configure --enable-R-shlib && \
    make && \
    make install && \
    cd .. && \
    rm -rf R-4.4.1 R-4.4.1.tar.gz

# Create R library directory for the default user
RUN mkdir -p /usr/local/lib/R/site-library && \
    chmod -R 777 /usr/local/lib/R/site-library

# Set default CRAN mirror
RUN echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' > /usr/local/lib/R/etc/Rprofile.site

# Install specific version of R packages (optional)
# Install BiocManager
RUN Rscript -e 'install.packages("BiocManager", repos="https://cloud.r-project.org")'

# Set Bioconductor version explicitly (3.19 corresponds to R 4.4.1)
RUN Rscript -e 'BiocManager::install(version = "3.19", ask = FALSE)'

# Install CRAN packages with specific versions using remotes
RUN Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("data.table", version = "1.15.4", repos = "https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("writexl", version = "1.5.0", repos = "https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("purrr", version = "1.0.2", repos = "https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("ggplot2", version = "3.5.1", repos = "https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("readxl", version = "1.4.3", repos = "https://cloud.r-project.org")'
RUN Rscript -e 'remotes::install_version("dplyr", version = "1.1.4", repos = "https://cloud.r-project.org")'

# Install Bioconductor packages with specific versions
# For Bioconductor packages, we use a specific approach to get exact versions
RUN Rscript -e 'BiocManager::install("CNTools", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("genefilter", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("GenomicRanges", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("GenomeInfoDb", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("IRanges", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("S4Vectors", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("BiocGenerics", ask = FALSE)'
RUN Rscript -e 'BiocManager::install("biomaRt", ask = FALSE)'

# Set working directory
WORKDIR /home

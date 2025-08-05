FROM python:3.8.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies including procps for 'ps' command
RUN apt-get update && apt-get install -y \
    wget \
    git \
    unzip \
    procps \
    coreutils \
    util-linux \
    && rm -rf /var/lib/apt/lists/*

# Download and extract oncokb-annotator from v3.0.0 tag
RUN wget https://github.com/oncokb/oncokb-annotator/archive/refs/tags/v3.0.0.zip && \
    unzip v3.0.0.zip && \
    cp oncokb-annotator-3.0.0/*.py /app/ && \
    cp -r oncokb-annotator-3.0.0/requirements /app/ && \
    rm -rf v3.0.0.zip oncokb-annotator-3.0.0

# Install Python dependencies from requirements
RUN pip install --no-cache-dir -r /app/requirements/common.txt && \
    pip install --no-cache-dir -r /app/requirements/pip3.txt

# Make scripts executable
RUN chmod +x /app/*.py

# Set Python path
ENV PYTHONPATH=/app

# Default command
CMD ["/bin/bash"]
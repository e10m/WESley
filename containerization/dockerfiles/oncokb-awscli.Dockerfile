FROM e10m/oncokb:3.0.0

# Install AWS CLI for Secrets Manager access on HealthOmics
RUN pip install --no-cache-dir awscli

FROM ensemblorg/ensembl-vep:release_106.1

RUN curl -O https://ftp.ensembl.org/pub/release-103/variation/indexed_vep_cache/homo_sapiens_vep_103_GRCh38.tar.gz && \
    tar -xzf homo_sapiens_vep_103_GRCh38.tar.gz && \
    rm homo_sapiens_vep_103_GRCh38.tar.gz

RUN mkdir -p /opt/vep/.vep && \
    mv homo_sapiens /opt/vep/.vep/

RUN ls -la /opt/vep/.vep/ && ls -la /opt/vep/.vep/homo_sapiens/

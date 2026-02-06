FROM python:3.10

# install polars, pytest, and xlsxwriter for Excel support
RUN pip3 install polars-lts-cpu==1.33.1 && \
    pip3 install pytest==9.0.2 && \
    pip3 install xlsxwriter && \
    pip3 install fastexcel

# set interactive bash
ENTRYPOINT ["/bin/bash"]

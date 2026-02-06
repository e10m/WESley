FROM python:3.10

# install polars, pytest, and Excel/data processing dependencies
RUN pip3 install polars-lts-cpu==1.33.1 && \
    pip3 install pytest==9.0.2 && \
    pip3 install xlsxwriter && \
    pip3 install fastexcel && \
    pip3 install pyarrow && \
    pip3 install openpyxl

# set interactive bash
ENTRYPOINT ["/bin/bash"]

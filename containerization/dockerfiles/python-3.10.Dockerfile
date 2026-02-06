FROM python:3.10

# install polars
RUN pip3 install polars-lts-cpu==1.33.1 && pip3 install pytest==9.0.2

# set interactive bash
ENTRYPOINT ["/bin/bash"]

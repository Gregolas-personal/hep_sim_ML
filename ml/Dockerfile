FROM python:3.11-slim

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    numpy \
    pandas \
    pyarrow \
    scikit-learn \
    matplotlib \
    awkward \
    uproot \
    vector \
    jupyterlab \
    torch

WORKDIR /workspace
COPY inspect_root.py /workspace/

CMD ["/bin/bash"]

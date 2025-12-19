
# Base image with Miniconda pre-installed
FROM continuumio/miniconda3:latest

LABEL maintainer="akalle1@jhu.edu"
LABEL description="TCGA-BRCA RNA-seq analysis pipeline"

# Set working directory
WORKDIR /workflow

# Install system dependencies
RUN apt-get update && apt-get install -y \
    procps \
    build-essential \
    wget \
    curl \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install mamba (faster than conda)
RUN conda install -n base -c conda-forge mamba -y

# Copy environment files
COPY envs/salmon.yaml /tmp/salmon.yaml
COPY envs/deseq2.yaml /tmp/deseq2.yaml

# Create conda environments from YAML files
RUN mamba env create -f /tmp/salmon.yaml
RUN mamba env create -f /tmp/deseq2.yaml

# Install Snakemake in base environment
RUN mamba install -n base -c conda-forge -c bioconda snakemake=7.32 -y

# Install AWS tools
RUN pip install boto3 awscli

# Clean up
RUN conda clean --all -y

# Set PATH to include conda environments
ENV PATH /opt/conda/envs/salmon_env/bin:/opt/conda/envs/deseq2_env/bin:$PATH

# Default command
CMD ["/bin/bash"]

# Base image with Miniconda pre-installed
FROM continuumio/miniconda3

# Set working directory
WORKDIR /app

# Install basics
RUN apt-get update && apt-get install -y procps build-essential

# Install Snakemake and Salmon via Conda
RUN conda install -c bioconda -c conda-forge \
    snakemake \
    salmon \
    pandas \
    boto3  # python library for AWS

# Default command
CMD ["/bin/bash"]

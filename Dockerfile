# Use an appropriate base image with Anvil and Foundry tools installed
FROM ubuntu:20.04

# Install required dependencies
RUN apt-get update && apt-get install -y \
  curl \
  git \
  build-essential \
  wget \
  unzip

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash

ENV PATH="/root/.foundry/bin:$PATH"

# Install Anvil
RUN foundryup

# Copy entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy .env file
COPY .env /root/.env

# Set the entry point to the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
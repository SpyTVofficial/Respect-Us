# Use Ubuntu as base
FROM ubuntu:22.04

# Set noninteractive mode to avoid tzdata prompt
ENV DEBIAN_FRONTEND=noninteractive

# Add uv path
ENV PATH="/root/.cargo/bin:${PATH}"

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    make \
    python3 \
    python3-venv \
    python3-pip \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package/dependency manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Set workdir inside container
WORKDIR /app

# Copy project files into container
COPY . .

# Run install target from Makefile
RUN make install

# Default command: run both backend and frontend
CMD make run-backend & make run-frontend && wait

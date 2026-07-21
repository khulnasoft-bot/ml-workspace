FROM khulnasoft/build-environment:0.6.6

# Install basics and Python dependencies for build.py
# hadolint ignore=DL3005
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-client \
        python3-pip \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python build dependencies
COPY build_requirements.txt /tmp/build_requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/build_requirements.txt

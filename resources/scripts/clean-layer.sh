
#!/bin/bash
#
# This script should be called at the end of each RUN command
# in the Dockerfiles.
#
# Each RUN command creates a new layer that is stored separately.
# At the end of each command, we should ensure we clean up downloaded
# archives and source files used to produce binary to reduce the size
# of the layer.

# Disable exit on error
set +e
# Show all commands
set -x

echo "Running layer cleanup script..."

# Delete old downloaded archive files
apt-get autoremove -y
# Delete downloaded archive files
apt-get clean
# Delete source files used for building binaries
rm -rf /usr/local/src/*
# Delete cache and temp folders
rm -rf /tmp/* /var/tmp/* /root/.cache/* /var/cache/apt/*
# Fix permissions on tmp directory
chmod 1777 /tmp 2>/dev/null || true
# Remove apt lists
rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/*

# Clean conda
if command -v conda &> /dev/null; then
    # Full Conda Cleanup
    conda clean --all -f -y
    # Remove source cache files
    conda build purge-all
    if [ -d "$CONDA_ROOT" ]; then
        # Cleanup python bytecode files - not needed: https://jcrist.github.io/conda-docker-tips.html
        find "$CONDA_ROOT" -type f -name '*.pyc' -delete
        find "$CONDA_ROOT" -type l -name '*.pyc' -delete
    fi
fi

# Clean npm
if command -v npm &> /dev/null; then
    npm cache clean --force
    rm -rf "$HOME/.npm" "$HOME/.node-gyp"
fi

# Clean yarn
if command -v yarn &> /dev/null; then
    yarn cache clean --all
fi

# Clean pip (handled by rm -rf /root/.cache/* above)

# Always exit without error
exit 0

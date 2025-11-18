FROM us-docker.pkg.dev/gemini-code-dev/gemini-cli/sandbox:0.1.1

# We run everything as root (base image uses root)
USER root

# Workspace where BuildPiper mounts the repo
WORKDIR /bp/workspace

# Copy script
COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

# Use build.sh as entrypoint so all arguments pass through
ENTRYPOINT ["/usr/local/bin/build.sh"]

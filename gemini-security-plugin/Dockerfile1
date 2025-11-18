FROM us-docker.pkg.dev/gemini-code-dev/gemini-cli/sandbox:0.1.1

USER root
WORKDIR /bp/workspace
ARG GEMINI_API_KEY

ENV GEMINI_API_KEY="${GEMINI_API_KEY}"

ENV DOCKER_BUILD_CMD="docker build --no-cache -t gemini-security-plugin ."

ENV DOCKER_RUN_CMD='docker run --rm -it -v $(pwd):/bp/workspace -e GEMINI_API_KEY="$GEMINI_API_KEY" gemini-security-plugin'

# ------------------------------------------------------
# Copy the build script
# ------------------------------------------------------
COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

ENTRYPOINT ["/usr/local/bin/build.sh"]

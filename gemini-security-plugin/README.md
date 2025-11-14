docker build --no-cache -t gemini-security-plugin .
docker run --rm -it   -v $(pwd):/bp/workspace   -e GEMINI_API_KEY=""   gemini-security-plugin


Run these commands

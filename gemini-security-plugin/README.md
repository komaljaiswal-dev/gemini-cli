# 📦 Gemini Security Plugin

A lightweight **Docker-based security scanner** that uses **Google Gemini** to analyze any codebase and provide security insights such as vulnerabilities, misconfigurations, and best practice violations.

This tool allows you to run the scanner inside any CI/CD pipeline or locally on your machine.

---

## 🚀 Features

* 🔍 Scans any codebase mounted into the container
* 🤖 Uses **Gemini API** for AI-powered security analysis
* ⚡ Zero dependencies on the host system
* 🐳 Fully Dockerized – plug and play in CI
* 📑 Custom prompts (e.g., “Show me medium severity vulnerabilities”)

---

## 🛠️ Prerequisites

Before you begin:

* Install **Docker**
* Get a **Gemini API Key** from:
  [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)

---

# 🏗️ Build the Docker Image

Run:

```bash
docker build --no-cache -t gemini-security-plugin .
```

This builds the image using your Dockerfile.

---

# ▶️ Run the Scanner

Run the container by mounting your codebase and providing your Gemini API key:

```bash
docker run --rm -it \
  -v $(pwd):/bp/workspace \
  -e GEMINI_API_KEY="YOUR_API_KEY_HERE" \
  gemini-security-plugin \
  "Show me medium severity vulnerabilities"
```

### 📌 Example Usage

Analyze critical issues:

```bash
docker run --rm -it \
  -v $(pwd):/bp/workspace \
  -e GEMINI_API_KEY="YOUR_API_KEY_HERE" \
  gemini-security-plugin \
  "Show me critical vulnerabilities"
```

Scan for insecure coding patterns:

```bash
docker run --rm -it \
  -v $(pwd):/bp/workspace \
  -e GEMINI_API_KEY="YOUR_API_KEY_HERE" \
  gemini-security-plugin \
  "Identify insecure code patterns and weak authentication flows"
```

List dependency risks:

```bash
docker run --rm -it \
  -v $(pwd):/bp/workspace \
  -e GEMINI_API_KEY="YOUR_API_KEY_HERE" \
  gemini-security-plugin \
  "Find dependency-related vulnerabilities"
```

---

# 📂 Directory Structure

Your project should look like this:

```
gemini-security-plugin/
├── Dockerfile
├── build.sh
├── README.md
└── ...
```

---

# 🔧 Environment Variables

| Variable         | Description                    |
| ---------------- | ------------------------------ |
| `GEMINI_API_KEY` | Your Gemini API key (required) |

---

# ✨ How It Works

1. Your codebase is mounted at `/bp/workspace`
2. The script collects all supported files
3. The prompt is sent to the Gemini model
4. Gemini responds with detailed security analysis
5. Output is printed in the terminal

---

# 💡 Troubleshooting

### ❗ `exec format error`

Ensure your `build.sh` inside the container has:

```
#!/bin/bash
```

And is executable:

```bash
chmod +x build.sh
```

### ❗ API key not working

* Ensure no extra quotes
* Check if the key is regenerated
* Confirm environment variable is set correctly

---

# 📝 License

MIT License

---

# 🤝 Contributing

Pull requests are welcome.











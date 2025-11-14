const http = require("http");
const fs = require("fs");
const url = require("url");
const path = require("path");

// Use environment variables for sensitive data
const API_KEY = process.env.API_KEY || "default_key";

http.createServer(function (req, res) {
    const q = url.parse(req.url, true);

    // Vulnerable file read (directory traversal)
    if (q.query.file) {
        const filePath = "./data/" + q.query.file;
        const content = fs.readFileSync(filePath, "utf-8");
        res.write(content);
        res.end();
        return;
    }

    // No rate-limiting, no input validation
    res.write("Hello World!");
    res.end();
}).listen(8080);

console.log("Server running on port 8080");

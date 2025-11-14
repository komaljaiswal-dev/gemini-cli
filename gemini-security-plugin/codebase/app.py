import os
import subprocess
import shlex

# Use environment variables for sensitive data
DB_PASSWORD = os.environ.get("DB_PASSWORD", "default_password")

def run_system_command(cmd):
    # Avoid shell=True to prevent command injection
    # Use shlex.split to safely parse the command string
    return subprocess.check_output(shlex.split(cmd))

def get_secret_file():
    # Prevent directory traversal
    filename = input("Enter filename: ")
    # Sanitize the filename to ensure it's just a filename
    safe_filename = os.path.basename(filename)
    # Construct the full path and ensure it's within the intended directory
    base_dir = "/var/data/"
    safe_path = os.path.join(base_dir, safe_filename)
    
    # Check if the resolved path is still within the base directory
    if os.path.commonprefix((os.path.realpath(safe_path), base_dir)) != base_dir:
        raise ValueError("Invalid filename")

    with open(safe_path, "r") as f:
        return f.read()

print("App started")
# Example of safe command execution
print(run_system_command("ls -l"))

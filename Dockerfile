# Secrets - never let these into the image. This is the one that matters
# most: app.py calls load_dotenv(), so a local .env with the real
# GEMINI_API_KEY sits at the repo root. Without this line, `COPY . .` in
# the Dockerfile bakes that key directly into the image layer history -
# recoverable even if a later step deletes the file.
.env
.env.*

# Version control - full git history has no reason to be inside a
# runtime image, and can be large.
.git
.gitignore
.gitattributes

# Python environment/cache - your local venv is Windows-specific and
# would be useless (and possibly broken) inside the Linux container;
# pip already reinstalls everything from requirements.txt anyway.
venv/
.venv/
__pycache__/
*.pyc

# The Flutter app is a separate project from this Flask backend - it
# has no reason to be inside the backend's image.
helpline_app/

# Test suite - not needed at runtime.
tests/

# Editor/OS noise
.vscode/
.idea/
.DS_Store
# Harmon Deployment

Use these files to simplify your Harmon deployment. Includes a Docker Compose file and a NixOS module.

# Docker Compose

Deploys everything on localhost with optional environment variables. You can put a reverse proxy on top of this and then set the environment variables appropriately for a production deployment.

# NixOS Module

Includes a reverse proxy and a coturn server, configuring Harmon to use them.

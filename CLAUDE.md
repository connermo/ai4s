# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI4S is a GPU development platform that provides isolated development environments for multiple users through Docker containers. It's a Chinese-language project (GPU开发平台) that combines a Go backend API with a web frontend for container management.

## Architecture

The platform consists of:
- **Backend**: Go web server using Gorilla Mux for routing, MySQL for data persistence
- **Frontend**: Static HTML/CSS/JS templates with Bootstrap UI
- **Container Management**: Docker API integration for creating/managing user development containers
- **User Containers**: Ubuntu-based development environments with VSCode Server, Jupyter Lab, and SSH access
- **Group Management**: Multi-level access control with user groups and shared directories

## Tech Stack

- **Backend**: Go 1.21, Gorilla Mux, JWT authentication, Docker API client
- **Database**: MySQL 8.0 (configurable via DB_DSN environment variable)
- **Frontend**: Vanilla JavaScript, Bootstrap 5, static file serving
- **Containerization**: Docker Compose orchestration
- **User Environments**: Ubuntu with VSCode Server, Jupyter Lab, Python/CUDA support

## Common Commands

### Build and Deploy
```bash
# Build all images (platform and development environment)
./scripts/build.sh

# Start the entire platform
./scripts/start.sh

# Stop all services
./scripts/stop.sh

# Clean up all data (destructive)
./scripts/cleanup.sh
```

### Development Commands
```bash
# Run backend in development mode
cd backend
go mod tidy
go run main.go

# Build backend binary
cd backend
go build -o main .

# Docker Compose operations
docker compose up -d                    # Start services
docker compose logs -f ai4s-platform   # View backend logs
docker compose down                     # Stop services
```

### Container Management
```bash
# View running user containers
docker ps --filter "name=dev-"

# Access user container
docker exec -it dev-username bash

# View container logs
docker logs dev-username
```

## Project Structure

```
ai4s/
├── backend/                 # Go API server
│   ├── main.go             # Application entry point
│   ├── models/             # Database models (User, Container, Group, UserGroup)
│   ├── handlers/           # HTTP handlers (auth, users, containers, groups)
│   ├── services/           # Business logic layer
│   └── database/           # Database connection and migrations
├── frontend/               # Web UI (static files)
│   ├── templates/          # HTML templates (admin login, dashboard)
│   └── static/             # CSS, JS, fonts (Bootstrap-based)
├── docker/                 # Container configurations
│   ├── Dockerfile.dev      # User development environment image
│   └── entrypoint.sh       # Container startup script with group support
├── scripts/                # Deployment and management scripts
├── data/                   # Runtime data directories
│   ├── users/              # User home directories
│   ├── shared-ro/          # Read-only shared data
│   ├── shared-rw/          # Read-write workspace
│   └── groups/             # Group shared directories
└── docker-compose.yml      # Service orchestration
```

## Key Environment Variables

The platform uses extensive environment variable configuration:
- `PORT`: Backend server port (default: 8080)  
- `DB_DSN`: MySQL connection string
- `DEFAULT_PORT_PREFIX`: Starting port for user containers (default: 9000)
- `PORT_STEP`: Port range per user (default: 10)
- `USER_CONTAINER_IMAGE`: Docker image for user environments
- `HOST_*_PATH`: Host filesystem paths for container mounts
- `GROUPS_DATA_PATH`: Platform groups directory path (default: /app/groups)
- `HOST_GROUPS_PATH`: Host groups directory path for container mounting
- `CONTAINER_GROUPS_PATH`: Container groups mount point (default: /groups)

## Port Allocation System

The platform implements a systematic port allocation:
- **Management Interface**: Port 8080
- **User Containers**: 10000-19999 range (10 ports per user)
  - SSH: 10000, 10010, 10020...
  - VSCode: 10001, 10011, 10021...  
  - Jupyter: 10002, 10012, 10022...
  - Additional services: 10003-10009, 10013-10019...

## Database Schema

Uses MySQL with models defined in `backend/models/`:
- **Users**: ID, username, password (bcrypt), email, creation timestamp
- **Containers**: ID, user reference, Docker container ID, port assignments, GPU allocation
- **Groups**: ID, name, description, GID (Linux group ID), creator, timestamps
- **UserGroups**: User-group relationships with roles (member/admin)
- **GIDAllocation**: Tracks allocated GIDs to prevent conflicts (ranges: system 0-999, users 1000-1999, groups 2000+)
- **SystemConfig**: Configuration for GID/UID allocation ranges

## Authentication & Authorization

- JWT-based authentication for API access
- Admin-only routes for user/container management  
- Password change functionality with bcrypt hashing
- CORS enabled for cross-origin requests

## Container Lifecycle

User containers are dynamically created with:
- Ubuntu base image with development tools
- VSCode Server, Jupyter Lab, SSH daemon
- GPU passthrough support (NVIDIA runtime)
- Volume mounts for user data, shared resources, and group directories
- Automatic port assignment and service startup
- Dynamic group membership and permissions via environment variables
- Linux group creation and user assignment for proper file permissions

## Development Notes

- Backend uses Go modules (`go.mod` in backend directory)
- Frontend is served as static files, no build process required
- Database migrations located in `backend/database/migrations/`
- All user-facing text and comments are in Chinese
- Container management leverages Docker API client library
- No package.json files - this is not a Node.js project

## Group Management System

The platform includes a comprehensive group management system:

### API Endpoints
```
# Group Management
GET    /api/groups                     # List groups (filtered by user role)
POST   /api/groups                     # Create group (admin only)
GET    /api/groups/{id}                # Get group details
PUT    /api/groups/{id}                # Update group (group admin/system admin)
DELETE /api/groups/{id}                # Delete group (admin only)

# Group Membership
GET    /api/groups/{id}/members        # List group members
POST   /api/groups/{id}/members        # Add member (group admin)
DELETE /api/groups/{id}/members/{uid}  # Remove member (group admin)
PUT    /api/groups/{id}/members/{uid}  # Update member role (group admin)
GET    /api/groups/{id}/available-users # Get users not in group
GET    /api/users/{uid}/groups         # Get user's groups
```

### Directory Structure
- Groups are stored in `data/groups/{group-name}/`
- Each group directory contains subdirectories: `shared/`, `projects/`, `resources/`
- Container access via `/groups/{group-name}` mount point
- User home directory shortcuts: `~/groups/`, `~/group-{name}`

### Permission Model
- **System Admin**: Full group management, can create/delete groups
- **Group Admin**: Can manage group members and settings
- **Group Member**: Read-write access to group directories
- **Non-member**: No access to group directories

### Security Features
- GID conflict prevention with allocation tracking
- Linux group-based file permissions in containers
- Automatic directory creation with proper ownership
- Group sticky bit for inherited permissions
# AGENTS.md

Work inside the provided Docker environment whenever possible.

Use Docker, Docker Compose or the existing container setup for installing dependencies, running commands, executing tests, debugging and validating changes. Avoid relying on host-machine-specific tools or global installations unless the project explicitly requires it.

Before making changes, inspect the available Docker configuration, such as Dockerfile, docker-compose.yml, compose.yml or project-specific container scripts. Prefer project-defined commands over ad-hoc alternatives.

All tests, linters, formatters and build checks should be executed inside the Docker environment when technically possible.

Do not mention any AI assistant, automation tool or code generation tool in code comments, commit messages, pull request titles, pull request descriptions or documentation unless explicitly required by the repository.

Do not use assistant or tool branding in branch names. Branch names should describe the work directly, for example `feature/docker-healthcheck` or `fix/login-redirect`.

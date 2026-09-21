#!/bin/bash

echo "**🐳 Docker Environment**"
echo
echo "| Component | Version |"
echo "|-----------|----------|"

if docker version >/dev/null 2>&1; then
    CLIENT_VERSION=$(docker version --format '{{.Client.Version}}')
    SERVER_VERSION=$(docker version --format '{{.Server.Version}}')
    ENGINE_PLATFORM=$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
    API_VERSION=$(docker version --format '{{.Client.APIVersion}}')
    echo "| 🔷 Docker Client | \`$CLIENT_VERSION\` |"
    echo "| 🔶 Docker Server | \`$SERVER_VERSION\` (${ENGINE_PLATFORM}) |"
    echo "| 🔌 API Version | \`$API_VERSION\` |"
fi

if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short)
    echo "| 📦 Docker Compose | \`$COMPOSE_VERSION\` |"
fi

if docker buildx version >/dev/null 2>&1; then
    BUILDX_VERSION=$(docker buildx version | head -n1 | cut -d' ' -f2)
    echo "| 🏗️ Docker Buildx | \`$BUILDX_VERSION\` |"
fi

CONTAINERD_VERSION=$(docker version --format '{{range .Server.Components}}{{if eq .Name "containerd"}}{{.Version}}{{end}}{{end}}')
echo "| 🔄 containerd | \`$CONTAINERD_VERSION\` |"

RUNC_VERSION=$(docker version --format '{{range .Server.Components}}{{if eq .Name "runc"}}{{.Version}}{{end}}{{end}}')
echo "| ⚙️ runc | \`$RUNC_VERSION\` |"
echo
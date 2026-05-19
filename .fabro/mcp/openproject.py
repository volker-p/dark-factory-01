#!/usr/bin/env python3
"""OpenProject MCP server — exposes work package tools to Fabro workflow agents."""

import base64
import json
import os
import urllib.error
import urllib.request
from mcp.server.fastmcp import FastMCP

OPENPROJECT_URL = os.environ.get("OPENPROJECT_URL", "https://op.uawg.xyz").rstrip("/")
OPENPROJECT_API_KEY = os.environ.get("OPENPROJECT_API_KEY", "")
DEFAULT_PROJECT_ID = os.environ.get("OPENPROJECT_PROJECT_ID", "7")

mcp = FastMCP("openproject")


def _auth_header() -> dict:
    creds = base64.b64encode(f"apikey:{OPENPROJECT_API_KEY}".encode()).decode()
    return {"Authorization": f"Basic {creds}", "Content-Type": "application/json"}


def _request(method: str, path: str, body: dict | None = None) -> dict:
    url = f"{OPENPROJECT_URL}/api/v3{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=_auth_header(), method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "reason": e.reason, "body": e.read().decode()}


@mcp.tool()
def list_work_packages(project_id: str = DEFAULT_PROJECT_ID, page_size: int = 25) -> str:
    """List work packages for a project. Returns id, subject, status and type for each."""
    data = _request("GET", f"/projects/{project_id}/work_packages?pageSize={page_size}")
    if "error" in data:
        return f"Error: {data}"
    items = []
    for wp in data.get("_embedded", {}).get("elements", []):
        items.append({
            "id": wp["id"],
            "subject": wp["subject"],
            "status": wp.get("_links", {}).get("status", {}).get("title", ""),
            "type": wp.get("_links", {}).get("type", {}).get("title", ""),
            "description": wp.get("description", {}).get("raw", ""),
        })
    return json.dumps(items, indent=2)


@mcp.tool()
def get_work_package(work_package_id: int) -> str:
    """Get full details of a single work package by ID."""
    data = _request("GET", f"/work_packages/{work_package_id}")
    if "error" in data:
        return f"Error: {data}"
    return json.dumps({
        "id": data["id"],
        "subject": data["subject"],
        "description": data.get("description", {}).get("raw", ""),
        "status": data.get("_links", {}).get("status", {}).get("title", ""),
        "type": data.get("_links", {}).get("type", {}).get("title", ""),
        "assignee": data.get("_links", {}).get("assignee", {}).get("title", ""),
        "priority": data.get("_links", {}).get("priority", {}).get("title", ""),
        "createdAt": data.get("createdAt", ""),
        "updatedAt": data.get("updatedAt", ""),
    }, indent=2)


@mcp.tool()
def create_work_package(subject: str, description: str = "", project_id: str = DEFAULT_PROJECT_ID) -> str:
    """Create a new work package (task) in a project."""
    body = {
        "subject": subject,
        "description": {"format": "markdown", "raw": description},
        "_links": {"project": {"href": f"/api/v3/projects/{project_id}"}},
    }
    data = _request("POST", f"/projects/{project_id}/work_packages", body)
    if "error" in data:
        return f"Error: {data}"
    return json.dumps({"id": data["id"], "subject": data["subject"]}, indent=2)


@mcp.tool()
def update_work_package(work_package_id: int, subject: str | None = None,
                        description: str | None = None) -> str:
    """Update the subject or description of an existing work package."""
    current = _request("GET", f"/work_packages/{work_package_id}")
    if "error" in current:
        return f"Error fetching work package: {current}"

    body: dict = {"lockVersion": current["lockVersion"]}
    if subject is not None:
        body["subject"] = subject
    if description is not None:
        body["description"] = {"format": "markdown", "raw": description}

    data = _request("PATCH", f"/work_packages/{work_package_id}", body)
    if "error" in data:
        return f"Error: {data}"
    return json.dumps({"id": data["id"], "subject": data["subject"]}, indent=2)


if __name__ == "__main__":
    transport = os.environ.get("MCP_TRANSPORT", "stdio")
    if transport == "http":
        host = os.environ.get("MCP_HOST", "0.0.0.0")
        port = int(os.environ.get("MCP_PORT", "8090"))
        mcp.run(transport="streamable-http", host=host, port=port, path="/mcp")
    else:
        mcp.run(transport="stdio")

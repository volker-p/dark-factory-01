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

_host = os.environ.get("MCP_HOST", "127.0.0.1")
_port = int(os.environ.get("MCP_PORT", "8090"))
mcp = FastMCP("openproject", host=_host, port=_port, streamable_http_path="/mcp")


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
def get_highest_priority_work_package(project_id: str = DEFAULT_PROJECT_ID) -> str:
    """Return the single highest-priority open work package in the project."""
    import urllib.parse
    filters = urllib.parse.quote('[{"status":{"operator":"o","values":[]}}]')
    sort = urllib.parse.quote('[["priority","desc"],["id","asc"]]')
    data = _request("GET", f"/projects/{project_id}/work_packages?filters={filters}&sortBy={sort}&pageSize=1")
    if "error" in data:
        return f"Error: {data}"
    elements = data.get("_embedded", {}).get("elements", [])
    if not elements:
        return "No open work packages found."
    wp = elements[0]
    return json.dumps({
        "id": wp["id"],
        "subject": wp["subject"],
        "description": wp.get("description", {}).get("raw", ""),
        "priority": wp.get("_links", {}).get("priority", {}).get("title", ""),
        "status": wp.get("_links", {}).get("status", {}).get("title", ""),
        "type": wp.get("_links", {}).get("type", {}).get("title", ""),
    }, indent=2)


@mcp.tool()
def set_work_package_status(work_package_id: int, status_id: int) -> str:
    """Set the status of a work package. Use status_id=12 for Closed."""
    current = _request("GET", f"/work_packages/{work_package_id}")
    if "error" in current:
        return f"Error fetching work package: {current}"
    body = {
        "lockVersion": current["lockVersion"],
        "_links": {"status": {"href": f"/api/v3/statuses/{status_id}"}},
    }
    data = _request("PATCH", f"/work_packages/{work_package_id}", body)
    if "error" in data:
        return f"Error: {data}"
    return json.dumps({
        "id": data["id"],
        "subject": data["subject"],
        "status": data.get("_links", {}).get("status", {}).get("title", ""),
    }, indent=2)


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
    mcp.run(transport="streamable-http" if transport == "http" else "stdio")

# SQL Graph Database

## Overview
This repository contains SQL scripts to create and manage a graph database with vertices and edges. The graph structure is designed to represent players, teams, and games, along with their relationships.

## Database Structure
### Tables:
- **Vertices:** Represents nodes in the graph (players, teams, games).
- **Edges:** Represents relationships between nodes (e.g., "plays_in", "plays_against").

### Types:
- **`vertex_type`:** Enum type defining vertex categories (`player`, `team`, `game`).
- **`edge_type`:** Enum type defining relationship categories (`plays_against`, `shares_team`, `plays_in`, `plays_on`).

## Usage
1. Clone the repository:
   ```bash
git clone https://github.com/zerangmajid/sql-graph-database.git
cd sql-graph-database


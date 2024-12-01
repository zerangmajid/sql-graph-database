DROP TYPE IF EXISTS edge_type CASCADE;

-- Create Vertex Type
CREATE TYPE vertex_type AS ENUM('player', 'team', 'game');

-- Create Vertices Table
CREATE TABLE vertices (
    identifier TEXT,
    type vertex_type,  -- Type of the vertex (player, team, or game)
    properties JSON,  -- JSON object to store additional attributes
    PRIMARY KEY (identifier, type)
);

-- Step 3: Create an edge_type ENUM to define relationships between vertices
CREATE TYPE edge_type AS ENUM(
    'plays_against', -- A player played against another player
    'shares_team', -- Two players are on the same team
    'plays_in', -- A player participated in a game
    'plays_on' -- A player is part of a team
);

-- Step 4: Create a table for edges
-- This table stores relationships (edges) between nodes in the graph
-- Create Edges Table
CREATE TABLE edges (
    subject_identifier TEXT,
    subject_type vertex_type,
    object_identifier TEXT,
    object_type vertex_type,
    edge_type edge_type,
    properties JSON,
    PRIMARY KEY (subject_identifier, subject_type, object_identifier, object_type, edge_type)
);

-- Insert Games Data into the Vertices Table
-- This section populates the vertices table with game data
INSERT INTO vertices
SELECT
    game_id AS identifier,
    'game'::vertex_type AS type,
    json_build_object(
        'pts_home', pts_home,
        'pts_away', pts_away,
        'winning_team', CASE WHEN home_team_wins = 1 THEN home_team_id ELSE visitor_team_id END
    ) AS properties
FROM games;

-- Insert Players Data into the Vertices Table
-- This section aggregates player data and populates the vertices table
WITH players_agg AS (
    SELECT
        player_id AS identifier,
        MAX(player_name) AS player_name,
        COUNT(1) AS number_of_games,
        SUM(pts) AS total_points,
        ARRAY_AGG(DISTINCT team_id) AS teams
    FROM game_details
    GROUP BY player_id
)
INSERT INTO vertices
SELECT
    identifier,
    'player'::vertex_type AS type,
    json_build_object(
        'player_name', player_name,
        'number_of_games', number_of_games,
        'total_points', total_points,
        'teams', teams
    ) AS properties
FROM players_agg;

-- Insert Teams Data into Vertices
WITH teams_deduped AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY team_id) AS row_num
    FROM teams
)
INSERT INTO vertices
SELECT
    team_id AS identifier,
    'team'::vertex_type AS type,
    json_build_object(
        'abbreviation', abbreviation,
        'nickname', nickname,
        'city', city,
        'arena', arena,
        'year_founded', yearfounded
    ) AS properties
FROM teams_deduped
WHERE row_num = 1;

-- Insert 'plays_in' Edges
WITH deduped AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id, game_id) AS row_num
    FROM game_details
)
INSERT INTO edges
SELECT
    player_id AS subject_identifier,
    'player'::vertex_type AS subject_type,
    game_id AS object_identifier,
    'game'::vertex_type AS object_type,
    'plays_in'::edge_type AS edge_type,
    json_build_object(
        'start_position', start_position,
        'pts', pts,
        'team_id', team_id,
        'team_abbreviation', team_abbreviation
    ) AS properties
FROM deduped
WHERE row_num = 1;

-- Insert 'plays_against' and 'shares_team' Edges
WITH deduped AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id, game_id) AS row_num
    FROM game_details
), filtered AS (
    SELECT * FROM deduped WHERE row_num = 1
), aggregated AS (
    SELECT
        f1.player_id AS subject_player_id,
        f2.player_id AS object_player_id,
        CASE
            WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type
            ELSE 'plays_against'::edge_type
        END AS edge_type,
        COUNT(1) AS num_games,
        SUM(f1.pts) AS subject_points,
        SUM(f2.pts) AS object_points
    FROM filtered f1
    JOIN filtered f2
        ON f1.game_id = f2.game_id AND f1.player_id <> f2.player_id
    WHERE f1.player_id > f2.player_id
    GROUP BY f1.player_id, f2.player_id, 
             CASE 
                WHEN f1.team_abbreviation = f2.team_abbreviation THEN 'shares_team'::edge_type
                ELSE 'plays_against'::edge_type
             END
)
INSERT INTO edges
SELECT
    subject_player_id AS subject_identifier,
    'player'::vertex_type AS subject_type,
    object_player_id AS object_identifier,
    'player'::vertex_type AS object_type,
    edge_type,
    json_build_object(
        'num_games', num_games,
        'subject_points', subject_points,
        'object_points', object_points
    )
FROM aggregated;

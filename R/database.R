#' Database Functions for Persistent Chat History
#'
#' @description
#' Manages SQLite database for storing chat sessions and messages
#'
#' @keywords internal

#' Get database path
#' @return Path to SQLite database file
get_db_path <- function() {
  # Store in user's home directory under .rflow
  db_dir <- file.path(Sys.getenv("HOME"), ".rflow")
  if (!dir.exists(db_dir)) {
    dir.create(db_dir, recursive = TRUE)
  }
  file.path(db_dir, "chat_history.sqlite")
}

#' Initialize database
#' @return Database connection
#' @keywords internal
init_database <- function() {
  db_path <- get_db_path()
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Create sessions table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS sessions (
      session_id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      title TEXT,
      working_dir TEXT,
      metadata TEXT
    )
  ")

  # Create messages table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS messages (
      message_id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      tool_calls TEXT,
      tool_results TEXT,
      FOREIGN KEY (session_id) REFERENCES sessions(session_id)
    )
  ")

  # Create indexes for performance
  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_messages_session
    ON messages(session_id, timestamp)
  ")

  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_sessions_updated
    ON sessions(updated_at DESC)
  ")

  con
}

#' Create new session
#' @param working_dir Current working directory
#' @return Session ID
#' @keywords internal
create_session <- function(working_dir = getwd()) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  session_id <- generate_session_id()
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  DBI::dbExecute(con, "
    INSERT INTO sessions (session_id, created_at, updated_at, working_dir)
    VALUES (?, ?, ?, ?)
  ", params = list(session_id, timestamp, timestamp, working_dir))

  session_id
}

#' Generate unique session ID
#' @keywords internal
generate_session_id <- function() {
  paste0("session_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
         substr(digest::digest(Sys.time()), 1, 8))
}

#' Save message to database
#' @param session_id Session ID
#' @param role Message role (user/assistant)
#' @param content Message content
#' @param tool_calls Optional tool calls (as JSON string)
#' @param tool_results Optional tool results (as JSON string)
#' @keywords internal
save_message <- function(session_id, role, content,
                        tool_calls = NULL, tool_results = NULL) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Convert tool data to JSON strings
  tool_calls_json <- if (!is.null(tool_calls)) {
    jsonlite::toJSON(tool_calls, auto_unbox = TRUE)
  } else NULL

  tool_results_json <- if (!is.null(tool_results)) {
    jsonlite::toJSON(tool_results, auto_unbox = TRUE)
  } else NULL

  DBI::dbExecute(con, "
    INSERT INTO messages (session_id, role, content, timestamp, tool_calls, tool_results)
    VALUES (?, ?, ?, ?, ?, ?)
  ", params = list(session_id, role, content, timestamp, tool_calls_json, tool_results_json))

  # Update session timestamp
  DBI::dbExecute(con, "
    UPDATE sessions SET updated_at = ? WHERE session_id = ?
  ", params = list(timestamp, session_id))

  invisible(NULL)
}

#' Load session messages
#' @param session_id Session ID
#' @return Data frame of messages
#' @keywords internal
load_session_messages <- function(session_id) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  messages <- DBI::dbGetQuery(con, "
    SELECT message_id, role, content, timestamp, tool_calls, tool_results
    FROM messages
    WHERE session_id = ?
    ORDER BY timestamp ASC
  ", params = list(session_id))

  # Parse JSON fields
  if (nrow(messages) > 0) {
    messages$tool_calls <- lapply(messages$tool_calls, function(x) {
      if (is.na(x) || is.null(x)) return(NULL)
      jsonlite::fromJSON(x)
    })

    messages$tool_results <- lapply(messages$tool_results, function(x) {
      if (is.na(x) || is.null(x)) return(NULL)
      jsonlite::fromJSON(x)
    })
  }

  messages
}

#' Get all sessions
#' @param limit Maximum number of sessions to return
#' @return Data frame of sessions
#' @keywords internal
get_sessions <- function(limit = 50) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  sessions <- DBI::dbGetQuery(con, "
    SELECT
      s.session_id,
      s.created_at,
      s.updated_at,
      s.title,
      s.working_dir,
      COUNT(m.message_id) as message_count
    FROM sessions s
    LEFT JOIN messages m ON s.session_id = m.session_id
    GROUP BY s.session_id
    ORDER BY s.updated_at DESC
    LIMIT ?
  ", params = list(limit))

  # Generate titles for sessions without one
  if (nrow(sessions) > 0) {
    sessions$title <- ifelse(
      is.na(sessions$title) | sessions$title == "",
      paste0("Session ", format(as.POSIXct(sessions$created_at), "%b %d, %H:%M")),
      sessions$title
    )
  }

  sessions
}

#' Update session title
#' @param session_id Session ID
#' @param title New title
#' @keywords internal
update_session_title <- function(session_id, title) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(con, "
    UPDATE sessions SET title = ? WHERE session_id = ?
  ", params = list(title, session_id))

  invisible(NULL)
}

#' Delete session
#' @param session_id Session ID
#' @keywords internal
delete_session <- function(session_id) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  # Delete messages first (foreign key constraint)
  DBI::dbExecute(con, "
    DELETE FROM messages WHERE session_id = ?
  ", params = list(session_id))

  # Delete session
  DBI::dbExecute(con, "
    DELETE FROM sessions WHERE session_id = ?
  ", params = list(session_id))

  invisible(NULL)
}

#' Export session to JSON
#' @param session_id Session ID
#' @param output_file Output file path
#' @keywords internal
export_session <- function(session_id, output_file) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  # Get session info
  session <- DBI::dbGetQuery(con, "
    SELECT * FROM sessions WHERE session_id = ?
  ", params = list(session_id))

  # Get messages
  messages <- load_session_messages(session_id)

  # Combine into export structure
  export_data <- list(
    session = session,
    messages = messages,
    exported_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    rflow_version = utils::packageVersion("Rflow")
  )

  # Write to file
  jsonlite::write_json(export_data, output_file, pretty = TRUE, auto_unbox = TRUE)

  invisible(output_file)
}

#' Import session from JSON
#' @param input_file Input file path
#' @return Session ID
#' @keywords internal
import_session <- function(input_file) {
  # Read JSON
  import_data <- jsonlite::read_json(input_file, simplifyVector = TRUE)

  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  # Generate new session ID
  new_session_id <- generate_session_id()

  # Insert session
  session <- import_data$session
  DBI::dbExecute(con, "
    INSERT INTO sessions (session_id, created_at, updated_at, title, working_dir)
    VALUES (?, ?, ?, ?, ?)
  ", params = list(
    new_session_id,
    session$created_at,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    paste0("[IMPORTED] ", session$title),
    session$working_dir
  ))

  # Insert messages
  messages <- import_data$messages
  if (nrow(messages) > 0) {
    for (i in 1:nrow(messages)) {
      msg <- messages[i, ]
      save_message(
        new_session_id,
        msg$role,
        msg$content,
        msg$tool_calls[[1]],
        msg$tool_results[[1]]
      )
    }
  }

  new_session_id
}

#' Clear old sessions
#' @param days_to_keep Number of days to keep sessions
#' @keywords internal
clear_old_sessions <- function(days_to_keep = 90) {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  cutoff_date <- format(Sys.time() - (days_to_keep * 24 * 60 * 60), "%Y-%m-%d %H:%M:%S")

  # Get sessions to delete
  old_sessions <- DBI::dbGetQuery(con, "
    SELECT session_id FROM sessions WHERE updated_at < ?
  ", params = list(cutoff_date))

  if (nrow(old_sessions) > 0) {
    # Delete messages
    DBI::dbExecute(con, "
      DELETE FROM messages WHERE session_id IN (
        SELECT session_id FROM sessions WHERE updated_at < ?
      )
    ", params = list(cutoff_date))

    # Delete sessions
    DBI::dbExecute(con, "
      DELETE FROM sessions WHERE updated_at < ?
    ", params = list(cutoff_date))

    cli::cli_alert_success("Deleted {nrow(old_sessions)} old session(s)")
  } else {
    cli::cli_alert_info("No old sessions to delete")
  }

  invisible(nrow(old_sessions))
}

#' Get database statistics
#' @keywords internal
get_db_stats <- function() {
  con <- init_database()
  on.exit(DBI::dbDisconnect(con))

  stats <- list(
    total_sessions = DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM sessions")$count,
    total_messages = DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM messages")$count,
    db_size_mb = round(file.size(get_db_path()) / 1024^2, 2),
    db_path = get_db_path()
  )

  stats
}

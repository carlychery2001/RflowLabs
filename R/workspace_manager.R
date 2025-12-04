#' Workspace Manager for Rflow
#' 
#' Tracks the user's current working folder and open files
#' so the AI has full context of where they're working

# Environment to store workspace state
.workspace_env <- new.env(parent = emptyenv())
.workspace_env$current_folder <- NULL
.workspace_env$open_files <- list()
.workspace_env$recent_files <- list()
.workspace_env$project_root <- NULL

#' Set the current working folder for Rflow
#' 
#' @param folder_path Path to the folder
#' @export
open_folder <- function(folder_path = NULL) {
  if (is.null(folder_path)) {
    # Open folder picker dialog
    if (rstudioapi::isAvailable()) {
      folder_path <- rstudioapi::selectDirectory(
        caption = "Select Working Folder",
        label = "Open"
      )
    } else {
      folder_path <- readline("Enter folder path: ")
    }
  }
  
  if (is.null(folder_path) || !dir.exists(folder_path)) {
    cli::cli_alert_danger("Folder not found: {folder_path}")
    return(invisible(NULL))
  }
  
  # Normalize path
  folder_path <- normalizePath(folder_path, winslash = "/")
  
  .workspace_env$current_folder <- folder_path
  .workspace_env$project_root <- folder_path
  
  # Scan folder structure
  folder_info <- scan_folder(folder_path)
  .workspace_env$folder_structure <- folder_info
  
  cli::cli_alert_success("Opened folder: {folder_path}")
  cli::cli_alert_info("Found {folder_info$file_count} files, {folder_info$folder_count} subfolders")
  
  # Show summary
  if (length(folder_info$r_files) > 0) {
    cli::cli_alert_info("R files: {length(folder_info$r_files)}")
  }
  if (length(folder_info$data_files) > 0) {
    cli::cli_alert_info("Data files: {length(folder_info$data_files)}")
  }
  
  invisible(folder_path)
}

#' Open a file and track it
#' 
#' @param file_path Path to the file
#' @export
open_file <- function(file_path = NULL) {
  if (is.null(file_path)) {
    # Open file picker dialog
    if (rstudioapi::isAvailable()) {
      file_path <- rstudioapi::selectFile(
        caption = "Select File to Open",
        filter = "All Files (*.*)"
      )
    } else {
      file_path <- readline("Enter file path: ")
    }
  }
  
  if (is.null(file_path) || !file.exists(file_path)) {
    cli::cli_alert_danger("File not found: {file_path}")
    return(invisible(NULL))
  }
  
  # Normalize path
  file_path <- normalizePath(file_path, winslash = "/")
  
  # Add to open files list
  file_info <- list(
    path = file_path,
    name = basename(file_path),
    ext = tolower(tools::file_ext(file_path)),
    size = file.info(file_path)$size,
    opened_at = Sys.time()
  )
  
  .workspace_env$open_files[[file_path]] <- file_info
  
  # Add to recent files
  .workspace_env$recent_files <- c(
    list(file_info),
    head(.workspace_env$recent_files, 9)  # Keep last 10
  )
  
  # Open in RStudio if available
  if (rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(file_path)
  }
  
  cli::cli_alert_success("Opened file: {basename(file_path)}")
  
  invisible(file_path)
}

#' Close a tracked file
#' 
#' @param file_path Path to the file
#' @export
close_file <- function(file_path) {
  file_path <- normalizePath(file_path, winslash = "/", mustWork = FALSE)
  
  if (file_path %in% names(.workspace_env$open_files)) {
    .workspace_env$open_files[[file_path]] <- NULL
    cli::cli_alert_info("Closed file: {basename(file_path)}")
  }
  
  invisible(NULL)
}

#' Get current workspace context for AI
#' 
#' @return List with workspace information
#' @export
get_workspace_context <- function() {
  context <- list(
    current_folder = .workspace_env$current_folder,
    project_root = .workspace_env$project_root,
    open_files = names(.workspace_env$open_files),
    open_file_details = .workspace_env$open_files,
    recent_files = lapply(.workspace_env$recent_files, function(f) f$path),
    folder_structure = .workspace_env$folder_structure,
    working_directory = getwd()
  )
  
  # Get active document from RStudio
  if (rstudioapi::isAvailable()) {
    tryCatch({
      active_doc <- rstudioapi::getActiveDocumentContext()
      if (!is.null(active_doc$path) && nchar(active_doc$path) > 0) {
        context$active_file <- active_doc$path
        context$active_file_content <- active_doc$contents
        context$cursor_position <- active_doc$selection[[1]]$range
      }
    }, error = function(e) NULL)
  }
  
  return(context)
}

#' Get workspace summary as text for AI prompt
#' 
#' @return Character string with workspace summary
#' @export
get_workspace_summary <- function() {
  ctx <- get_workspace_context()
  
  lines <- character()
  
  lines <- c(lines, "=== WORKSPACE CONTEXT ===")

  if (!is.null(ctx$current_folder)) {
    lines <- c(lines, paste0("[FOLDER] Working Folder: ", ctx$current_folder))
  }

  if (!is.null(ctx$active_file)) {
    lines <- c(lines, paste0("[FILE] Active File: ", ctx$active_file))
  }

  if (length(ctx$open_files) > 0) {
    lines <- c(lines, paste0("[DIR] Open Files (", length(ctx$open_files), "):"))
    for (f in ctx$open_files) {
      lines <- c(lines, paste0("   - ", basename(f)))
    }
  }

  if (!is.null(ctx$folder_structure)) {
    fs <- ctx$folder_structure
    lines <- c(lines, paste0("[VIEW] Folder Contents: ", fs$file_count, " files, ", fs$folder_count, " folders"))
    
    if (length(fs$r_files) > 0) {
      lines <- c(lines, paste0("   R files: ", paste(head(basename(fs$r_files), 5), collapse = ", "),
                               if(length(fs$r_files) > 5) "..." else ""))
    }
    if (length(fs$data_files) > 0) {
      lines <- c(lines, paste0("   Data files: ", paste(head(basename(fs$data_files), 5), collapse = ", "),
                               if(length(fs$data_files) > 5) "..." else ""))
    }
  }
  
  lines <- c(lines, "=========================")
  
  paste(lines, collapse = "\n")
}

#' Scan folder structure
#' 
#' @param folder_path Path to scan
#' @param max_depth Maximum depth to scan
#' @return List with folder information
#' @keywords internal
scan_folder <- function(folder_path, max_depth = 3) {
  all_files <- list.files(folder_path, recursive = TRUE, full.names = TRUE)
  all_dirs <- list.dirs(folder_path, recursive = TRUE, full.names = TRUE)
  
  # Categorize files
  extensions <- tolower(tools::file_ext(all_files))
  
  r_files <- all_files[extensions %in% c("r", "rmd", "rproj", "rdata", "rds")]
  data_files <- all_files[extensions %in% c("csv", "xlsx", "xls", "json", "xml", "parquet", "feather", "tsv")]
  doc_files <- all_files[extensions %in% c("pdf", "docx", "doc", "txt", "md", "html")]
  image_files <- all_files[extensions %in% c("png", "jpg", "jpeg", "gif", "svg", "bmp")]
  
  list(
    path = folder_path,
    file_count = length(all_files),
    folder_count = length(all_dirs) - 1,  # Exclude root
    r_files = r_files,
    data_files = data_files,
    doc_files = doc_files,
    image_files = image_files,
    all_files = all_files,
    scanned_at = Sys.time()
  )
}

#' Show current workspace status
#' 
#' @export
workspace_status <- function() {
  ctx <- get_workspace_context()
  
  cli::cli_h2("Rflow Workspace")
  
  if (!is.null(ctx$current_folder)) {
    cli::cli_alert_success("Folder: {ctx$current_folder}")
  } else {
    cli::cli_alert_warning("No folder opened. Use open_folder() to set one.")
  }
  
  if (!is.null(ctx$active_file)) {
    cli::cli_alert_info("Active file: {basename(ctx$active_file)}")
  }
  
  if (length(ctx$open_files) > 0) {
    cli::cli_alert_info("Open files: {length(ctx$open_files)}")
    for (f in ctx$open_files) {
      cli::cli_li("{basename(f)}")
    }
  }
  
  invisible(ctx)
}

#' Clear workspace tracking
#' 
#' @export
clear_workspace <- function() {
  .workspace_env$current_folder <- NULL
  .workspace_env$open_files <- list()
  .workspace_env$recent_files <- list()
  .workspace_env$project_root <- NULL
  .workspace_env$folder_structure <- NULL
  
  cli::cli_alert_success("Workspace cleared")
  invisible(NULL)
}

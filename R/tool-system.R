#' System command execution tools
#' Allows the AI to navigate the file system, create folders, delete files, etc.

#' Execute system commands
tool_run_command <- function() {
  ellmer::tool(
    function(command, working_dir = NULL, `_intent` = NULL) {
      tryCatch({
        # Set working directory if specified
        if (!is.null(working_dir) && dir.exists(working_dir)) {
          old_wd <- getwd()
          on.exit(setwd(old_wd))
          setwd(working_dir)
        }
        
        # Execute command and capture output
        output <- system(command, intern = TRUE, show.output.on.console = FALSE)
        
        ellmer::ContentToolResult(
          value = paste(output, collapse = "\n"),
          extra = list(
            display = list(
              markdown = paste0("**Command executed:** `", command, "`\n\n```\n", 
                              paste(output, collapse = "\n"), "\n```"),
              title = "System Command",
              show_request = FALSE
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error executing command: ", conditionMessage(e))
        )
      })
    },
    name = "run_command",
    description = "Execute a system command (cmd on Windows, bash on Unix). Use for file operations, navigation, etc.",
    arguments = list(
      command = ellmer::type_string("The command to execute (e.g., 'dir', 'mkdir newfolder', 'del file.txt')"),
      working_dir = ellmer::type_string("Working directory for the command (optional)", required = FALSE),
      `_intent` = ellmer::type_string("Why you're running this command", required = FALSE)
    ),
    convert = FALSE
  )
}

#' Create directory
tool_create_directory <- function() {
  ellmer::tool(
    function(path, recursive = TRUE, `_intent` = NULL) {
      tryCatch({
        dir.create(path, showWarnings = FALSE, recursive = recursive)
        
        ellmer::ContentToolResult(
          value = paste0("Directory created: ", path),
          extra = list(
            display = list(
              markdown = paste0("[FOLDER] **Created directory:** `", path, "`"),
              title = "Directory Created",
              show_request = FALSE
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error creating directory: ", conditionMessage(e))
        )
      })
    },
    name = "create_directory",
    description = "Create a new directory/folder. Creates parent directories if needed.",
    arguments = list(
      path = ellmer::type_string("Path to the directory to create"),
      recursive = ellmer::type_boolean("Create parent directories if needed (default: TRUE)", required = FALSE),
      `_intent` = ellmer::type_string("Why you're creating this directory", required = FALSE)
    ),
    convert = FALSE
  )
}

#' Delete file or directory
tool_delete_path <- function() {
  ellmer::tool(
    function(path, recursive = FALSE, `_intent` = NULL) {
      tryCatch({
        if (file.exists(path)) {
          unlink(path, recursive = recursive)
          
          ellmer::ContentToolResult(
            value = paste0("Deleted: ", path),
            extra = list(
              display = list(
                markdown = paste0("[DELETE] **Deleted:** `", path, "`"),
                title = "File/Directory Deleted",
                show_request = FALSE
              )
            )
          )
        } else {
          ellmer::ContentToolResult(
            error = paste0("Path does not exist: ", path)
          )
        }
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error deleting: ", conditionMessage(e))
        )
      })
    },
    name = "delete_path",
    description = "Delete a file or directory. Use recursive=TRUE to delete directories with contents.",
    arguments = list(
      path = ellmer::type_string("Path to the file or directory to delete"),
      recursive = ellmer::type_boolean("Delete directory and all contents (default: FALSE)", required = FALSE),
      `_intent` = ellmer::type_string("Why you're deleting this", required = FALSE)
    ),
    convert = FALSE
  )
}

#' Copy file or directory
tool_copy_path <- function() {
  ellmer::tool(
    function(from, to, overwrite = FALSE, `_intent` = NULL) {
      tryCatch({
        if (file.info(from)$isdir) {
          # Copy directory
          dir.create(dirname(to), showWarnings = FALSE, recursive = TRUE)
          file.copy(from, to, overwrite = overwrite, recursive = TRUE)
        } else {
          # Copy file
          dir.create(dirname(to), showWarnings = FALSE, recursive = TRUE)
          file.copy(from, to, overwrite = overwrite)
        }
        
        ellmer::ContentToolResult(
          value = paste0("Copied from ", from, " to ", to),
          extra = list(
            display = list(
              markdown = paste0("[COPY] **Copied:** `", from, "` -> `", to, "`"),
              title = "File/Directory Copied",
              show_request = FALSE
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error copying: ", conditionMessage(e))
        )
      })
    },
    name = "copy_path",
    description = "Copy a file or directory to a new location.",
    arguments = list(
      from = ellmer::type_string("Source path to copy from"),
      to = ellmer::type_string("Destination path to copy to"),
      overwrite = ellmer::type_boolean("Overwrite if destination exists (default: FALSE)", required = FALSE),
      `_intent` = ellmer::type_string("Why you're copying this", required = FALSE)
    ),
    convert = FALSE
  )
}

#' Move/rename file or directory
tool_move_path <- function() {
  ellmer::tool(
    function(from, to, `_intent` = NULL) {
      tryCatch({
        dir.create(dirname(to), showWarnings = FALSE, recursive = TRUE)
        file.rename(from, to)
        
        ellmer::ContentToolResult(
          value = paste0("Moved from ", from, " to ", to),
          extra = list(
            display = list(
              markdown = paste0("[MOVE] **Moved:** `", from, "` -> `", to, "`"),
              title = "File/Directory Moved",
              show_request = FALSE
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error moving: ", conditionMessage(e))
        )
      })
    },
    name = "move_path",
    description = "Move or rename a file or directory.",
    arguments = list(
      from = ellmer::type_string("Source path to move from"),
      to = ellmer::type_string("Destination path to move to"),
      `_intent` = ellmer::type_string("Why you're moving this", required = FALSE)
    ),
    convert = FALSE
  )
}

#' List directory contents
tool_list_directory <- function() {
  ellmer::tool(
    function(path = ".", pattern = NULL, recursive = FALSE, `_intent` = NULL) {
      tryCatch({
        files <- list.files(path, pattern = pattern, full.names = TRUE, 
                           recursive = recursive, include.dirs = TRUE)
        
        # Get file info
        info <- file.info(files)
        info$path <- files
        info$name <- basename(files)
        info$type <- ifelse(info$isdir, "DIR", "FILE")
        
        # Format output
        output <- data.frame(
          Type = info$type,
          Name = info$name,
          Size = ifelse(info$isdir, "", format(info$size, big.mark = ",")),
          Modified = format(info$mtime, "%Y-%m-%d %H:%M")
        )
        
        result_text <- paste(
          capture.output(print(output, row.names = FALSE)),
          collapse = "\n"
        )
        
        ellmer::ContentToolResult(
          value = result_text,
          extra = list(
            display = list(
              markdown = paste0("[DIR] **Directory:** `", path, "`\n\n```\n", result_text, "\n```"),
              title = paste("Contents of", basename(path)),
              show_request = FALSE
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          error = paste0("Error listing directory: ", conditionMessage(e))
        )
      })
    },
    name = "list_directory",
    description = "List contents of a directory with file information.",
    arguments = list(
      path = ellmer::type_string("Directory path to list (default: current directory)", required = FALSE),
      pattern = ellmer::type_string("File pattern to filter (e.g., '*.R', '*.csv')", required = FALSE),
      recursive = ellmer::type_boolean("List subdirectories recursively (default: FALSE)", required = FALSE),
      `_intent` = ellmer::type_string("Why you're listing this directory", required = FALSE)
    ),
    convert = FALSE
  )
}

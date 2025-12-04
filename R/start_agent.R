#' Start Rflow AI Agent
#'
#' @description
#' Launches an AI coding agent in RStudio. The agent runs as a background job
#' and displays a chat interface in the viewer pane or browser. It can interact with your
#' files, R session, and execute code.
#'
#' Requires Anthropic API key set in environment variable ANTHROPIC_API_KEY.
#'
#' @param api_key Deprecated - use ANTHROPIC_API_KEY environment variable instead.
#' @param client An [ellmer::Chat] client to power the agent.
#'   If NULL, will auto-configure Claude Sonnet.
#' @param launch_in Where to open Rflow: "viewer" (default) or "browser".
#'   Use "browser" if you have maps or other content in the viewer.
#' @param ... Currently ignored.
#' @param host A character string specifying the host. Defaults to "127.0.0.1".
#'
#' @return Launches a Shiny application as a background job.
#' @export
start_rflow <- function(
  api_key = NULL,
  client = getOption("rflow.client"),
  launch_in = c("viewer", "browser"),
  ...,
  host = getOption("shiny.host", "127.0.0.1")
) {
  # Verify we're in RStudio
  check_in_rstudio()

  # Clean up RStudio environment before starting
  clean_rstudio_session()

  # Check for Anthropic API key
  anthropic_key <- Sys.getenv("ANTHROPIC_API_KEY", "")
  if (nchar(anthropic_key) == 0) {
    cli::cli_abort(c(
      "Anthropic API key not found",
      "i" = "Set your API key: Sys.setenv(ANTHROPIC_API_KEY = 'your-key')",
      "i" = "Get a key at: https://console.anthropic.com/"
    ))
  }
  
  # Match launch_in argument
  launch_in <- match.arg(launch_in)
  
  # Setup LLM client (auto-configures Claude - uses server key for trial)
  client <- setup_client(client)
  
  # Find available ports
  port <- find_available_port()
  env_port <- find_available_port()
  env_url <- generate_env_server_url(env_port)
  
  # Launch socket server for tool execution in user's R session
  launch_env_server(env_url)
  
  # Create temporary app directory with client configuration
  app_dir <- create_app_dir(env_url, client)
  
  # Run Shiny app as background job
  run_in_background(app_dir, "Rflow", host, port)
  
  # Open in viewer pane or browser
  if (launch_in == "browser") {
    open_app_in_browser(host, port)
  } else {
    # Activate viewer protection to keep Rflow in viewer
    activate_rflow_viewer()
    open_app_in_viewer(host, port)
  }
}

check_in_rstudio <- function(call = rlang::caller_env()) {
  rstudioapi::verifyAvailable()
  
  if (identical(Sys.getenv("POSITRON"), "1")) {
    cli::cli_abort(
      "Rflow requires RStudio and is not supported in Positron.",
      call = call
    )
  }
}

find_available_port <- function() {
  safe_ports <- setdiff(3000:8000, c(3659, 4045, 5060, 5061, 6000, 6566, 6665:6669, 6697))
  sample(safe_ports, 1)
}

create_app_dir <- function(env_url, client) {
  dir <- normalizePath(tempdir(), winslash = "/")
  app_file <- create_app_file(env_url, client)
  file.copy(app_file, file.path(dir, "app.R"), overwrite = TRUE)
  dir
}

create_app_file <- function(env_url, client, use_custom = FALSE) {
  # Load app template - use stable client.R by default
  template_file <- if (use_custom) "client_custom.R" else "client.R"
  template_path <- system.file(template_file, package = "Rflow")
  template <- paste(readLines(template_path, warn = FALSE), collapse = "\n")

  # Load system prompt
  working_dir <- normalizePath(getwd(), winslash = "/")
  prompt_path <- system.file("agents", "main.md", package = "Rflow")
  system_prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
  client$set_system_prompt(system_prompt)

  # Configure tools on the client (route to env server)
  all_tools <- agent_tools(socket_url = env_url)
  client$set_tools(all_tools)

  # Save client to temp file
  client_path <- tempfile(fileext = ".rds")
  saveRDS(client, client_path)
  client_path <- normalizePath(client_path, winslash = "/")

  # Replace template variables
  app_code <- template
  app_code <- gsub("{{client_path}}", client_path, app_code, fixed = TRUE)
  app_code <- gsub("{{env_url}}", env_url, app_code, fixed = TRUE)
  app_code <- gsub("{{working_dir}}", working_dir, app_code, fixed = TRUE)

  # Write to temp file
  temp_file <- tempfile(fileext = ".R")
  writeLines(app_code, temp_file)
  temp_file
}

run_in_background <- function(app_dir, job_name, host, port) {
  job_script <- tempfile(fileext = ".R")
  writeLines(
    glue::glue("shiny::runApp(appDir = '{app_dir}', port = {port}, host = '{host}')"),
    job_script
  )
  rstudioapi::jobRunScript(job_script, name = job_name)
}

open_app_in_viewer <- function(host, port) {
  url <- glue::glue("http://{host}:{port}")
  translated_url <- rstudioapi::translateLocalUrl(url, absolute = TRUE)
  
  wait_for_app_launch(translated_url)
  
  rstudioapi::viewer(translated_url)
  rstudioapi::executeCommand("activateConsole")
}

open_app_in_browser <- function(host, port) {
  url <- glue::glue("http://{host}:{port}")
  translated_url <- rstudioapi::translateLocalUrl(url, absolute = TRUE)
  
  wait_for_app_launch(translated_url)
  
  cli::cli_alert_success("Opening Rflow in browser...")
  utils::browseURL(translated_url)
  rstudioapi::executeCommand("activateConsole")
}

wait_for_app_launch <- function(url, max_seconds = 30) {
  start_time <- Sys.time()
  cli::cli_alert_info("Waiting for app to start at {url}...")
  
  last_error <- NULL
  while (difftime(Sys.time(), start_time, units = "secs") < max_seconds) {
    result <- tryCatch(
      {
        httr2::request(url) |> httr2::req_perform()
        elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)
        cli::cli_alert_success("App started successfully after {elapsed} seconds")
        return(invisible(NULL))
      },
      error = function(e) {
        last_error <<- conditionMessage(e)
        NULL
      }
    )
    Sys.sleep(0.5)
  }
  
  cli::cli_abort(c(
    "App failed to start within {max_seconds} seconds",
    "i" = "Last error: {last_error}",
    "i" = "Check the background job logs in RStudio for more details"
  ))
}

#' Clean up Rflow temporary files
#' @keywords internal
cleanup_rflow_temp <- function() {
  tryCatch({
    temp_dir <- tempdir()

    # Clean up client RDS files
    client_files <- list.files(temp_dir, pattern = "^file[0-9a-f]+.*\\.rds$", full.names = TRUE)
    if (length(client_files) > 0) {
      unlink(client_files)
    }

    # Clean up temp R script files
    app_files <- list.files(temp_dir, pattern = "^file[0-9a-f]+.*\\.R$", full.names = TRUE)
    if (length(app_files) > 0) {
      unlink(app_files)
    }

    # Clean up HTML temp files
    html_files <- list.files(temp_dir, pattern = "^file[0-9a-f]+.*\\.html$", full.names = TRUE)
    if (length(html_files) > 0) {
      unlink(html_files)
    }

    invisible(TRUE)
  }, error = function(e) {
    warning("Could not clean up all temp files: ", conditionMessage(e))
    invisible(FALSE)
  })
}

#' Stop Rflow and Restore Viewer
#'
#' @description
#' Stops the Rflow background job and restores normal viewer behavior.
#'
#' @export
stop_rflow <- function() {
  # Deactivate viewer protection
  deactivate_rflow_viewer()

  # Try to stop the background job
  tryCatch({
    jobs <- rstudioapi::jobList()
    rflow_jobs <- jobs[grepl("Rflow", names(jobs), ignore.case = TRUE)]

    if (length(rflow_jobs) > 0) {
      for (job_id in rflow_jobs) {
        rstudioapi::jobRemove(job_id)
      }
      cli::cli_alert_success("Rflow stopped successfully")
    } else {
      cli::cli_alert_info("No Rflow jobs found")
    }
  }, error = function(e) {
    cli::cli_alert_warning("Could not stop background job: {conditionMessage(e)}")
  })

  # Clean up temporary files
  cleanup_rflow_temp()

  invisible(NULL)
}

# Legacy function - no longer used
# validate_rflow_license <- function(api_key) {
#   # This function referenced old trial/licensing system that has been removed
#   invisible(NULL)
# }

#' Clean RStudio Session
#' 
#' @description
#' Clears plots, viewer, stops old jobs, and resets graphics devices before starting Rflow.
#' This prevents old maps/plots from appearing when Rflow starts.
#' 
#' @keywords internal
clean_rstudio_session <- function() {
  cli::cli_alert_info("Cleaning RStudio session...")
  
  # Clear the R environment (remove all objects that might trigger plots)
  tryCatch({
    # Get all objects in global environment
    all_objs <- ls(envir = .GlobalEnv)
    # Find plot/map related objects (ggplot, leaflet, htmlwidgets, etc.)
    for (obj_name in all_objs) {
      obj <- get(obj_name, envir = .GlobalEnv)
      # Remove ggplot, leaflet, htmlwidget objects
      if (inherits(obj, c("ggplot", "leaflet", "htmlwidget", "plotly", "tmap"))) {
        rm(list = obj_name, envir = .GlobalEnv)
      }
    }
  }, error = function(e) NULL)
  
  # Stop all previous Rflow jobs
  tryCatch({
    jobs <- rstudioapi::jobList()
    if (length(jobs) > 0) {
      rflow_jobs <- jobs[grepl("Rflow", names(jobs), ignore.case = TRUE)]
      if (length(rflow_jobs) > 0) {
        cli::cli_alert_info("Stopping {length(rflow_jobs)} previous Rflow job(s)...")
        for (job_id in rflow_jobs) {
          tryCatch({
            rstudioapi::jobRemove(job_id)
          }, error = function(e) NULL)
        }
        cli::cli_alert_success("Previous jobs stopped")
      }
    }
  }, error = function(e) NULL)
  
  # Close ALL graphics devices (clears plots)
  tryCatch({
    graphics.off()
  }, error = function(e) NULL)
  
  # Force close any remaining devices
  tryCatch({
    while (dev.cur() > 1) {
      dev.off()
    }
  }, error = function(e) NULL)
  
  # Clear RStudio's plot history
  tryCatch({
    if (rstudioapi::isAvailable()) {
      # Clear all plots from the Plots pane
      if (rstudioapi::hasFun("executeCommand")) {
        rstudioapi::executeCommand("clearPlots")
      }
    }
  }, error = function(e) NULL)
  
  # Clear the last plot
  tryCatch({
    if (exists(".Last.value", envir = .GlobalEnv)) {
      last_val <- get(".Last.value", envir = .GlobalEnv)
      if (inherits(last_val, c("ggplot", "leaflet", "htmlwidget", "plotly"))) {
        rm(".Last.value", envir = .GlobalEnv)
      }
    }
  }, error = function(e) NULL)
  
  # Clear the viewer pane by showing blank content
  tryCatch({
    if (rstudioapi::isAvailable()) {
      # Create a blank HTML to clear the viewer
      blank_html <- tempfile(fileext = ".html")
      writeLines("<html><body></body></html>", blank_html)
      rstudioapi::viewer(blank_html)
      Sys.sleep(0.1)
      rstudioapi::viewer(NULL)
      unlink(blank_html)
    }
  }, error = function(e) NULL)
  
  # Kill any htmlwidget/leaflet sessions
  tryCatch({
    # Clear shiny's httpuv servers that might be serving old content
    if (requireNamespace("httpuv", quietly = TRUE)) {
      httpuv::stopAllServers()
    }
  }, error = function(e) NULL)
  
  # Clear any pending later callbacks
  tryCatch({
    later::later(function() {}, delay = 0)
  }, error = function(e) NULL)
  
  # Reset viewer option
  tryCatch({
    options(viewer = NULL)
  }, error = function(e) NULL)
  
  # Clear any leaflet/htmlwidget temp files
  tryCatch({
    temp_dirs <- list.dirs(tempdir(), recursive = FALSE)
    html_dirs <- temp_dirs[grepl("viewhtml|leaflet|htmlwidget", temp_dirs, ignore.case = TRUE)]
    for (d in html_dirs) {
      unlink(d, recursive = TRUE)
    }
  }, error = function(e) NULL)
  
  # Delay to let things settle
  Sys.sleep(0.3)
  
  cli::cli_alert_success("Session cleaned")
  invisible(NULL)
}

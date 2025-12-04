# R code execution tool
run_r_code_env <- new.env(parent = emptyenv())
run_r_code_env$exec_env <- new.env(parent = .GlobalEnv)

tool_run_r_code <- function() {
  ellmer::tool(
    function(code, persist = FALSE, `_intent` = NULL) {
      messages <- character()
      warnings <- character()
      error_msg <- NULL
      result <- NULL

      exec_env <- if (persist) .GlobalEnv else run_r_code_env$exec_env

      # Ensure graphics device is in valid state before executing code
      # This prevents "r-graphics error 4 (Invalid plot index)" errors
      tryCatch({
        # Check if current device is valid
        if (dev.cur() > 1) {
          # Try to use current device - if it fails, it's invalid
          tryCatch({
            dev.list()  # This will fail if device is invalid
          }, error = function(e) {
            # Device is invalid, close it and let R create a new one
            tryCatch(dev.off(), error = function(e) NULL)
          })
        }
      }, error = function(e) NULL)

      result <- tryCatch(
        withCallingHandlers(
          {
            eval(parse(text = code), envir = exec_env)
          },
          message = function(m) {
            messages <<- c(messages, conditionMessage(m))
            invokeRestart("muffleMessage")
          },
          warning = function(w) {
            warnings <<- c(warnings, conditionMessage(w))
            invokeRestart("muffleWarning")
          }
        ),
        error = function(e) {
          error_msg <<- conditionMessage(e)

          # Handle graphics device errors specifically
          if (grepl("graphics error|invalid plot|device", error_msg, ignore.case = TRUE)) {
            # Try to recover from graphics errors
            tryCatch({
              # Close any broken devices
              while (dev.cur() > 1) {
                dev.off()
              }
              # Try executing the code again with a fresh device
              result <<- eval(parse(text = code), envir = exec_env)
              error_msg <<- NULL  # Clear error if retry succeeded
            }, error = function(e2) {
              # If retry also fails, keep the original error
              error_msg <<- paste0(error_msg, " (Recovery attempted but failed: ", conditionMessage(e2), ")")
            })
          }

          NULL
        }
      )
      
      if (!is.null(error_msg)) {
        return(ellmer::ContentToolResult(
          value = paste0("Error: ", error_msg),
          extra = list(
            display = list(
              markdown = paste0("```r\n", code, "\n#> Error: ", error_msg, "\n```"),
              title = "Run R Code (Error)",
              show_request = FALSE,
              open = TRUE
            )
          )
        ))
      }
      
      output <- if (!is.null(result)) {
        paste0(utils::capture.output(print(result)), collapse = "\n")
      } else {
        "Code executed successfully."
      }
      
      if (length(messages) > 0) {
        output <- paste0(output, "\n\nMessages:\n", paste(messages, collapse = "\n"))
      }
      
      if (length(warnings) > 0) {
        output <- paste0(output, "\n\nWarnings:\n", paste(warnings, collapse = "\n"))
      }
      
      ellmer::ContentToolResult(
        value = output,
        extra = list(
          display = list(
            markdown = paste0("```r\n", code, "\n#> ", gsub("\n", "\n#> ", output), "\n```"),
            title = "Run R Code",
            show_request = FALSE,
            open = TRUE
          )
        )
      )
    },
    name = "run_r_code",
    description = paste(
      "Execute R code and return the result.",
      "By default runs in a temporary environment.",
      "Set persist=TRUE to run in the user's global environment (use sparingly)."
    ),
    arguments = list(
      code = ellmer::type_string("The R code to execute"),
      persist = ellmer::type_boolean(
        "Whether to run in global environment (true) or temporary (false). Default false.",
        required = FALSE
      ),
      `_intent` = ellmer::type_string("Why you're running this code", required = FALSE)
    ),
    convert = FALSE
  )
}

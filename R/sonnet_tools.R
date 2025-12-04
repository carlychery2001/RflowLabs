#' Custom Tool Execution for Claude Sonnet 4.5
#' 
#' This handles tool calls from Claude Sonnet 4.5 which uses a different format
#' than what elmer currently supports.
#' 
#' @keywords internal

#' Execute tools from Claude Sonnet 4.5 response
#' @param client The elmer client
#' @param message User message
#' @param tools List of tool functions
#' @return Response with tool results
execute_with_tools <- function(client, message, tools) {
  max_iterations <- 10
  conversation <- list()
  
  for (iteration in 1:max_iterations) {
    cat("[>] Tool iteration", iteration, "\n")
    
    # Get response from Claude
    response <- client$chat(message, stream = FALSE)
    
    # Check if response contains tool calls
    tool_calls <- extract_tool_calls(response)
    
    if (length(tool_calls) == 0) {
      # No more tool calls, return final response
      return(response)
    }
    
    # Execute each tool call
    tool_results <- list()
    for (tool_call in tool_calls) {
      cat("[TOOL] Executing tool:", tool_call$name, "\n")
      
      # Find and execute the tool
      tool_func <- tools[[tool_call$name]]
      if (!is.null(tool_func)) {
        result <- tryCatch({
          do.call(tool_func, tool_call$input)
        }, error = function(e) {
          list(error = conditionMessage(e))
        })
        
        tool_results[[length(tool_results) + 1]] <- list(
          tool_use_id = tool_call$id,
          content = jsonlite::toJSON(result, auto_unbox = TRUE)
        )
        
        cat("[OK] Tool result:", substr(as.character(result), 1, 100), "...\n")
      }
    }
    
    # Add tool results to conversation and continue
    message <- list(
      role = "user",
      content = tool_results
    )
  }
  
  stop("Max tool iterations reached")
}

#' Extract tool calls from Claude response
#' @param response Response from Claude
#' @return List of tool calls
extract_tool_calls <- function(response) {
  tool_calls <- list()
  
  if (!is.null(response$content)) {
    for (block in response$content) {
      if (!is.null(block$type) && block$type == "tool_use") {
        tool_calls[[length(tool_calls) + 1]] <- list(
          id = block$id,
          name = block$name,
          input = block$input
        )
      }
    }
  }
  
  tool_calls
}

#' Stream with tool execution for Sonnet 4.5
#' @param client The elmer client
#' @param message User message
#' @param tools List of tool functions
#' @param callback Function to call with each chunk
#' @param session Shiny session for UI updates
#' @return Final response
stream_with_tools <- function(client, message, tools, callback = NULL, session = NULL) {
  max_iterations <- 5  # Reduce to prevent long waits
  all_text <- ""
  
  for (iteration in 1:max_iterations) {
    cat("[>] Iteration", iteration, "\n")
    
    # Add timeout protection
    start_time <- Sys.time()
    
    # Stream the response
    chunks <- list()
    tool_calls <- list()
    current_tool <- NULL
    iteration_text <- ""
    
    stream <- client$stream(message)
    
    coro::loop(for (chunk in stream) {
      # Collect chunks
      chunks[[length(chunks) + 1]] <- chunk
      
      # Check for tool use
      if (!is.null(chunk$type)) {
        if (chunk$type == "content_block_start" && 
            !is.null(chunk$content_block$type) && 
            chunk$content_block$type == "tool_use") {
          current_tool <- list(
            id = chunk$content_block$id,
            name = chunk$content_block$name,
            input = ""
          )
          cat("[TOOL] Tool starting:", chunk$content_block$name, "\n")
        } else if (chunk$type == "content_block_delta" && 
                   !is.null(chunk$delta$type) && 
                   chunk$delta$type == "input_json_delta") {
          if (!is.null(current_tool)) {
            current_tool$input <- paste0(current_tool$input, chunk$delta$partial_json)
          }
        } else if (chunk$type == "content_block_stop" && !is.null(current_tool)) {
          # Parse the complete input
          current_tool$input <- jsonlite::fromJSON(current_tool$input)
          tool_calls[[length(tool_calls) + 1]] <- current_tool
          current_tool <- NULL
        } else if (chunk$type == "content_block_delta" && 
                   !is.null(chunk$delta$type) && 
                   chunk$delta$type == "text_delta") {
          # Stream text to callback
          text <- chunk$delta$text
          iteration_text <- paste0(iteration_text, text)
          all_text <- paste0(all_text, text)
          if (!is.null(callback)) {
            callback(text)
          }
        }
      }
    })
    
    # If no tool calls, we're done
    if (length(tool_calls) == 0) {
      cat("[OK] Response complete\n")
      return(chunks)
    }
    
    # Execute tools and show clean feedback
    cat("[TOOL] Executing", length(tool_calls), "tool(s)\n")
    tool_results <- list()
    
    for (i in seq_along(tool_calls)) {
      tool_call <- tool_calls[[i]]
      tool_name <- tool_call$name
      
      cat("  ", i, "/", length(tool_calls), "->", tool_name, "\n")
      
      # Show tool execution in UI
      if (!is.null(callback)) {
        tool_msg <- paste0("\n\n[TOOL] **", tool_name, "**")
        callback(tool_msg)
      }
      
      tool_func <- tools[[tool_name]]
      if (!is.null(tool_func)) {
        result <- tryCatch({
          res <- do.call(tool_func, tool_call$input)
          cat("    [OK] Success\n")
          
          # Show success in UI
          if (!is.null(callback)) {
            callback(" [OK]\n")
          }
          
          res
        }, error = function(e) {
          cat("    [X] Error:", conditionMessage(e), "\n")
          
          # Show error in UI
          if (!is.null(callback)) {
            callback(paste0(" [X] Error: ", conditionMessage(e), "\n"))
          }
          
          list(error = conditionMessage(e))
        })
        
        tool_results[[length(tool_results) + 1]] <- list(
          type = "tool_result",
          tool_use_id = tool_call$id,
          content = as.character(jsonlite::toJSON(result, auto_unbox = TRUE))
        )
      }
    }
    
    # Continue conversation with tool results
    message <- list(
      role = "user",
      content = tool_results
    )
    
    cat("[SEND] Sending tool results back to Claude\n")
  }
  
  stop("Max tool iterations reached")
}

# Tool registry for the agent
agent_tools <- function(socket_url = NULL) {
  # Tools that need to run in the user's R session
  tools_to_reroute <- c(
    btw::btw_tools("env"),
    btw::btw_tools("btw_tool_files_list_files"),
    btw::btw_tools("btw_tool_files_code_search"),
    list(
      read_text_file = tool_read_text_file(),
      write_text_file = tool_write_text_file(),
      run_r_code = tool_run_r_code(),
      analyze_file = tool_analyze_file(),
      run_command = tool_run_command(),
      create_directory = tool_create_directory(),
      delete_path = tool_delete_path(),
      copy_path = tool_copy_path(),
      move_path = tool_move_path(),
      list_directory = tool_list_directory(),
      search_r_source = tool_search_r_source(),
      get_r_internals_info = tool_get_r_internals(),
      find_r_function = tool_find_r_function()
    )
  )
  
  # Reroute tools to execute via socket in user's session
  if (!is.null(socket_url)) {
    tools_to_reroute <- lapply(tools_to_reroute, reroute_tool, socket_url = socket_url)
  }
  
  # Combine with tools that can run in the Shiny process
  c(
    btw::btw_tools("docs"),
    btw::btw_tools("session"),
    tools_to_reroute,
    list(
      # Add your custom tools here
      example_tool = tool_example()
    )
  )
}

# Example custom tool
tool_example <- function() {
  ellmer::tool(
    function(message, `_intent` = NULL) {
      result <- paste("You said:", message)
      
      ellmer::ContentToolResult(
        value = result,
        extra = list(
          display = list(
            markdown = paste0("**Example Tool Result:**\n\n", result),
            title = "Example Tool",
            show_request = FALSE,
            open = TRUE
          )
        )
      )
    },
    name = "example_tool",
    description = "An example tool that echoes back your message. Replace this with your own custom tools.",
    arguments = list(
      message = ellmer::type_string("The message to echo back"),
      `_intent` = ellmer::type_string("Brief description of why you're using this tool", required = FALSE)
    ),
    convert = FALSE
  )
}

# Socket-based tool routing to execute in user's R session
# This allows the Shiny background job to execute tools in the user's actual environment

the <- new.env(parent = emptyenv())

reroute_tool <- function(tool, socket_url) {
  tool_fun <- S7::S7_data(tool)
  
  rerouted_fun <- rlang::new_function(
    rlang::fn_fmls(tool_fun),
    rlang::expr({
      args <- as.list(environment())
      
      sock <- nanonext::socket("req", dial = !!socket_url)
      on.exit(close(sock), add = TRUE)
      
      ctx <- nanonext::context(sock)
      
      request <- list(
        tool_name = !!tool@name,
        arguments = args
      )
      
      response <- nanonext::request(ctx, data = request, timeout = 5000)
      nanonext::call_aio(response)
      
      result <- response$data
      
      if (!is.null(result$error)) {
        cli::cli_abort(result$error, call = rlang::caller_env())
      }
      
      result$value
    }),
    env = rlang::fn_env(tool_fun)
  )
  
  S7::S7_data(tool) <- rerouted_fun
  tool
}

generate_env_server_url <- function(port) {
  sprintf("tcp://127.0.0.1:%d", port)
}

launch_env_server <- function(url) {
  start_env_tool_server(url)
  wait_for_env_server(url)
  invisible(url)
}

start_env_tool_server <- function(url) {
  sock <- nanonext::socket("rep", listen = url)
  all_tools <- agent_tools()
  
  the$env_server_socket <- sock
  the$env_server_active <- TRUE
  
  later::later(
    function() service_env_requests(sock, all_tools),
    delay = 0.1
  )
  
  invisible(sock)
}

service_env_requests <- function(sock, all_tools) {
  if (!isTRUE(the$env_server_active)) {
    return()
  }
  
  ctx <- nanonext::context(sock)
  
  nanonext::reply(
    ctx,
    execute = function(request) {
      tool_name <- request$tool_name
      args <- request$arguments
      
      if (tool_name %in% names(all_tools)) {
        tool <- all_tools[[tool_name]]
        tool_fun <- S7::S7_data(tool)
        
        tryCatch(
          {
            result <- do.call(tool_fun, args, envir = .GlobalEnv)
            list(value = result, error = NULL)
          },
          error = function(e) {
            list(value = NULL, error = conditionMessage(e))
          }
        )
      } else {
        list(value = NULL, error = paste0("Unknown tool: ", tool_name))
      }
    },
    timeout = 100
  )
  
  later::later(
    function() service_env_requests(sock, all_tools),
    delay = 0.1
  )
}

wait_for_env_server <- function(url, max_seconds = 5) {
  start_time <- Sys.time()
  
  while (difftime(Sys.time(), start_time, units = "secs") < max_seconds) {
    result <- tryCatch(
      {
        sock <- nanonext::socket("req", dial = url)
        on.exit(close(sock), add = TRUE)
        ctx <- nanonext::context(sock)
        
        test_request <- list(
          tool_name = "btw_tool_env_describe_environment",
          arguments = list(items = NULL, `_intent` = "")
        )
        
        response <- nanonext::request(ctx, data = test_request, timeout = 100)
        nanonext::call_aio(response)
        
        return(invisible(NULL))
      },
      error = function(e) NULL
    )
    
    Sys.sleep(0.1)
  }
  
  cli::cli_abort("Env tool server failed to start within {max_seconds} seconds")
}

#' Viewer Manager - Keep Rflow in Viewer, send other content to browser
#'
#' @description
#' Intercepts viewer calls and redirects them to browser when Rflow is active.
#' This allows Rflow to stay in the Viewer while maps, plots, and other content
#' open in the browser automatically.

# Store Rflow's viewer state
.rflow_env <- new.env(parent = emptyenv())
.rflow_env$is_active <- FALSE
.rflow_env$original_viewer <- NULL
.rflow_env$proxy_process <- NULL
.rflow_env$proxy_port <- 5555

#' Start Proxy Server
#' 
#' @description
#' Starts Python proxy server for wrapping viewer content
#' 
#' @keywords internal
start_proxy_server <- function() {
  # Check if already running
  if (!is.null(.rflow_env$proxy_process)) {
    return(invisible(NULL))
  }
  
  # Find proxy server script
  proxy_script <- system.file("viewer_proxy", "proxy_server.py", package = "Rflow")
  
  if (!file.exists(proxy_script)) {
    # Try alternative path
    proxy_script <- file.path(getwd(), "viewer_proxy", "proxy_server.py")
  }
  
  if (!file.exists(proxy_script)) {
    cat("[WARNING]  Proxy server not found, toolbar disabled\n")
    return(invisible(NULL))
  }
  
  # Start proxy server in background
  tryCatch({
    port <- .rflow_env$proxy_port
    
    # Start Python process (SECURITY: Bind to localhost only)
    if (.Platform$OS.type == "windows") {
      cmd <- sprintf('python "%s" %d --host 127.0.0.1', proxy_script, port)
      .rflow_env$proxy_process <- system(cmd, wait = FALSE, invisible = TRUE)
    } else {
      cmd <- sprintf('python3 "%s" %d --host 127.0.0.1 &', proxy_script, port)
      system(cmd)
    }
    
    # Wait a moment for server to start
    Sys.sleep(1)
    
    cat("[OK] Viewer proxy started on port", port, "\n")
  }, error = function(e) {
    cat("[WARNING]  Could not start proxy server:", conditionMessage(e), "\n")
    cat("[WARNING]  Toolbar will be disabled\n")
  })
  
  invisible(NULL)
}

#' Activate Rflow Viewer Protection
#' 
#' @description
#' Redirects viewer content to browser while Rflow is running
#' 
#' @keywords internal
activate_rflow_viewer <- function() {
  # Store original viewer function
  if (is.null(.rflow_env$original_viewer)) {
    .rflow_env$original_viewer <- getOption("viewer")
  }
  
  # Start proxy server
  start_proxy_server()
  
  # Set custom viewer that redirects to browser
  options(viewer = function(url, height = NULL) {
    if (.rflow_env$is_active) {
      # Rflow is active, send other content to browser
      message("[VIEW] Opening in browser (Rflow is using the Viewer)")
      
      # Open directly in browser
      # Note: Toolbar feature disabled due to browser security restrictions
      # Users can use browser's built-in tools: Print to PDF, Screenshot, etc.
      utils::browseURL(url)
    } else {
      # Rflow not active, use original viewer
      if (!is.null(.rflow_env$original_viewer)) {
        .rflow_env$original_viewer(url, height)
      } else {
        # Fallback to RStudio viewer
        rstudioapi::viewer(url)
      }
    }
  })
  
  .rflow_env$is_active <- TRUE
  cat("[OK] Rflow Viewer protection activated\n")
  cat("[VIEW] Maps and plots will open in browser with toolbar\n")
}

#' Wrap Content with Browser Controls
#' 
#' @description
#' Adds toolbar with clear, save PDF, and save PNG buttons
#' 
#' @keywords internal
wrap_content_with_controls <- function(original_url) {
  # Read original content
  if (grepl("^http://", original_url) || grepl("^https://", original_url)) {
    # It's a URL, can't wrap it
    return(original_url)
  }
  
  # It's a file path
  if (!file.exists(original_url)) {
    return(original_url)
  }
  
  # Normalize path for iframe
  original_path <- normalizePath(original_url, winslash = "/")
  iframe_src <- paste0("file:///", original_path)

  # Get paths to bundled JavaScript libraries (SECURITY: Use local files instead of CDN)
  html2canvas_path <- system.file("www/js/html2canvas.min.js", package = "Rflow")
  jspdf_path <- system.file("www/js/jspdf.umd.min.js", package = "Rflow")

  # Normalize paths for browser
  html2canvas_url <- paste0("file:///", normalizePath(html2canvas_path, winslash = "/"))
  jspdf_url <- paste0("file:///", normalizePath(jspdf_path, winslash = "/"))

  # Create wrapped HTML with controls using iframe
  wrapped_html <- sprintf('
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Rflow Viewer</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      overflow: hidden;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }
    
    .toolbar {
      background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
      color: white;
      padding: 12px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      flex-shrink: 0;
    }
    
    .toolbar-title {
      font-weight: 600;
      font-size: 14px;
      margin-right: auto;
    }
    
    .toolbar-btn {
      background: rgba(255,255,255,0.2);
      border: 1px solid rgba(255,255,255,0.3);
      color: white;
      padding: 8px 16px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 500;
      transition: all 0.2s ease;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    
    .toolbar-btn:hover {
      background: rgba(255,255,255,0.3);
      transform: translateY(-1px);
    }
    
    .toolbar-btn:active {
      transform: translateY(0);
    }
    
    .toolbar-btn.danger {
      background: rgba(239, 68, 68, 0.8);
      border-color: rgba(239, 68, 68, 1);
    }
    
    .toolbar-btn.danger:hover {
      background: rgba(239, 68, 68, 1);
    }
    
    .content-frame {
      flex: 1;
      border: none;
      width: 100%%;
      height: 100%%;
      overflow: auto;
    }
    
    .content-wrapper {
      flex: 1;
      overflow: auto;
      background: white;
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <div class="toolbar-title">[VIEW] Rflow Viewer</div>
    <button class="toolbar-btn" onclick="savePDF()">
      [FILE] Save as PDF
    </button>
    <button class="toolbar-btn" onclick="savePNG()">
      [IMAGE] Save as PNG
    </button>
    <button class="toolbar-btn danger" onclick="clearView()">
      [DELETE] Clear
    </button>
  </div>
  
  <iframe id="contentFrame" class="content-frame" src="%s"></iframe>

  <script src="%s"></script>
  <script src="%s"></script>

  <script>
    function clearView() {
      if (confirm("Clear this view? This will close the window.")) {
        window.close();
      }
    }
    
    function savePDF() {
      const iframe = document.getElementById("contentFrame");
      const content = iframe.contentDocument || iframe.contentWindow.document;
      
      html2canvas(content.body, {
        scale: 2,
        useCORS: true,
        logging: false
      }).then(canvas => {
        const imgData = canvas.toDataURL("image/png");
        const { jsPDF } = window.jspdf;
        
        // Calculate dimensions
        const imgWidth = 210; // A4 width in mm
        const pageHeight = 297; // A4 height in mm
        const imgHeight = (canvas.height * imgWidth) / canvas.width;
        
        const pdf = new jsPDF("p", "mm", "a4");
        let heightLeft = imgHeight;
        let position = 0;
        
        // Add first page
        pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
        heightLeft -= pageHeight;
        
        // Add additional pages if needed
        while (heightLeft > 0) {
          position = heightLeft - imgHeight;
          pdf.addPage();
          pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
          heightLeft -= pageHeight;
        }
        
        // Save
        const filename = "rflow-export-" + Date.now() + ".pdf";
        pdf.save(filename);
        
        alert("[OK] PDF saved: " + filename);
      }).catch(err => {
        alert("[X] Error saving PDF: " + err.message);
      });
    }
    
    function savePNG() {
      const iframe = document.getElementById("contentFrame");
      const content = iframe.contentDocument || iframe.contentWindow.document;
      
      html2canvas(content.body, {
        scale: 2,
        useCORS: true,
        logging: false
      }).then(canvas => {
        canvas.toBlob(blob => {
          const url = URL.createObjectURL(blob);
          const a = document.createElement("a");
          a.href = url;
          a.download = "rflow-export-" + Date.now() + ".png";
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(url);
          
          alert("[OK] PNG saved: " + a.download);
        });
      }).catch(err => {
        alert("[X] Error saving PNG: " + err.message);
      });
    }
  </script>
</body>
</html>
  ', iframe_src, html2canvas_url, jspdf_url)
  
  # Save wrapped HTML to temp file
  temp_file <- tempfile(fileext = ".html")
  writeLines(wrapped_html, temp_file)
  
  return(temp_file)
}

#' Deactivate Rflow Viewer Protection
#' 
#' @description
#' Restores normal viewer behavior
#' 
#' @keywords internal
deactivate_rflow_viewer <- function() {
  # Restore original viewer
  if (!is.null(.rflow_env$original_viewer)) {
    options(viewer = .rflow_env$original_viewer)
  }
  
  .rflow_env$is_active <- FALSE
  cat("[OK] Rflow Viewer protection deactivated\n")
  cat("[VIEW] Viewer restored to normal behavior\n")
}

#' Check if Rflow Viewer is Active
#' 
#' @return Logical indicating if Rflow is protecting the viewer
#' @export
is_rflow_viewer_active <- function() {
  .rflow_env$is_active
}

#' Manually Open Content in Browser
#' 
#' @description
#' Force content to open in browser instead of viewer
#' 
#' @param content Content to display (htmlwidget, ggplot, etc.)
#' @export
#' 
#' @examples
#' \dontrun{
#' library(leaflet)
#' map <- leaflet() %>% addTiles()
#' open_in_browser(map)
#' }
open_in_browser <- function(content) {
  # Create temp HTML file
  temp_file <- tempfile(fileext = ".html")
  
  # Handle different content types
  if (inherits(content, "htmlwidget")) {
    htmlwidgets::saveWidget(content, temp_file, selfcontained = TRUE)
  } else if (inherits(content, "ggplot")) {
    # Save ggplot as HTML via plotly
    if (requireNamespace("plotly", quietly = TRUE)) {
      p <- plotly::ggplotly(content)
      htmlwidgets::saveWidget(p, temp_file, selfcontained = TRUE)
    } else {
      stop("plotly package required to open ggplot in browser. Install with: install.packages('plotly')")
    }
  } else if (inherits(content, "shiny.tag.list") || inherits(content, "shiny.tag")) {
    # HTML content
    htmltools::save_html(content, temp_file)
  } else {
    stop("Unsupported content type. Supported: htmlwidget, ggplot, HTML")
  }
  
  # Open in browser
  utils::browseURL(temp_file)
  invisible(temp_file)
}

#' Tool: Analyze File
#'
#' Analyzes uploaded files (Excel, CSV, images, etc.)
#'
#' @return An ellmer tool
tool_analyze_file <- function() {
  ellmer::tool(
    function(file_path, analysis_type = "summary") {
      tryCatch({
        if (!file.exists(file_path)) {
          return(ellmer::ContentToolResult(
            value = paste0("File not found: ", file_path),
            extra = list(
              display = list(
                markdown = paste0("**Error:** File not found at path: `", file_path, "`"),
                title = "File Analysis Error"
              )
            )
          ))
        }
        
        # Detect file type
        ext <- tolower(tools::file_ext(file_path))
        
        result <- switch(ext,
          "xlsx" = ,
          "xls" = analyze_excel(file_path),
          "csv" = analyze_csv(file_path),
          "tsv" = analyze_tsv(file_path),
          "rds" = analyze_rds(file_path),
          "rdata" = ,
          "rda" = analyze_rdata(file_path),
          "json" = analyze_json(file_path),
          "shp" = analyze_shapefile(file_path),
          "geojson" = analyze_geojson(file_path),
          "png" = ,
          "jpg" = ,
          "jpeg" = ,
          "gif" = ,
          "bmp" = ,
          "tiff" = ,
          "webp" = analyze_image(file_path),
          "txt" = ,
          "log" = ,
          "md" = ,
          "markdown" = analyze_text(file_path),
          "r" = ,
          "rmd" = analyze_r_file(file_path),
          "py" = ,
          "js" = ,
          "html" = ,
          "css" = ,
          "xml" = ,
          "yaml" = ,
          "yml" = analyze_code_file(file_path, ext),
          "pdf" = analyze_pdf(file_path),
          "docx" = ,
          "doc" = analyze_document(file_path),
          # Default handler for any unknown file type
          analyze_generic(file_path, ext)
        )
        
        ellmer::ContentToolResult(
          value = result,
          extra = list(
            display = list(
              markdown = paste0("**File Analysis:**\n\n", result),
              title = "File Analysis"
            )
          )
        )
      }, error = function(e) {
        ellmer::ContentToolResult(
          value = paste0("Error analyzing file: ", conditionMessage(e)),
          extra = list(
            display = list(
              markdown = paste0("**Error:** ", conditionMessage(e)),
              title = "File Analysis Error"
            )
          )
        )
      })
    },
    name = "analyze_file",
    description = "Analyze any uploaded file regardless of extension. Supports Excel, CSV, TSV, RDS, RData, JSON, images, text files, code files, PDFs, and more. Provides summary statistics, structure, and content preview.",
    arguments = list(
      file_path = ellmer::type_string("Path to the file to analyze"),
      analysis_type = ellmer::type_string("Type of analysis: 'summary' (default), 'detailed', or 'preview'")
    )
  )
}

analyze_excel <- function(file_path) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    return("Package 'readxl' is required to analyze Excel files. Install it with: install.packages('readxl')")
  }
  
  sheets <- readxl::excel_sheets(file_path)
  result <- paste0("**Excel File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Sheets: ", length(sheets), "\n")
  result <- paste0(result, "- Sheet names: ", paste(sheets, collapse = ", "), "\n\n")
  
  # Analyze first sheet
  if (length(sheets) > 0) {
    data <- readxl::read_excel(file_path, sheet = 1)
    
    # Load data into global environment to avoid getting stuck with large datasets
    var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
    assign(var_name, data, envir = .GlobalEnv)
    
    result <- paste0(result, "**First sheet (", sheets[1], "):**\n")
    result <- paste0(result, "- Rows: ", nrow(data), "\n")
    result <- paste0(result, "- Columns: ", ncol(data), "\n")
    result <- paste0(result, "- Column names: ", paste(names(data), collapse = ", "), "\n")
    result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
    
    if (nrow(data) > 0) {
      result <- paste0(result, "**Preview (first 5 rows):**\n```\n")
      result <- paste0(result, paste(capture.output(print(head(data, 5))), collapse = "\n"))
      result <- paste0(result, "\n```")
    }
  }
  
  result
}

analyze_csv <- function(file_path) {
  # Read full dataset (not just 1000 rows)
  data <- read.csv(file_path)
  
  # Load data into global environment to avoid getting stuck with large datasets
  var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
  assign(var_name, data, envir = .GlobalEnv)
  
  result <- paste0("**CSV File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Rows: ", nrow(data), "\n")
  result <- paste0(result, "- Columns: ", ncol(data), "\n")
  result <- paste0(result, "- Column names: ", paste(names(data), collapse = ", "), "\n")
  result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
  
  # Column types
  result <- paste0(result, "**Column types:**\n")
  for (col in names(data)) {
    result <- paste0(result, "- `", col, "`: ", class(data[[col]])[1], "\n")
  }
  
  result <- paste0(result, "\n**Preview (first 5 rows):**\n```\n")
  result <- paste0(result, paste(capture.output(print(head(data, 5))), collapse = "\n"))
  result <- paste0(result, "\n```")
  
  result
}

analyze_image <- function(file_path) {
  file_info <- file.info(file_path)
  
  result <- paste0("**Image File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Size: ", round(file_info$size / 1024, 2), " KB\n")
  result <- paste0(result, "- Type: ", tools::file_ext(file_path), "\n")
  result <- paste0(result, "- Path: `", file_path, "`\n\n")
  result <- paste0(result, "Note: Image content analysis requires additional packages. The file is available at the path above for manual inspection or processing.")
  
  result
}

analyze_text <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  
  result <- paste0("**Text File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Lines: ", length(lines), "\n")
  result <- paste0(result, "- Characters: ", sum(nchar(lines)), "\n\n")
  
  preview_lines <- min(20, length(lines))
  result <- paste0(result, "**Preview (first ", preview_lines, " lines):**\n```\n")
  result <- paste0(result, paste(head(lines, preview_lines), collapse = "\n"))
  result <- paste0(result, "\n```")
  
  result
}

analyze_r_file <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  
  result <- paste0("**R Script Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Lines: ", length(lines), "\n")
  
  # Count functions
  func_pattern <- "^\\s*[a-zA-Z_][a-zA-Z0-9_]*\\s*<-\\s*function"
  funcs <- grep(func_pattern, lines, value = TRUE)
  result <- paste0(result, "- Functions defined: ", length(funcs), "\n")
  
  # Count library calls
  lib_pattern <- "^\\s*(library|require)\\("
  libs <- grep(lib_pattern, lines, value = TRUE)
  result <- paste0(result, "- Library calls: ", length(libs), "\n\n")
  
  result <- paste0(result, "**Content:**\n```r\n")
  result <- paste0(result, paste(lines, collapse = "\n"))
  result <- paste0(result, "\n```")
  
  result
}

analyze_tsv <- function(file_path) {
  # Read full dataset
  data <- read.delim(file_path, sep = "\t")
  
  # Load data into global environment to avoid getting stuck with large datasets
  var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
  assign(var_name, data, envir = .GlobalEnv)
  
  result <- paste0("**TSV File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Rows: ", nrow(data), "\n")
  result <- paste0(result, "- Columns: ", ncol(data), "\n")
  result <- paste0(result, "- Column names: ", paste(names(data), collapse = ", "), "\n")
  result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
  
  # Column types
  result <- paste0(result, "**Column types:**\n")
  for (col in names(data)) {
    result <- paste0(result, "- `", col, "`: ", class(data[[col]])[1], "\n")
  }
  
  result <- paste0(result, "\n**Preview (first 5 rows):**\n```\n")
  result <- paste0(result, paste(capture.output(print(head(data, 5))), collapse = "\n"))
  result <- paste0(result, "\n```")
  
  result
}

analyze_rds <- function(file_path) {
  data <- readRDS(file_path)
  
  # Load data into global environment
  var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
  assign(var_name, data, envir = .GlobalEnv)
  
  result <- paste0("**RDS File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Object class: ", class(data)[1], "\n")
  result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
  
  if (is.data.frame(data)) {
    result <- paste0(result, "- Rows: ", nrow(data), "\n")
    result <- paste0(result, "- Columns: ", ncol(data), "\n")
    result <- paste0(result, "- Column names: ", paste(names(data), collapse = ", "), "\n\n")
    result <- paste0(result, "**Preview (first 5 rows):**\n```\n")
    result <- paste0(result, paste(capture.output(print(head(data, 5))), collapse = "\n"))
    result <- paste0(result, "\n```")
  } else {
    result <- paste0(result, "**Structure:**\n```\n")
    result <- paste0(result, paste(capture.output(str(data)), collapse = "\n"))
    result <- paste0(result, "\n```")
  }
  
  result
}

analyze_rdata <- function(file_path) {
  # Load RData file and get object names
  env <- new.env()
  loaded_objects <- load(file_path, envir = env)
  
  result <- paste0("**RData File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Objects loaded: ", length(loaded_objects), "\n")
  result <- paste0(result, "- Object names: ", paste(loaded_objects, collapse = ", "), "\n\n")
  
  # Load all objects into global environment
  for (obj_name in loaded_objects) {
    assign(obj_name, get(obj_name, envir = env), envir = .GlobalEnv)
  }
  result <- paste0(result, "- **All objects loaded into global environment**\n\n")
  
  # Show info about each object
  for (obj_name in loaded_objects) {
    obj <- get(obj_name, envir = env)
    result <- paste0(result, "**Object: `", obj_name, "`**\n")
    result <- paste0(result, "- Class: ", class(obj)[1], "\n")
    
    if (is.data.frame(obj)) {
      result <- paste0(result, "- Rows: ", nrow(obj), "\n")
      result <- paste0(result, "- Columns: ", ncol(obj), "\n")
    } else if (is.vector(obj)) {
      result <- paste0(result, "- Length: ", length(obj), "\n")
    }
    result <- paste0(result, "\n")
  }
  
  result
}

analyze_json <- function(file_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return("Package 'jsonlite' is required to analyze JSON files. Install it with: install.packages('jsonlite')")
  }
  
  data <- jsonlite::fromJSON(file_path, simplifyDataFrame = TRUE)
  
  # Load data into global environment
  var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
  assign(var_name, data, envir = .GlobalEnv)
  
  result <- paste0("**JSON File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Object class: ", class(data)[1], "\n")
  result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
  
  if (is.data.frame(data)) {
    result <- paste0(result, "- Rows: ", nrow(data), "\n")
    result <- paste0(result, "- Columns: ", ncol(data), "\n")
    result <- paste0(result, "- Column names: ", paste(names(data), collapse = ", "), "\n\n")
    result <- paste0(result, "**Preview (first 5 rows):**\n```\n")
    result <- paste0(result, paste(capture.output(print(head(data, 5))), collapse = "\n"))
    result <- paste0(result, "\n```")
  } else if (is.list(data)) {
    result <- paste0(result, "- List elements: ", length(data), "\n")
    if (!is.null(names(data))) {
      result <- paste0(result, "- Element names: ", paste(names(data), collapse = ", "), "\n")
    }
    result <- paste0(result, "\n**Structure:**\n```\n")
    result <- paste0(result, paste(capture.output(str(data, max.level = 2)), collapse = "\n"))
    result <- paste0(result, "\n```")
  } else {
    result <- paste0(result, "**Content:**\n```\n")
    result <- paste0(result, paste(capture.output(print(data)), collapse = "\n"))
    result <- paste0(result, "\n```")
  }
  
  result
}

analyze_code_file <- function(file_path, ext) {
  lines <- readLines(file_path, warn = FALSE)
  
  lang_map <- list(
    py = "python", js = "javascript", html = "html", 
    css = "css", xml = "xml", yaml = "yaml", yml = "yaml"
  )
  lang <- lang_map[[ext]] %||% ext
  
  result <- paste0("**Code File Analysis (", toupper(ext), ")**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Lines: ", length(lines), "\n")
  result <- paste0(result, "- Characters: ", sum(nchar(lines)), "\n\n")
  
  preview_lines <- min(50, length(lines))
  result <- paste0(result, "**Content (first ", preview_lines, " lines):**\n```", lang, "\n")
  result <- paste0(result, paste(head(lines, preview_lines), collapse = "\n"))
  result <- paste0(result, "\n```")
  
  result
}

analyze_pdf <- function(file_path) {
  file_info <- file.info(file_path)
  
  result <- paste0("**PDF File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Size: ", round(file_info$size / 1024, 2), " KB\n")
  result <- paste0(result, "- Path: `", file_path, "`\n\n")
  
  # Try to extract text if pdftools is available
  if (requireNamespace("pdftools", quietly = TRUE)) {
    tryCatch({
      text <- pdftools::pdf_text(file_path)
      result <- paste0(result, "- Pages: ", length(text), "\n\n")
      
      # Show first page preview
      if (length(text) > 0) {
        preview <- substr(text[1], 1, 500)
        result <- paste0(result, "**First page preview:**\n```\n")
        result <- paste0(result, preview)
        if (nchar(text[1]) > 500) result <- paste0(result, "\n... (truncated)")
        result <- paste0(result, "\n```")
      }
    }, error = function(e) {
      result <<- paste0(result, "Note: Could not extract text from PDF. The file is available at the path above.")
    })
  } else {
    result <- paste0(result, "Note: Install 'pdftools' package to extract text from PDFs: install.packages('pdftools')")
  }
  
  result
}

analyze_document <- function(file_path) {
  file_info <- file.info(file_path)
  ext <- tools::file_ext(file_path)
  
  result <- paste0("**Document File Analysis (", toupper(ext), ")**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Size: ", round(file_info$size / 1024, 2), " KB\n")
  result <- paste0(result, "- Path: `", file_path, "`\n\n")
  
  if (ext == "docx" && requireNamespace("officer", quietly = TRUE)) {
    tryCatch({
      doc <- officer::read_docx(file_path)
      content <- officer::docx_summary(doc)
      result <- paste0(result, "- Paragraphs: ", sum(content$content_type == "paragraph"), "\n")
      result <- paste0(result, "- Tables: ", sum(content$content_type == "table cell"), "\n\n")
      result <- paste0(result, "Note: Document loaded. Use 'officer' package for detailed manipulation.")
    }, error = function(e) {
      result <<- paste0(result, "Note: Could not read document content. The file is available at the path above.")
    })
  } else {
    result <- paste0(result, "Note: Install 'officer' package to read Word documents: install.packages('officer')")
  }
  
  result
}

analyze_shapefile <- function(file_path) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    return("Package 'sf' is required to analyze shapefiles. Install it with: install.packages('sf')")
  }
  
  tryCatch({
    # Read shapefile
    spatial_data <- sf::st_read(file_path, quiet = TRUE)
    
    # Load into global environment
    var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
    assign(var_name, spatial_data, envir = .GlobalEnv)
    
    result <- paste0("**Shapefile Analysis**\n\n")
    result <- paste0(result, "- File: `", basename(file_path), "`\n")
    result <- paste0(result, "- Features: ", nrow(spatial_data), "\n")
    result <- paste0(result, "- Attributes: ", ncol(spatial_data) - 1, "\n")
    result <- paste0(result, "- Geometry type: ", as.character(unique(sf::st_geometry_type(spatial_data))), "\n")
    
    # CRS information
    crs_info <- sf::st_crs(spatial_data)
    if (!is.na(crs_info$input)) {
      result <- paste0(result, "- CRS: ", crs_info$input, "\n")
    }
    
    # Bounding box
    bbox <- sf::st_bbox(spatial_data)
    result <- paste0(result, "- Bounding box: [", 
                    round(bbox["xmin"], 4), ", ", round(bbox["ymin"], 4), ", ",
                    round(bbox["xmax"], 4), ", ", round(bbox["ymax"], 4), "]\n")
    
    result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
    
    # Attribute columns
    attr_cols <- setdiff(names(spatial_data), attr(spatial_data, "sf_column"))
    if (length(attr_cols) > 0) {
      result <- paste0(result, "**Attribute columns:**\n")
      for (col in attr_cols) {
        result <- paste0(result, "- `", col, "`: ", class(spatial_data[[col]])[1], "\n")
      }
    }
    
    # Preview
    if (nrow(spatial_data) > 0) {
      result <- paste0(result, "\n**Preview (first 5 features):**\n```\n")
      preview_data <- as.data.frame(spatial_data)[1:min(5, nrow(spatial_data)), ]
      result <- paste0(result, paste(capture.output(print(preview_data)), collapse = "\n"))
      result <- paste0(result, "\n```")
    }
    
    result
  }, error = function(e) {
    paste0("**Shapefile Analysis Error**\n\n",
           "- File: `", basename(file_path), "`\n",
           "- Error: ", conditionMessage(e), "\n\n",
           "Note: Make sure the .shp file has accompanying .shx, .dbf, and .prj files in the same directory.")
  })
}

analyze_geojson <- function(file_path) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    return("Package 'sf' is required to analyze GeoJSON files. Install it with: install.packages('sf')")
  }
  
  tryCatch({
    # Read GeoJSON
    spatial_data <- sf::st_read(file_path, quiet = TRUE)
    
    # Load into global environment
    var_name <- make.names(paste0(tools::file_path_sans_ext(basename(file_path)), "_data"))
    assign(var_name, spatial_data, envir = .GlobalEnv)
    
    result <- paste0("**GeoJSON File Analysis**\n\n")
    result <- paste0(result, "- File: `", basename(file_path), "`\n")
    result <- paste0(result, "- Features: ", nrow(spatial_data), "\n")
    result <- paste0(result, "- Properties: ", ncol(spatial_data) - 1, "\n")
    result <- paste0(result, "- Geometry type: ", as.character(unique(sf::st_geometry_type(spatial_data))), "\n")
    
    # CRS information
    crs_info <- sf::st_crs(spatial_data)
    if (!is.na(crs_info$input)) {
      result <- paste0(result, "- CRS: ", crs_info$input, "\n")
    }
    
    # Bounding box
    bbox <- sf::st_bbox(spatial_data)
    result <- paste0(result, "- Bounding box: [", 
                    round(bbox["xmin"], 4), ", ", round(bbox["ymin"], 4), ", ",
                    round(bbox["xmax"], 4), ", ", round(bbox["ymax"], 4), "]\n")
    
    result <- paste0(result, "- **Loaded into environment as: `", var_name, "`**\n\n")
    
    # Property columns
    attr_cols <- setdiff(names(spatial_data), attr(spatial_data, "sf_column"))
    if (length(attr_cols) > 0) {
      result <- paste0(result, "**Properties:**\n")
      for (col in attr_cols) {
        result <- paste0(result, "- `", col, "`: ", class(spatial_data[[col]])[1], "\n")
      }
    }
    
    # Preview
    if (nrow(spatial_data) > 0) {
      result <- paste0(result, "\n**Preview (first 5 features):**\n```\n")
      preview_data <- as.data.frame(spatial_data)[1:min(5, nrow(spatial_data)), ]
      result <- paste0(result, paste(capture.output(print(preview_data)), collapse = "\n"))
      result <- paste0(result, "\n```")
    }
    
    result
  }, error = function(e) {
    paste0("**GeoJSON Analysis Error**\n\n",
           "- File: `", basename(file_path), "`\n",
           "- Error: ", conditionMessage(e), "\n\n",
           "Note: Ensure the GeoJSON file is properly formatted.")
  })
}

analyze_generic <- function(file_path, ext) {
  file_info <- file.info(file_path)
  
  result <- paste0("**Generic File Analysis**\n\n")
  result <- paste0(result, "- File: `", basename(file_path), "`\n")
  result <- paste0(result, "- Extension: ", if(ext == "") "none" else ext, "\n")
  result <- paste0(result, "- Size: ", round(file_info$size / 1024, 2), " KB\n")
  result <- paste0(result, "- Path: `", file_path, "`\n")
  result <- paste0(result, "- Modified: ", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Try to detect if it's a text file
  is_text <- tryCatch({
    test_lines <- readLines(file_path, n = 10, warn = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  if (is_text) {
    lines <- readLines(file_path, warn = FALSE)
    result <- paste0(result, "**Detected as text file**\n")
    result <- paste0(result, "- Lines: ", length(lines), "\n")
    result <- paste0(result, "- Characters: ", sum(nchar(lines)), "\n\n")
    
    preview_lines <- min(20, length(lines))
    result <- paste0(result, "**Preview (first ", preview_lines, " lines):**\n```\n")
    result <- paste0(result, paste(head(lines, preview_lines), collapse = "\n"))
    result <- paste0(result, "\n```\n\n")
    result <- paste0(result, "Note: This file can be read as text. You can use `read_text_file` for full content.")
  } else {
    result <- paste0(result, "**Binary file detected**\n\n")
    result <- paste0(result, "This appears to be a binary file. The file is available at the path above for manual processing.")
  }
  
  result
}

#' Search R Source Code
#'
#' Search through the R interpreter source code for functions, patterns, or concepts.
#' This gives the AI deep understanding of R internals.
#'
#' @param pattern Search pattern (regex supported)
#' @param path Subdirectory to search (main, library, include, etc.)
#' @param context Number of lines of context around matches
#' @param max_results Maximum number of results to return
#'
#' @return Character vector of search results with file paths and line numbers
#' @export
search_r_source <- function(pattern, path = NULL, context = 3, max_results = 50) {
  # Get R source directory
  r_source_dir <- system.file("../R-source/R-4.5.2", package = "Rflow")

  # Fallback to download location if not installed
  if (!dir.exists(r_source_dir) || r_source_dir == "") {
    r_source_dir <- "C:/Users/carly/Downloads/Rflow/R-source/R-4.5.2"
  }

  if (!dir.exists(r_source_dir)) {
    return("Error: R source code not found. Please ensure R-source directory exists.")
  }

  # Build search path
  search_path <- r_source_dir
  if (!is.null(path)) {
    search_path <- file.path(r_source_dir, "src", path)
    if (!dir.exists(search_path)) {
      search_path <- file.path(r_source_dir, path)
    }
  }

  # Use grep to search (works cross-platform)
  tryCatch({
    # Search recursively through .c, .h, and .R files
    if (.Platform$OS.type == "windows") {
      # Windows: use findstr
      cmd <- sprintf('cd /d "%s" && findstr /S /N /I /C:"%s" *.c *.h *.R 2>nul',
                     search_path, pattern)
      results <- system(cmd, intern = TRUE, ignore.stderr = TRUE)
    } else {
      # Unix/Linux/Mac: use grep
      cmd <- sprintf('grep -r -n -i -C %d "%s" "%s" --include="*.c" --include="*.h" --include="*.R"',
                     context, pattern, search_path)
      results <- system(cmd, intern = TRUE, ignore.stderr = TRUE)
    }

    # Limit results
    if (length(results) > max_results) {
      results <- c(
        results[1:max_results],
        sprintf("\n... (showing %d of %d results, query more specific for remaining)",
                max_results, length(results))
      )
    }

    if (length(results) == 0) {
      return(sprintf("No matches found for '%s' in R source code.", pattern))
    }

    return(paste(results, collapse = "\n"))

  }, error = function(e) {
    return(sprintf("Search error: %s", e$message))
  })
}


#' Get R Internals Documentation
#'
#' Returns comprehensive documentation about R internals, architecture, and common patterns.
#'
#' @param topic Topic to get info about: "architecture", "memory", "evaluation",
#'               "parser", "graphics", "all"
#' @return Character string with R internals documentation
#' @export
get_r_internals_info <- function(topic = "all") {

  info <- list(
    architecture = '
# R INTERPRETER ARCHITECTURE

## Core Components (src/main/)

### 1. EVALUATION ENGINE (eval.c, eval-basics.c)
- **eval()**: Main expression evaluator - heart of R
- **applyClosure()**: Function call mechanism
- **evalList()**: Evaluates argument lists
- **Promise evaluation**: Lazy evaluation via PROMSXP
- **Context management**: RCNTXT struct for call stack

### 2. MEMORY MANAGEMENT (memory.c, alloc.c)
- **SEXPRECs**: S-expression data structure (everything in R)
- **Generational GC**: 3 generations (new, old, permanent)
- **gc()**: Garbage collector - mark & sweep algorithm
- **PROTECT/UNPROTECT**: Manual protection from GC
- **R_alloc()**: Transient memory allocation

### 3. PARSER & COMPILER (gram.y, gramRd.y)
- **Bison parser**: R language grammar
- **parse()**: Converts text to expression objects
- **R byte-code compiler**: speed optimization
- **deparse()**: Convert expressions back to text

### 4. OBJECT SYSTEM (attrib.c, objects.c)
- **Attributes**: names, dim, class, etc.
- **S3 dispatch**: UseMethod() - simple OOP
- **S4 dispatch**: Complex OOP (methods package)
- **R6/R7**: Reference-based OOP

### 5. BUILT-IN FUNCTIONS (builtin.c, names.c)
- **.Primitive()**: C-level primitives
- **.Internal()**: Internal C functions
- **FUNTAB**: Function dispatch table
- **do_xxx()**: C implementations of R functions
',

    memory = '
# R MEMORY INTERNALS

## SEXPTYPE Structure (Rinternals.h)
Every R object is a SEXPREC (S-expression record):

```c
typedef struct SEXPREC {
    SEXPTYPE sxpinfo;      // Type tag
    struct SEXPREC *attrib; // Attributes
    struct SEXPREC *gengc;  // GC info
    union {
        // Type-specific data
    } u;
} *SEXP;
```

## Main SEXP Types (Rinternals.h)
- **NILSXP (0)**: NULL
- **SYMSXP (1)**: Symbols/names
- **LISTSXP (2)**: Pairlists (dotted pairs)
- **CLOSXP (3)**: Closures (R functions)
- **ENVSXP (4)**: Environments
- **PROMSXP (5)**: Promises (lazy evaluation)
- **LANGSXP (6)**: Language objects (calls)
- **SPECIALSXP (7)**: Special functions (.Primitive)
- **BUILTINSXP (8)**: Built-in functions
- **CHARSXP (9)**: Scalar strings
- **LGLSXP (10)**: Logical vectors
- **INTSXP (13)**: Integer vectors
- **REALSXP (14)**: Numeric vectors (double)
- **CPLXSXP (15)**: Complex vectors
- **STRSXP (16)**: Character vectors
- **VECSXP (19)**: Lists (generic vectors)
- **EXPRSXP (20)**: Expression vectors

## Garbage Collection (memory.c)
- **Generational GC**: Objects promoted through generations
- **Tri-color marking**: White (unmarked), gray (pending), black (marked)
- **R_gc()**: Main GC entry point
- **GC triggers**: Memory threshold, explicit gc() call
- **Finalizers**: Cleanup code when objects collected

## Memory Allocation Functions
- **allocVector()**: Allocate typed vectors
- **allocList()**: Allocate pairlists
- **allocSExp()**: Low-level SEXP allocation
- **R_alloc()**: Temporary allocation (freed on context exit)
- **R_allocLD()**: Long-duration allocation
',

    evaluation = '
# R EVALUATION INTERNALS

## The Evaluation Process (eval.c)

### 1. eval() - Main Evaluator
```c
SEXP eval(SEXP e, SEXP rho)
```
- Evaluates expression `e` in environment `rho`
- Handles symbols, language objects, promises
- Returns evaluated result

### 2. Promise Evaluation (PROMSXP)
- **Lazy evaluation**: Arguments not evaluated until needed
- **Promise structure**: expr + environment + value
- **PRVALUE()**: Get promise value (evaluates if needed)
- **Force evaluation**: force() or access triggers eval

### 3. Function Calls (applyClosure)
```c
SEXP applyClosure(SEXP call, SEXP op, SEXP args, SEXP rho, SEXP suppliedvars)
```
- Creates new environment for function execution
- Matches formal arguments to actual arguments
- Evaluates function body
- Handles ... (dot-dot-dot) arguments

### 4. Argument Matching (match.c)
- **Exact matching**: Full name match
- **Partial matching**: Unique prefix
- **Positional matching**: By order
- **matchArgs()**: Main argument matcher

### 5. Context Management (context.c)
- **RCNTXT**: Execution context stack
- **Tracks**: Function calls, restarts, error handlers
- **begincontext()/endcontext()**: Push/pop contexts
- **Used for**: traceback(), debugging, error handling

## Special Evaluation Forms
- **if/else**: Conditional evaluation (only one branch)
- **for/while/repeat**: Loop constructs
- **function()**: Closure creation
- **{...}**: Sequential evaluation
- **&&, ||**: Short-circuit logical operators
',

    parser = '
# R PARSER INTERNALS

## Parser Components (gram.y, gramRd.y)

### 1. Lexical Analysis (gramlex.c)
- **Token scanning**: Converts text to tokens
- **yylex()**: Main lexer function
- **Tokens**: SYMBOL, NUM_CONST, STR_CONST, operators
- **Handles**: Comments, whitespace, line continuation

### 2. Syntax Analysis (gram.y)
- **Bison grammar**: R language syntax rules
- **Produces**: Parse tree (language objects)
- **Operator precedence**: ^, *, +, ==, &, |, ~, etc.
- **Special forms**: if, for, function, etc.

### 3. Parse Tree Structure
```r
# Parse tree for: f(x, y = 2)
LANGSXP:
  CAR: SYMSXP (f)
  CDR: LISTSXP
    CAR: SYMSXP (x)
    CDR: LISTSXP
      CAR: NUM (2)
      TAG: SYMSXP (y)
```

### 4. Parsing Functions (parse.c)
- **R_ParseVector()**: Main C parsing entry
- **parse()**: R-level parsing function
- **str2lang()**: Parse single expression
- **R_ParseEvalString()**: Parse and evaluate

## Common Parsing Issues

### 1. Operator Precedence
- **Problem**: `x^2/2` vs `x^(2/2)`
- **Solution**: Know precedence rules (^ > / > +)

### 2. Non-Standard Evaluation (NSE)
- **substitute()**: Capture unevaluated expressions
- **quote()**: Quote expressions
- **Used in**: dplyr, ggplot2 for clean syntax

### 3. Metaprogramming
- **as.call()**: Construct calls programmatically
- **bquote()**: Quasiquotation (selective evaluation)
- **rlang::expr()**: Modern metaprogramming
',

    graphics = '
# R GRAPHICS INTERNALS

## Graphics Systems

### 1. Base Graphics (src/library/graphics/)
- **C code**: plot.c, graphics.c
- **Device drivers**: Direct plotting calls
- **State-based**: par() settings persist
- **Low-level**: points(), lines(), polygon()
- **High-level**: plot(), hist(), barplot()

### 2. Grid Graphics (src/library/grid/)
- **viewport system**: Coordinate systems
- **grobs**: Graphical objects
- **ggplot2 built on grid**
- **More flexible than base**

### 3. Graphics Devices (grDevices/)
- **pdf()**: PDF device
- **png()**: PNG bitmap device
- **svg()**: SVG vector device
- **x11(), windows(), quartz()**: Screen devices
- **dev.new()**: Open new device

## Graphics Device Interface (src/include/R_ext/GraphicsDevice.h)

### Device Structure
```c
typedef struct {
    void (*activate)(pDevDesc);
    void (*circle)(double x, double y, double r, ...);
    void (*line)(double x1, double y1, double x2, double y2, ...);
    void (*polygon)(int n, double *x, double *y, ...);
    void (*rect)(double x0, double y0, double x1, double y1, ...);
    void (*text)(double x, double y, const char *str, ...);
    // ... many more functions
} DevDesc;
```

## Common Graphics Issues

### 1. Device Management
- **Multiple devices**: dev.list(), dev.cur(), dev.set()
- **Clean up**: dev.off() after saving plots
- **Plot not showing**: Check dev.cur()

### 2. Coordinate Systems
- **User coordinates**: Data space
- **Device coordinates**: Pixel/point space
- **grconvertX/Y()**: Convert between systems

### 3. Plot Margins
- **par(mar = c(bottom, left, top, right))**
- **par(oma = ...)**: Outer margins
- **Default**: c(5.1, 4.1, 4.1, 2.1) lines
',

    common_bugs = '
# COMMON R BUGS AND THEIR SOURCES

## 1. Scoping Issues (envir.c, eval.c)

### Lexical Scoping Bug
```r
f <- function() x
x <- 1
f()  # Returns 1 (lexical scoping)
```
**Source**: findVar() in envir.c - searches parent frames

### <<- Assignment Confusion
```r
f <- function() x <<- 2  # Assigns to parent env
```
**Source**: R_SetVarLocInFrame() - modifies parent environment

## 2. Subsetting Bugs (subset.c, subscript.c)

### $ Partial Matching
```r
df$na  # Might match df$names unexpectedly
```
**Source**: getAttrib() with partial matching enabled

### Negative vs Logical Indexing
```r
x[-which(x > 0)]  # Bug if which() returns integer(0)
```
**Fix**: Use x[!(x > 0)] instead

## 3. Memory Issues (memory.c)

### Growing Vectors in Loops
```r
x <- NULL
for (i in 1:10000) x <- c(x, i)  # Slow! Reallocs every time
```
**Source**: Repeated allocVector() calls, no pre-allocation

### Unprotected SEXPs in C
```c
SEXP x = allocVector(REALSXP, 1000);
// GC might collect x here!
SEXP y = allocVector(REALSXP, 1000);  // Might trigger GC
```
**Fix**: Use PROTECT(x) after allocation

## 4. Floating Point (arithmetic.c)

### Equality Comparison
```r
0.1 + 0.2 == 0.3  # FALSE! Floating point precision
```
**Fix**: Use all.equal() or abs(a - b) < tol

### Integer Overflow
```r
as.integer(2e9 + 2e9)  # NA (integer overflow)
```
**Source**: Integer max is 2^31 - 1 (2147483647)

## 5. Evaluation Issues (eval.c)

### Non-Standard Evaluation Confusion
```r
subset(df, x > 5)  # Works
col <- "x"
subset(df, col > 5)  # Doesn\'t work as expected!
```
**Source**: substitute() captures literal expression

### Missing Arguments
```r
f <- function(x) missing(x)  # Checks if x supplied
```
**Source**: PROMSXP with R_MissingArg marker

## 6. Factor Bugs (factor.c)

### Factors in Arithmetic
```r
x <- factor(c(1,2,3))
as.numeric(x)  # Returns 1,2,3 (level indices!)
```
**Fix**: as.numeric(as.character(x))

### Stringsasfactors
```r
df <- data.frame(x = letters[1:3])  # factors in old R
```
**Source**: stringsAsFactors default (changed in R 4.0)

## 7. Vectorization Issues (apply.c)

### Recycling Rule Surprises
```r
1:3 + 1:4  # Warning: longer object not multiple
```
**Source**: Implicit vector recycling in arithmetic.c

### ifelse() Type Coercion
```r
ifelse(TRUE, 1L, "a")  # Returns 1, not "1"!
```
**Source**: Type determined by first result
',

    all = NULL  # Will return all topics
  )

  if (topic == "all") {
    # Return all topics
    result <- paste(
      "\n========================================",
      "\n   R INTERPRETER INTERNALS KNOWLEDGE",
      "\n========================================\n",
      info$architecture,
      "\n", info$memory,
      "\n", info$evaluation,
      "\n", info$parser,
      "\n", info$graphics,
      "\n", info$common_bugs,
      collapse = "\n"
    )
  } else if (topic %in% names(info)) {
    result <- info[[topic]]
  } else {
    result <- sprintf("Unknown topic '%s'. Available: %s",
                      topic, paste(names(info), collapse = ", "))
  }

  return(result)
}


#' Find R Function Implementation
#'
#' Locate where a specific R function is implemented in the C source code.
#'
#' @param func_name Name of R function (e.g., "mean", "sum", "lm")
#' @return Information about where the function is implemented
#' @export
find_r_function <- function(func_name) {
  cat("Searching for implementation of:", func_name, "\n\n")

  # First search for do_funcname pattern (common for .Primitive/.Internal)
  pattern1 <- sprintf("do_%s", func_name)
  result1 <- search_r_source(pattern1, path = "main", context = 5, max_results = 20)

  # Also search for function name in FUNTAB
  result2 <- search_r_source(sprintf('"%s"', func_name), path = "main/names.c",
                              context = 2, max_results = 10)

  # Search in library for R-level implementation
  result3 <- search_r_source(sprintf("%s <-", func_name), path = "library",
                              context = 5, max_results = 10)

  results <- paste(
    "=== C Implementation (do_xxx functions) ===",
    result1,
    "\n\n=== Function Table Entry ===",
    result2,
    "\n\n=== R-level Implementation ===",
    result3,
    sep = "\n"
  )

  return(results)
}

# 🔒 Rflow Security Audit Report

**Date:** 2025-12-04
**Version Audited:** 0.9.0
**Status:** ⚠️ **Critical Issues Found - Must Fix Before v1.0**

---

## Executive Summary

Rflow has been audited for common security vulnerabilities. **One critical XSS vulnerability was identified** that must be fixed before public launch. Other security practices are generally good.

### Risk Level Summary:
- 🔴 **Critical:** 1 issue (XSS in markdown rendering)
- 🟡 **Medium:** 2 issues (temp file cleanup, error messages)
- 🟢 **Low:** 0 issues
- ✅ **Good Practices:** 5 areas

---

## 🔴 CRITICAL ISSUES (Must Fix Before Launch)

### 1. Cross-Site Scripting (XSS) Vulnerability in Markdown Rendering

**Location:** `inst/client.R:2137-2210` (render_markdown function)

**Severity:** 🔴 **CRITICAL**

**Description:**
The `render_markdown()` function does NOT escape HTML entities before processing markdown. This allows arbitrary HTML/JavaScript to be injected and executed in the browser.

**Vulnerable Code:**
```r
render_markdown <- function(text) {
  # ... processes text directly without HTML escaping ...
  text <- gsub("```r\\n([^`]+)```", "<pre><code class='language-r'>\\1</code></pre>", text)
  # ⚠️ No htmlEscape() called!
}
```

**Attack Scenario:**
1. AI response or user input contains: `<script>alert(document.cookie)</script>`
2. This gets rendered directly into the page
3. JavaScript executes, potentially stealing session data or API keys

**Proof of Concept:**
If AI includes this in a response:
```
Here's a helpful tip: <img src=x onerror="alert('XSS')">
```

It will execute JavaScript in the user's browser.

**Impact:**
- Steal API keys from browser storage
- Hijack user sessions
- Execute arbitrary code in user's browser
- Redirect users to malicious sites

**FIX REQUIRED** (See Fixes section below)

---

## 🟡 MEDIUM ISSUES (Should Fix Before v1.0)

### 2. Temp File Cleanup

**Location:** Multiple files (tool-run-r.R, start_agent.R)

**Severity:** 🟡 **MEDIUM**

**Description:**
Temporary files are created but not always cleaned up systematically:
- `start_agent.R:114` - `saveRDS(client, client_path)` - Client saved to temp
- `start_agent.R:124` - App code written to temp file
- No explicit cleanup on session end or error

**Impact:**
- Disk space consumption over time
- Potential information disclosure if temp files contain sensitive data
- May leave API key-containing objects in temp files

**Recommendation:**
Add explicit cleanup:
```r
# In stop_rflow()
on.exit({
  temp_dir <- tempdir()
  temp_files <- list.files(temp_dir, pattern = "rflow.*\\.rds$", full.names = TRUE)
  unlink(temp_files)
}, add = TRUE)
```

### 3. Information Disclosure in Error Messages

**Location:** `inst/client.R:3019` and other error handlers

**Severity:** 🟡 **MEDIUM**

**Description:**
Some error messages may expose internal system information:
- File paths in error messages
- API error details
- Stack traces in development mode

**Current Code:**
```r
"Check your ANTHROPIC_API_KEY is valid"
```

**Impact:**
- May reveal internal directory structure
- Could help attackers understand system configuration
- Minor information leakage

**Recommendation:**
- Use generic error messages for users
- Log detailed errors server-side only
- Don't expose full file paths

---

## ✅ GOOD SECURITY PRACTICES FOUND

### 1. API Key Handling ✅

**Location:** `R/setup.R:14-24`, `R/start_agent.R:33-41`

**Status:** ✅ **SECURE**

**Good Practices:**
- API key retrieved from environment variable (not hardcoded)
- Never logged to console
- Not saved to files unencrypted
- Proper error if missing

```r
api_key <- Sys.getenv("ANTHROPIC_API_KEY", "")
if (nchar(api_key) == 0) {
  stop("Claude API key not found...")
}
```

**Recommendation:** Consider adding option to use system keyring for storage:
```r
# Optional enhancement
if (requireNamespace("keyring", quietly = TRUE)) {
  api_key <- keyring::key_get("rflow", "anthropic_api")
}
```

### 2. SQL Injection Protection ✅

**Location:** `R/database.R:77-80`, `R/database.R:103-108`

**Status:** ✅ **SECURE**

**Good Practices:**
- Uses parameterized queries throughout
- Never concatenates user input into SQL
- Proper use of DBI parameter binding

```r
DBI::dbExecute(con, "
  INSERT INTO sessions (session_id, created_at, updated_at, working_dir)
  VALUES (?, ?, ?, ?)
", params = list(session_id, timestamp, timestamp, working_dir))
```

**No issues found.** ✅

### 3. File Upload Validation ✅

**Location:** `inst/client.R:1550`

**Status:** ✅ **MOSTLY SECURE**

**Good Practices:**
- File type restrictions in place
- Uses Shiny's built-in `fileInput()` with `accept` parameter
- Limited to specific extensions

```r
fileInput("fileUpload", NULL, multiple = TRUE, accept = c(
  ".xlsx", ".xls", ".csv", ".tsv", # ... specific types only
))
```

**Minor Enhancement:**
Add server-side validation to verify file types match extensions (MIME type check).

### 4. Path Traversal Protection ✅

**Location:** `inst/client.R:2271`, `inst/client.R:2306`

**Status:** ✅ **SECURE**

**Good Practices:**
- Uses `normalizePath()` to resolve paths safely
- RStudio file dialogs used (not arbitrary user input)
- Checks `file.exists()` and `dir.exists()` before operations

```r
folder_path <- normalizePath(folder_path, winslash = "/")
if (!is.null(file_path) && file.exists(file_path)) {
  file_path <- normalizePath(file_path, winslash = "/")
}
```

**No issues found.** ✅

### 5. No Hardcoded Credentials ✅

**Status:** ✅ **SECURE**

**Audit Results:**
- No hardcoded API keys found
- No hardcoded passwords found
- No embedded secrets in code
- All sensitive data from environment variables

---

## 🛠️ REQUIRED FIXES

### Fix #1: XSS Prevention in Markdown Rendering (CRITICAL)

**File:** `inst/client.R`

**Action:** Add HTML escaping before markdown processing

**Current Code:**
```r
render_markdown <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")
  tryCatch({
    # Handle code blocks first (```...```)
    text <- gsub("```r\\n([^`]+)```", "<pre><code class='language-r'>\\1</code></pre>", text)
    # ... rest of processing ...
```

**Fixed Code:**
```r
render_markdown <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")

  tryCatch({
    # SECURITY FIX: Escape HTML first to prevent XSS
    # Extract code blocks BEFORE escaping (they should remain intact)
    code_blocks <- list()
    code_counter <- 0

    # Extract and temporarily replace code blocks
    text <- gsub("```r?\\n([^`]+)```", function(match) {
      code_counter <<- code_counter + 1
      code_blocks[[code_counter]] <<- match
      paste0("__CODE_BLOCK_", code_counter, "__")
    }, text, perl = TRUE)

    # NOW escape HTML entities in the remaining text
    text <- htmltools::htmlEscape(text)

    # Restore code blocks (which are already safe)
    for (i in seq_along(code_blocks)) {
      placeholder <- paste0("__CODE_BLOCK_", i, "__")
      # Process the code block for markdown
      code_content <- gsub("```r?\\n([^`]+)```", "\\1", code_blocks[[i]])
      code_html <- paste0("<pre><code class='language-r'>",
                          htmltools::htmlEscape(code_content),
                          "</code></pre>")
      text <- sub(placeholder, code_html, text, fixed = TRUE)
    }

    # NOW continue with markdown processing (headers, lists, etc.)
    lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
    # ... rest of processing ...
```

**Alternative (Simpler):**
Use a proper markdown library like `markdown` or `commonmark`:
```r
render_markdown <- function(text) {
  if (requireNamespace("commonmark", quietly = TRUE)) {
    # commonmark properly escapes HTML by default
    html <- commonmark::markdown_html(text, extensions = TRUE)
    return(html)
  } else {
    # Fallback: at minimum, escape HTML
    return(htmltools::htmlEscape(text))
  }
}
```

### Fix #2: Add Temp File Cleanup

**File:** `R/start_agent.R`

**Action:** Add cleanup function

**Add This Function:**
```r
#' Clean up Rflow temp files
#' @keywords internal
cleanup_rflow_temp <- function() {
  temp_dir <- tempdir()

  # Clean up client files
  client_files <- list.files(temp_dir, pattern = "^rflow.*\\.rds$", full.names = TRUE)
  unlink(client_files)

  # Clean up app files
  app_files <- list.files(temp_dir, pattern = "^file[0-9]+\\.R$", full.names = TRUE)
  unlink(app_files)

  # Clean up HTML temp files
  html_files <- list.files(temp_dir, pattern = "^file[0-9]+\\.html$", full.names = TRUE)
  unlink(html_files)

  invisible(TRUE)
}
```

**Modify stop_rflow():**
```r
#' @export
stop_rflow <- function() {
  # ... existing code ...

  # Clean up temp files
  cleanup_rflow_temp()

  cli::cli_alert_success("Rflow stopped successfully")
}
```

---

## 📋 Security Checklist for v1.0 Launch

### Before Launch:
- [ ] **CRITICAL:** Fix XSS vulnerability in markdown rendering
- [ ] Add temp file cleanup
- [ ] Review all error messages for information disclosure
- [ ] Add server-side file type validation
- [ ] Test with malicious inputs (XSS payloads)
- [ ] Run security scan: `goodpractice::gp()`
- [ ] Review all `HTML()` calls in Shiny UI
- [ ] Check for any console.log() that might leak data
- [ ] Verify API keys never logged
- [ ] Test error scenarios don't expose internal paths

### Post-Launch:
- [ ] Set up security disclosure policy
- [ ] Add SECURITY.md file
- [ ] Monitor for security issues
- [ ] Keep dependencies updated
- [ ] Regular security audits

---

## 🔍 Testing Recommendations

### XSS Testing:
Test these payloads in chat:
```
1. <script>alert('XSS')</script>
2. <img src=x onerror="alert('XSS')">
3. <svg onload="alert('XSS')">
4. javascript:alert('XSS')
5. <iframe src="javascript:alert('XSS')">
```

All should be rendered as text, not executed.

### SQL Injection Testing:
Test these in file names/paths:
```
1. test'; DROP TABLE sessions; --
2. test' OR '1'='1
3. ../../../etc/passwd
```

All should be handled safely (already are).

### File Upload Testing:
Try uploading:
```
1. .exe files (should be rejected)
2. .php files (should be rejected)
3. Files with no extension
4. Very large files (>100MB)
5. Files with special characters in names
```

---

## 📚 Security Resources

### For Users:
- Never share your API key
- Use environment variables, not code, for API keys
- Review code before running AI-generated commands
- Keep Rflow updated

### For Developers:
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- R Package Security: https://r-pkgs.org/security.html
- Shiny Security: https://shiny.rstudio.com/articles/security.html

---

## 📝 Security Policy

### Reporting Security Issues:
Create a security issue template:
1. **DO NOT** open public GitHub issues for security vulnerabilities
2. Email: security@your-domain.com (or your email)
3. Include: Description, reproduction steps, impact
4. Response time: 48 hours
5. Fix timeline: 7 days for critical, 30 days for medium

---

## ✅ Conclusion

**Overall Assessment:** Rflow has good security practices in most areas, but **ONE CRITICAL XSS vulnerability MUST be fixed before v1.0 launch**.

**Action Items Priority:**
1. **CRITICAL (Do Now):** Fix XSS in markdown rendering
2. **HIGH (Before v1.0):** Add temp file cleanup
3. **MEDIUM (Before v1.0):** Review error messages
4. **LOW (Nice to have):** Add server-side file validation

**Recommendation:** **DO NOT launch v1.0** until the XSS vulnerability is fixed. After the fix:
- Re-test thoroughly
- Consider security review by another developer
- Add XSS tests to test suite

The codebase shows good security awareness overall. Fixing the XSS issue will make Rflow safe for public use.

---

**Report Prepared By:** Claude Code Security Audit
**Date:** 2025-12-04
**Next Review:** After XSS fix, then quarterly

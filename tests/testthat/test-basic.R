test_that("Package loads successfully", {
  expect_true("Rflow" %in% loadedNamespaces())
})

test_that("Main functions are exported", {
  expect_true(exists("start_rflow"))
  expect_true(exists("stop_rflow"))
})

test_that("start_rflow requires RStudio and API key", {
  # Skip if not in RStudio (tests run in R CMD check don't have RStudio)
  skip_if_not(rstudioapi::isAvailable(), "RStudio not available")

  # Temporarily unset API key
  old_key <- Sys.getenv("ANTHROPIC_API_KEY")
  Sys.setenv(ANTHROPIC_API_KEY = "")

  # Should fail without API key
  expect_error(start_rflow(), "API key not found")

  # Restore API key
  Sys.setenv(ANTHROPIC_API_KEY = old_key)
})

test_that("Viewer functions exist", {
  expect_true(exists("is_rflow_viewer_active"))
  expect_true(exists("open_in_browser"))
})

test_that("Workspace functions exist", {
  expect_true(exists("get_workspace_summary"))
  expect_true(exists("workspace_status"))
  expect_true(exists("clear_workspace"))
})

test_that("R internals functions exist", {
  expect_true(exists("search_r_source"))
  expect_true(exists("get_r_internals_info"))
  expect_true(exists("find_r_function"))
})

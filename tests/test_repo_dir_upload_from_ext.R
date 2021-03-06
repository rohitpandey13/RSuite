#----------------------------------------------------------------------------
# RSuite
# Copyright (c) 2017, WLOG Solutions
#----------------------------------------------------------------------------
context("Testing if uploading external packages into directory works properly [test_repo_dir_upload_from_ext]")

library(RSuite)
library(testthat)

source("R/test_utils.R")
source("R/project_management.R")
source("R/repo_management.R")


test_that_managed("Uploading external packages (basic)", {
  prj <- init_test_project(repo_adapters = c("Dir"))  # uses BaseTestProjectTemplate with logging 0.7-103
  mgr <- init_test_manager(prj)

  RSuite::repo_upload_ext_packages(mgr$repo_mgr, pkgs = "logging", prj = prj, pkg_type = "source")

  expect_that_packages_available("logging", "source", mgr)
})

test_that_managed("Uploading external packages (with deps)", {
  prj <- init_test_project(repo_adapters = c("Dir"))  # uses BaseTestProjectTemplate with logging 0.7-103
  mgr <- init_test_manager(prj)

  create_package_deploy_to_lrepo("TestPackage", prj, type = "source")

  RSuite::repo_upload_ext_packages(mgr$repo_mgr, pkgs = "TestPackage", prj = prj, pkg_type = "source",
                                   with_deps = TRUE)

  expect_that_packages_available(c("logging", "TestPackage"), "source", mgr)
})

test_that_managed("Uploading external packages (withr - building source cannot rebuild docs)", {
  prj <- init_test_project(repo_adapters = c("Url[https://cran.rstudio.com/]"))
  bin_type <- prj$load_params()$bin_pkgs_type

  mgr <- init_test_manager(prj)

  RSuite::repo_upload_ext_packages(mgr$repo_mgr, pkgs = "withr", prj = prj, pkg_type = bin_type)

  expect_that_packages_available("withr", bin_type, mgr)
})

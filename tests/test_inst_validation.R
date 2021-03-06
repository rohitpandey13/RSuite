#----------------------------------------------------------------------------
# RSuite
# Copyright (c) 2017, WLOG Solutions
#----------------------------------------------------------------------------
context("Testing if package install validations works properly [test_inst_validation]")

library(RSuite)
library(testthat)

source("R/test_utils.R")
source("R/project_management.R")


test_that_managed("Post-install R version check works", {
  skip_if_not(.Platform$pkgType == "win.binary")
  skip_if_not(RSuite:::current_rver() == "3.4")
  skip_if(httr::http_error("https://mran.microsoft.com/snapshot/2017-01-08/bin/windows/contrib/3.4/colorspace_1.3-2.zip"))

  prj <- init_test_project(repo_adapters = c("Dir", "MRAN[2017-01-08]")) # uses BaseTestProjectTemplate with logging 0.7-103

  # prj_config_set_rversion("3.4", prj = prj)
  create_test_master_script(prj = prj, code = "library(colorspace)")

  expect_error(prj_install_deps(prj = prj),
               "Failed to install some dependencies: colorspace")

  # colorspace is not installed because it was built for R 3.3.2
  expect_that_packages_installed(c("logging"), prj)
})

test_that_managed("Post building docs imports in NAMESPACE shoud get fixed", {
  prj <- init_test_project(repo_adapters = "Dir") # uses BaseTestProjectTemplate with logging 0.7-103
  create_package_deploy_to_lrepo(name = "TestPackage1", prj = prj)

  create_test_package("TestPackage2", prj, imps = "logging, TestPackage1")

  RSuite::prj_install_deps(prj)
  expect_that_packages_installed(c("logging", "TestPackage1"), prj)

  RSuite::prj_build(prj = prj)
  expect_that_packages_installed(c("logging", "TestPackage1", "TestPackage2"), prj)
})

test_that_managed("Post building docs declared imports should confirm to NAMESPACE", {
  prj <- init_test_project(repo_adapters = "Dir")  # uses BaseTestProjectTemplate with logging 0.7-103

  create_test_package("TestPackage1", prj)
  set_test_package_ns_imports("TestPackage1", prj, c("logging", "TestPackage"))

  RSuite::prj_install_deps(prj)
  expect_that_packages_installed(c("logging"), prj) # dependency to TestPackage1 is detected base on DESCRIPTION

  expect_error(RSuite::prj_build(prj = prj), "Failed to install .*: TestPackage1")
})

test_that_managed("Post building docs declared imports should handle names with . properly", {
  prj <- init_test_project(repo_adapters = "Dir")  # uses BaseTestProjectTemplate with logging 0.7-103
  create_package_deploy_to_lrepo(name = "Package.With.Dot.In.Name", prj)

  create_test_package("TestPackage", prj, imps = "Package.With.Dot.In.Name")
  set_test_package_ns_imports("TestPackage", prj, c("Package.With.Dot.In.Name"))

  RSuite::prj_install_deps(prj)
  expect_that_packages_installed(c("logging", "Package.With.Dot.In.Name"), prj)

  RSuite::prj_build(prj = prj)
  expect_that_packages_installed(c("logging", "TestPackage", "Package.With.Dot.In.Name"), prj)
})

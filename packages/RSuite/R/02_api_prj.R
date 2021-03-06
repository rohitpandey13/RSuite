#----------------------------------------------------------------------------#
# RSuite
# Copyright (c) 2017, WLOG Solutions
#
# Package API related to projects.
#----------------------------------------------------------------------------#

#'
#' Bind to rstudio project creation menu. Creates an R Suite project.
#' This function will be called when the user invokes the New Project
#' wizard using the project template defined in the template file at:
#'
#'  inst/rstudio/templates/project/rsuite_project.dcf
#'
#'
#' @keywords internal
#' @noRd
rstudio_prj_start <- function(path, ...) {
  # collect arguments
  name <- basename(path)
  path <- dirname(path)
  args <- list(...)

  # create project
  prj_start(name = name, path = path, skip_rc = args$skip_rc)
}

#'
#' Detect project base dir in parents of path.
#'
#' @keywords internal
#' @noRd
#'
detect_prj_path <- function(path) {
  stopifnot(is.character(path) && length(path) == 1)
  stopifnot(dir.exists(path))

  prj_path <- normalizePath(path)
  while (!file.exists(file.path(prj_path, "PARAMETERS"))) {
    parent_path <- dirname(prj_path)
    assert(parent_path != prj_path, "Failed to detect project base folder from %s", path)
    prj_path <- parent_path
  }

  return(prj_path)
}

#'
#' Validates if prj is project.
#' If prj is NULL tries initilize project at working dir.
#' If fails tries loaded project.
#' If no loaded project asserts that could not detect project out of context.
#'
#' @keywords internal
#' @noRd
#'
safe_get_prj <- function(prj, prj_param_name = "prj") {
  assert(is.null(prj) || is_prj(prj),
         "Project(rsuite_project object) expected as %s", prj_param_name)

  if (!is.null(prj)) {
    return(prj)
  }
  prj <- tryCatch({
    prj_init()
  },
  error = function(e) {
    NULL
  })

  if (!is.null(prj)) {
    return(prj)
  }
  prj <- get_loaded_prj()
  if (!is.null(prj)) {
    return(prj)
  }

  assert(!is.null(prj), "Could not detect project out of context")
  return(prj)
}

#'
#' Checks if object is rsuite project.
#'
#' @param prj object to check for beeing rsuite project.
#' @return TRUE if prj is rsuite project.
#'
#' @keywords internal
#' @noRd
#'
is_prj <- function(prj) {
  class(prj) == "rsuite_project"
}


#'
#' Loads project settings without loading them into the environment.
#'
#' @details
#' Project parameters are searched and loaded. If the project has been loaded
#' previously from the path the same project instance will be used without
#' reloading.
#'
#' If the project is the first one loaded it will become the default project (used then
#' NULL is passed as the project for project management functions).
#'
#' @param path path to start searching project base folder from. Search is
#'   performed upwards folder structure. Should be existing directory.
#'   (type: character, default: getwd())
#' @return object of type rsuite_project
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' # init project
#' prj <- prj_init(path = file.path(prj_base, "my_project"))
#'
#' @export
#'
prj_init <- function(path = getwd()) {
  assert(is.character(path) && length(path) == 1,
         "character(1) expected for path parameter")
  assert(dir.exists(path),
         "Existing directory path is expected for path parameter")

  prj_path <- detect_prj_path(path)

  prj <- find_prj(prj_path)
  if (!is.null(prj)) {
    return(prj)
  }

  prj <- list(
    load_params = function() {
      assert(dir.exists(prj_path), "Project folder seems to be gone: %s", prj_path)
      load_prj_parameters(prj_path)
    },
    path = prj_path
  )
  class(prj) <- "rsuite_project"

  prj <- register_prj(prj)
  invisible(prj)
}

#'
#' Creates project structure at the specified path.
#'
#' @details
#' The project is not loaded, just created.
#'
#' If name passed folder under such name will be created and project structure
#' will be placed under it. If not passed folder under path will contain project
#' structure and project name will be assumed to be basename of the path.
#'
#' Logs all messages from the building process onto the rsuite logger. Use \code{logging::setLevel}
#' to control logs verbosity. DEBUG level turns on building and downloading messages.
#'
#' Project templates have to include a PARAMETERS file
#'
#' @param name name of the project to create. It must not contain special characters
#'   like \\/\"\'<> otherwise project folder could not be created. It can be NULL.
#'   If so project will be created at path directly with the name of the first folder.
#'   (type: character).
#' @param path path to the folder where project structure should be created.
#' @param skip_rc if TRUE skip adding project under revision control.
#'   (type: logical, default: FALSE)
#' @param tmpl name of the project template (or path to it) to use for project
#'   structure  creation.
#'   (type: character).
#'
#' @return rsuite_project object for the project just created.
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' @export
#'
prj_start <- function(name = NULL, path = getwd(), skip_rc = FALSE, tmpl = "builtin") {
  assert(is.character(path) && length(path) == 1, "character(1) expected for path")
  assert(dir.exists(path), "Directory %s does not exists", path)
  assert(is.logical(skip_rc), "logical(1) expected for skip_rc")

  if (is.null(name)) {
    assert(dirname(path) != path, "Cannot create project at root directory")
    prj_dir <- path
  } else {
    assert(is.character(name) && length(name) == 1 && nchar(name) > 0,
           "non empty character(1) expected for name")
    assert(!grepl("[\\/\"\'<>]+", name),
           "Invalid project name %s. It must not contain special characters", name)
    prj_dir <- file.path(path, name)
  }

  create_project_structure(prj_dir, tmpl) # from 14_setup_structure.R
  check_project_structure(prj_dir) # from 14_setup_structure.R

  pkg_loginfo("Project %s started.", basename(prj_dir))

  prj <- prj_init(path = prj_dir)

  if (!skip_rc) {
    rc_adapter <- detect_rc_adapter(prj_dir)
    if (is.null(rc_adapter)) {
      git2r::init(prj_dir) # initilize local Git repo
      pkg_loginfo("Local GIT repository created for the project")
      rc_adapter <- detect_rc_adapter(prj_dir)
    }

    if (!is.null(rc_adapter)) {
      pkg_loginfo("Puting project %s under %s control ...", basename(prj_dir), rc_adapter$name)
      rc_adapter_prj_struct_add(rc_adapter, prj$load_params())
      pkg_loginfo("... done")
    } else {
      pkg_logwarn("Failed to detect RC manager for %s", basename(prj_dir))
      clear_rc_adapter_infos(prj_dir) # from 14_setup_structure.R
    }
  } else {
    clear_rc_adapter_infos(prj_dir) # from 14_setup_structure.R
  }

  invisible(prj)
}

#'
#' Creates package structure inside the project.
#'
#' @details
#' It fails if the package exists already in the project.
#'
#' Logs all messages from the building process onto the rsuite logger. Use \code{logging::setLevel}
#' to control logs verbosity. DEBUG level turns on building and downloading messages.
#'
#' Package templates have to include the following files: DESCRIPTION, NAMESPACE, NEWS
#'
#' @param name name of the package to create. It must not contain special characters
#'    like \\/\"\'<> otherwise package folder could not be created. It must not
#'    contain _ also as it is requirement enforced on R package names. The folder
#'    must not exist.
#'    (type: character).
#' @param prj project object to create the package in. If not passed will init
#'    project from working directory. (type: rsuite_project, default: NULL)
#' @param skip_rc if TRUE skip adding package under revision control.
#'    (type: logical, default: FALSE)
#' @param tmpl name of the package template (or path to it) to use for package
#'    structure  creation.
#'    (type: character).
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' # start package in it
#' prj_start_package("mypackage", prj = prj, skip_rc = TRUE)
#'
#' @export
#'
prj_start_package <- function(name,
                              prj = NULL,
                              skip_rc = FALSE,
                              tmpl = "builtin") {
  assert(!is.null(name) && is.character(name) && length(name) == 1 && nchar(name) > 0,
         "Non empty character(1) required for name")
  assert(!grepl("[\\/\"\'<>_]+", name),
         "Invalid package name %s. It must not contain special characters or underscore", name)
  prj <- safe_get_prj(prj)

  params <- prj$load_params()
  pkg_dir <- file.path(params$pkgs_path, name)

  assert(!dir.exists(pkg_dir), "Package folder exists already: %s", pkg_dir)

  create_package_structure(pkg_dir, tmpl) # from 14_setup_structure.R

  pkg_loginfo("Package %s started in project %s.", name, params$project)

  if (!skip_rc) {
    rc_adapter <- detect_rc_adapter(pkg_dir)
    if (!is.null(rc_adapter)) {
      pkg_loginfo("Puting package %s under %s control ...", name, rc_adapter$name)
      rc_adapter_pkg_struct_add(rc_adapter, params, name)
      pkg_loginfo("... done")
    } else {
      pkg_logwarn("Failed to detect RC manager for %s", name)
      clear_rc_adapter_infos(pkg_dir) # from 14_setup_structure.R
    }
  } else {
    clear_rc_adapter_infos(pkg_dir) # from 14_setup_structure.R
  }
}


#'
#' Loads project into the environment so all master scripts can run.
#'
#' It changes \code{.libPaths()} so project internal environment is visible
#' for R. Use \code{\link{prj_unload}} to restore your environment.
#'
#' @param prj project to load or NULL to use path for new project
#'   initialization. If not path passed project will be initialized from working
#'   folder. (type: rsuite_project, default: NULL)
#' @param path if prj is NULL, the path will be used to init new project to load.
#'   If passed must be existing folder path. (type: character)
#'
#' @return previously loaded project or NULL if no project has been loaded.
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' cat(.libPaths(), sep = "\n") # show inital contents of .libPaths()
#'
#' prj_load(prj = prj) # load project
#' cat(.libPaths(), sep = "\n") # show contents of .libPaths()
#'
#' prj_unload() # restore environment
#' cat(.libPaths(), sep = "\n") # show final contents of .libPaths()
#'
#' @export
#'
prj_load <- function(path, prj = NULL) {
  if (!is.null(prj)) {
    assert(is_prj(prj), "Project(rsuite_project object) expected for prj")
  } else if (missing(path)) {
    prj <- prj_init(path = getwd())
  } else {
    assert(is.character(path) && length(path) == 1,
           "character(1) expected for path parameter")
    assert(dir.exists(path),
           "Existing directory path is expected for path parameter")

    prj_path <- detect_prj_path(path)
    prj <- find_prj(prj_path)
    if (is.null(prj)) {
      prj <- prj_init(path)
    }
  }

  stopifnot(!is.null(prj) && is_prj(prj))

  params <- prj$load_params()
  prev_prj <- set_loaded_prj(prj)

  cur_lpath <- .libPaths()
  cur_lpath <- cur_lpath[!grepl("[\\/]deployment[\\/](libs|sbox)[\\/]?$", cur_lpath)]

  .libPaths(c(params$sbox_path, params$lib_path, cur_lpath))

  invisible(prev_prj)
}

#'
#' Unloads last loaded project.
#'
#' It changes \code{.libPaths()} removing all references to currently loaded
#' project internal environment.
#'
#' @return Project unloaded or NULL if there was no project to unload.
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' cat(.libPaths(), sep = "\n") # show inital contents of .libPaths()
#'
#' prj_load(prj = prj) # load project
#' cat(.libPaths(), sep = "\n") # show contents of .libPaths()
#'
#' prj_unload() # restore environment
#' cat(.libPaths(), sep = "\n") # show final contents of .libPaths()
#'
#' @export
#'
prj_unload <- function() {
  prev_prj <- set_loaded_prj(NULL)

  cur_lpath <- .libPaths()
  cur_lpath <- cur_lpath[!grepl("[\\/]deployment[\\/](libs|sbox)[\\/]?$", cur_lpath)]
  .libPaths(cur_lpath)

  invisible(prev_prj)
}


#'
#' Installs project dependencies and needed supportive packages.
#'
#' @details
#' Logs all messages from the building process onto the rsuite logger. Use
#' \code{logging::setLevel} to control logs verbosity. DEBUG level turns
#' on building and downloading messages.
#'
#' @param prj project to collect dependencies for if not passed will build
#'    project for working directory. (type: rsuite_project, default: NULL)
#' @param clean if TRUE clear environment before installing package dependencies.
#'   (type: logical, default: FALSE)
#' @param sups specifies which supportive packages should be installed. One of
#' \describe{
#'  \item{none}{Do not install supportive packages}
#'  \item{vanilla}{Install only base supportive packages(like devtools & roxygen2)}
#'  \item{all}{Install all packages in suggests}
#'  }
#'  (type: character(1), default: all)
#' @param relock if TRUE allows updating the env.lock file
#'   (type: logical, default: FALSE)
#'
#' @return TRUE if all build successfully.
#'
#' @family in project management
#'
#' @examples
#' \donttest{
#'   # create exemplary project base folder
#'   prj_base <- tempfile("example_")
#'   dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#'   # start project
#'   prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#'   # reinstall logging package into project environment
#'   prj_install_deps(prj = prj, clean = TRUE)
#' }
#'
#' @export
#'
prj_install_deps <- function(prj = NULL,
                             clean = FALSE,
                             sups = "all",
                             relock = FALSE) {
  assert(is.character(sups) && length(sups) == 1, "character(1) expected for 'sups'")
  assert(sups %in% c("none", "vanilla", "all"), "One of none,vanilla,all expected for 'sups'")

  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))

  params <- prj$load_params()
  get_rscript_path(params$r_ver) # from 97_rversion.R; ensure R version is available

  prev_library <- .Library
  prev_lpath <- .libPaths()
  on.exit({
    .Library <- prev_library
    .libPaths(prev_lpath)
  })
  .libPaths(params$lib_path)
  .Library <- NULL

  if (clean) {
    pkg_loginfo("Cleaning up local environment...")
    unlink(file.path(params$lib_path, "*"), recursive = TRUE, force = TRUE)
    pkg_loginfo("Cleaning up local environment... done")
  }

  install_prj_deps(params, # from 11_install_prj_deps.R
                   sups = sups,
                   relock = relock)
}

#'
#' Uninstalls unused packages from the local project environment.
#'
#' Checks if all dependencies installed are required by project packages or
#' master scripts and removes those which are not required any more.
#'
#' @details
#' Logs all messages from the building process onto the rsuite logger. Use \code{logging::setLevel}
#' to control logs verbosity. DEBUG level turns on building and downloading messages.
#'
#' @param prj project to clean dependencies of. If not passed will use the project
#'    base in the working directory. (type: rsuite_project, default: NULL)
#'
#' @family in project management
#'
#' @examples
#' \donttest{
#'   # create exemplary project base folder
#'   prj_base <- tempfile("example_")
#'   dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#'   # start project
#'   prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#'   # add colorspace to master script
#'   master_script_fpath <- file.path(prj$path, "R", "master.R")
#'   write("library(colorspace)", file = master_script_fpath, append = TRUE)
#'
#'   # install colorspace into project local environment
#'   prj_install_deps(prj = prj)
#'
#'   # remove dependency to colorspace
#'   writeLines(head(readLines(master_script_fpath), n = -1),
#'              con = master_script_fpath)
#'
#'   # uninstall colorspace from project local environment
#'   prj_clean_deps(prj = prj)
#' }
#'
#' @export
#'
prj_clean_deps <- function(prj = NULL) {
  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))

  params <- prj$load_params()
  get_rscript_path(params$r_ver) # from 97_rversion.R; ensure R version is available

  clean_prj_deps(params) # from 11_install_prj_deps.R
}


#'
#' Builds project internal packages and installs them.
#'
#' @details
#' Logs all messages from the building process onto the rsuite logger. Use
#' \code{logging::setLevel} to control logs verbosity. DEBUG level turns
#' on building and downloading messages.
#'
#' @param prj project to build if not passed will build project for working
#'    directory. (type: rsuite_project, default: NULL)
#' @param type type of packages to build. If NULL will build platform default.
#'    (type: character)
#' @param rebuild if TRUE will force rebuild all project packages event if no
#'    changes detected (type: logical)
#' @param vignettes if FALSE will not build vignettes which can highly decrease
#'    package building time (type: logical, default: TRUE)
#' @param tag if TRUE will tag packages with RC revision. Enforces rebuild.
#'   (type: logical; default: FALSE)
#'
#' @family in project management
#'
#' @examples
#' \donttest{
#'   # create exemplary project base folder
#'   prj_base <- tempfile("example_")
#'   dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#'   # start project
#'   prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#'   # create package in the project
#'   prj_start_package("mypackage", prj = prj, skip_rc = TRUE)
#'
#'   # build project local environment
#'   prj_install_deps(prj = prj)
#'
#'   # build mypackage and install it into project environment
#'   prj_build(prj = prj)
#' }
#'
#' @export
#'
prj_build <- function(prj = NULL, type = NULL, rebuild = FALSE, vignettes = TRUE, tag = FALSE) {
  assert(is.logical(rebuild), "logical expected for rebuild")
  assert(is.logical(vignettes), "logical expected for vignettes")
  assert(is.logical(tag), "logical expected for tag")

  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))

  params <- prj$load_params()
  get_rscript_path(params$r_ver) # from 97_rversion.R; ensure R version is available

  if (is.null(type)) {
    type <- params$pkgs_type
  }

  skip_build_steps <- NULL
  if (!any(vignettes)) {
    skip_build_steps <- "vignettes"
  }

  revision <- NULL
  if (any(tag)) {
    ver_info <- detect_zip_version(params, NULL) # from 15_zip_project.R
    revision <- ver_info$rev
    rebuild <- TRUE
  }
  build_install_tagged_prj_packages(params, # from 12_build_install_prj_pacakges.R
                                    revision = revision,
                                    build_type = type,
                                    rebuild = rebuild,
                                    skip_build_steps = skip_build_steps)
}

#'
#' Prepares deployment zip tagged with version.
#'
#' It collects all dependencies and project packages installed in local project
#' environment together with master scripts and artifacts and zips them into
#' a single zip file.
#'
#' @details
#' Zip package generated is stamped with version. It can be enforced with zip_ver
#' parameter (zip will have suffix <zip_ver>x in the case). If the version is not
#' enforced it is detected out of ZipVersion setting in project PARAMETERS file or
#' from the maximal project packages version number. In that case, revision number is
#' appended to version: version number will be <zip_ver>_<rc_ver>. Check for
#' changes in project sources is performed for zip package consistency.
#'
#' Before building zip package project is built. If revision number detected
#' project packages will have version altered: revision will be added as least
#' number to package version.
#'
#' Logs all messages from the building process onto rsuite logger. Use \code{logging::setLevel}
#' to control logs verbosity. DEBUG level turns on building and downloading messages.
#'
#' @param prj project object to zip. if not passed will zip the loaded project or
#'    the default whichever exists. Will init default project from the working
#'    directory if no default project exists. (type: rsuite_project, default: NULL)
#' @param path folder path to put output zip into. If the folder does not exist, will
#'    create it. (type: character: default: \code{getwd()})
#' @param zip_ver if passed enforce the version of the zip package to the passed value.
#'    Expected form of version is DD.DD. (type: character, default: NULL)
#'
#' @return invisible file path to pack file created. The file name will be
#'    in form <ProjectName>_<version>.zip
#
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' # build deployment zip
#' zip_fpath <- prj_zip(prj = prj, path = tempdir(), zip_ver = "1.0")
#'
#' @export
#'
prj_zip <- function(prj = NULL, path = getwd(), zip_ver = NULL) {
  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))

  params <- prj$load_params()
  get_rscript_path(params$r_ver) # from 97_rversion.R; ensure R version is available

  # Check if environment is locked
  if (!file.exists(params$lock_path)) {
    pkg_logwarn("Project environment is not locked!")
  }

  ver_inf <- detect_zip_version(params, zip_ver) # from 15_zip_project.R
  build_install_tagged_prj_packages(params, # from 12_build_install_prj_pacakges.R
                                    ver_inf$rev,
                                    params$pkgs_type,
                                    rebuild = TRUE)

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  zip_fpath <- zip_project(params, ver_inf$ver, path) # from 15_zip_project.R
  return(invisible(zip_fpath))
}


#'
#' Prepares project source pack tagged with version.
#'
#' It collects all sources and assemblies found in the project folder and packs them
#' into a single zip file.
#'
#' @details
#' The function is heavily used for building projects for alternative environments
#' (like in docker).
#'
#' Pack generated is stamped with version. It can be enforced with pack_ver
#' parameter (zip will have suffix <pack_ver>x in the case). If the version is not
#' enforced it is detected out of ZipVersion setting in project PARAMETERS file or
#' from the maximal project packages version number. In that case, the revision number
#' is appended to version: version number will be <ZipVersion>_<rc_ver>. Check for
#' changes in project sources is performed for pack consistency. The resulted pack
#' is marked with the version detected so while building zip after unpacking will
#' have the same version as the original project.
#'
#' Before building pack project packages will have version altered: revision will
#' be added as the least number to package version.
#'
#' Logs all messages onto rsuite logger. Use \code{logging::setLevel} to control
#' logs verbosity.
#'
#' @param prj project object to pack. if not passed the loaded project will be packed or
#'    the default whichever exists. Will init default project from the working
#'    directory if no default project exists. (type: rsuite_project, default: NULL)
#' @param path folder path to put output pack into. The folder must exist.
#'    (type: character(1), default: \code{getwd()})
#' @param pkgs names of packages to include in the pack. If NULL will include all
#'    project packages (type: character, default: NULL)
#' @param inc_master if TRUE will include master scripts in the pack.
#'    (type: logical(1), default: TRUE)
#' @param pack_ver if passed enforce the version of the pack to the passed value.
#'    Expected form of version is DD.DD. (type: character(1), default: NULL)
#' @param rver if passed enforce destination R version of the pack.
#'    (type: character(1), default: NULL)
#'
#' @return invisible file path to pack file created. The file name will be
#'    in form prjpack_<ProjectName>_<version>.zip
#'
#' @family in project management
#'
#' @examples
#' # create exemplary project base folder
#' prj_base <- tempfile("example_")
#' dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#' # start project
#' prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#' # create package in the project
#' prj_start_package("mypackage", prj = prj, skip_rc = TRUE)
#'
#' # build project source pack
#' pack_fpath <- prj_pack(prj = prj, path = tempdir(), pack_ver = "1.0")
#'
#' @export
#'
prj_pack <- function(prj = NULL, path = getwd(),
                     pkgs = NULL, inc_master = TRUE,
                     pack_ver = NULL,
                     rver = NULL) {
  assert(dir.exists(path), "Existing folder expected for path")
  assert(is.logical(inc_master), "Logical value expected for inc_master")
  assert(is.null(pack_ver) || is_nonempty_char1(pack_ver),
         "Non empty character(1) expected for pack_ver")
  assert(is.null(rver) || (is.character(rver) && length(rver) == 1),
         "character(1) expected for rver")

  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))

  params <- prj$load_params()
  # no need to check R version here. We will not build anything

  # Check if project environment is locked
  if (!file.exists(params$lock_path)) {
    pkg_logwarn("Project environment is not locked!")
  }

  prj_packages <- build_project_pkgslist(params$pkgs_path) # from 51_pkg_info.R
  if (is.null(pkgs)) {
    pkgs <- prj_packages
  } else {
    assert(all(pkgs %in% prj_packages),
           sprintf("Some packages requiested to include not found in project: %s",
                   paste(setdiff(pkgs, prj_packages), collapse = ", ")))
    pkgs <- prj_packages[prj_packages == pkgs]
  }

  if (!is.null(pack_ver) && grepl("^_\\d+$", pack_ver)) {
    # pack_ver contains only pack_rev enforcement
    ver_inf <- detect_zip_version(params, # from 15_zip_project.R
                                  zip_ver = NULL,
                                  zip_rev = gsub("_", "", pack_ver))
  } else {
    ver_inf <- detect_zip_version(params,  # from 15_zip_project.R
                                  zip_ver = pack_ver,
                                  zip_rev = NULL) # no revision enforcement
  }

  tmp_dir <- tempfile("pkgpack_")
  on.exit({
      unlink(tmp_dir, recursive = TRUE, force = TRUE)
  },
  add = TRUE)

  exp_params <- export_prj(params, # from 19_pack_helpers.R
                           rver,
                           pkgs,
                           inc_master,
                           tmp_dir)
  assert(!is.null(exp_params), "Failed to create project export")

  create_prjinfo(exp_params, ver_inf) # from 19_pack_helpers.R

  prj_name <- gsub("[\\/\"\'<>]+", "_", params$project)
  pack_fpath <- file.path(rsuite_fullUnifiedPath(path),
                          sprintf("prjpack_%s_%s.zip", prj_name, ver_inf$ver))

  success <- zip_folder(wspace = tmp_dir, zip_file_path = pack_fpath) # from 15_zip_project.R
  assert(success, "Failed to create pack file (zip returned non 0 return status).")

  invisible(pack_fpath)
}

#'
#' Locks the project environment.
#'
#' It collects all dependencies' versions and stores them in lock file to
#' enforce exact dependency versions in the future.
#'
#' @details
#' The lock file is saved in <my_project>/deployment/ under 'env.lock' name.
#' It is in dcf format with information about packages installed in local
#' project environment together with their versions. A sample record from
#' the lock file:
#'
#'  Package: RSuite\cr
#'  Version: 0.26.235
#'
#' When dependencies are being installed (using \code{\link{prj_install_deps}})
#' the 'env.lock' file will be used to detect whether any package will change
#' versions. If that's the case a warning message will be displayed like this:
#'
#' \code{...:rsuite: The following packages will be updated from the last lock: colorspace}
#'
#' The feature allows preventing errors caused by newer versions of packages
#' which might work differently than previous versions used in the project.
#'
#' @param prj project object to be locked. If not passed the loaded project
#'    will be locked or the default whichever exists. Will init default project from
#'    the working directory if no default project exists.
#'    (type: rsuite_project, default: NULL)
#'
#' @family in project management
#'
#' @examples
#' \donttest{
#'   # create exemplary project base folder
#'   prj_base <- tempfile("example_")
#'   dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#'   # start project
#'   prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#'   # build project local environment
#'   prj_install_deps(prj = prj)
#'
#'   # lock project environment
#'   prj_lock_env(prj = prj)
#'
#'   # present contents of lock file created
#'   cat(readLines(file.path(prj$path, "deployment", "env.lock")), sep = "\n")
#' }
#' @export
#'
prj_lock_env <- function(prj = NULL) {
  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))
  params <- prj$load_params()

  uninst_deps <- collect_uninstalled_direct_deps(params) # from 52_dependencies.R

  prj_pkgs <- build_project_pkgslist(params$pkgs_path) # from 51_pkg_info.R
  uninst_deps <- vers.rm(uninst_deps, prj_pkgs)

  assert(vers.is_empty(uninst_deps),
         paste0("Some dependencies are not installed in project env: %s.",
                " Please, build project environment first."),
         paste(vers.get_names(uninst_deps), collapse = ","))

  env_pkgs <- collect_installed_pkgs(params)$valid # from 52_dependencies.R
  required <- collect_prj_required_dep_names(params, env_pkgs) # from 52_dependencies.R

  # Create lock data and save to 'env.lock' file
  lock_data <- env_pkgs[env_pkgs$Package %in% required, c("Package", "Version")]
  write.dcf(lock_data, file = params$lock_path)
  pkg_loginfo("The project environment was locked successfully")
}

#'
#' Unlocks the project environment.
#'
#' It removes the lock file created with \code{\link{prj_lock_env}}. If the project
#' environment is not locked (there is no lock file) the prj_unlock_env will fail.
#'
#' @param prj project object to be unlocked. if not passed the loaded project will be
#'    locked or the default whichever exists. Will init default project from the working
#'    directory if no default project exists.
#'    (type: rsuite_project, default: NULL)
#'
#' @examples
#' \donttest{
#'   # create exemplary project base folder
#'   prj_base <- tempfile("example_")
#'   dir.create(prj_base, recursive = TRUE, showWarnings = FALSE)
#'
#'   # start project
#'   prj <- prj_start("my_project", skip_rc = TRUE, path = prj_base)
#'
#'   # build project local environment
#'   prj_install_deps(prj = prj)
#'
#'   # lock project environment
#'   prj_lock_env(prj = prj)
#'
#'   # unlock project environment
#'   prj_unlock_env(prj = prj)
#' }
#' @export
#'
prj_unlock_env <- function(prj = NULL) {
  prj <- safe_get_prj(prj)
  stopifnot(!is.null(prj))
  params <- prj$load_params()

  if (!file.exists(params$lock_path)) {
    pkg_logwarn("The project environment is not locked")
    return(invisible())
  }

  unlink(params$lock_path, force = TRUE)
  pkg_loginfo("The project environment has been unlocked.")
}

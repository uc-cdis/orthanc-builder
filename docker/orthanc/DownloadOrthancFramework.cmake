# Orthanc - A Lightweight, RESTful DICOM Store
# Copyright (C) 2012-2016 Sebastien Jodogne, Medical Physics
# Department, University Hospital of Liege, Belgium
# Copyright (C) 2017-2023 Osimis S.A., Belgium
# Copyright (C) 2021-2023 Sebastien Jodogne, ICTEAM UCLouvain, Belgium
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.



##
## Check whether the parent script sets the mandatory variables
##

if (NOT DEFINED ORTHANC_FRAMEWORK_SOURCE OR
    (NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "system" AND
     NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "hg" AND
     NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "web" AND
     NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive" AND
     NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "path"))
  message(FATAL_ERROR "The variable ORTHANC_FRAMEWORK_SOURCE must be set to \"system\", \"hg\", \"web\", \"archive\" or \"path\"")
endif()


##
## Detection of the requested version
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "hg" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "web")
  if (NOT DEFINED ORTHANC_FRAMEWORK_VERSION)
    message(FATAL_ERROR "The variable ORTHANC_FRAMEWORK_VERSION must be set")
  endif()

  if (DEFINED ORTHANC_FRAMEWORK_MAJOR OR
      DEFINED ORTHANC_FRAMEWORK_MINOR OR
      DEFINED ORTHANC_FRAMEWORK_REVISION OR
      DEFINED ORTHANC_FRAMEWORK_MD5)
    message(FATAL_ERROR "Some internal variable has been set")
  endif()

  set(ORTHANC_FRAMEWORK_MD5 "")

  if (NOT DEFINED ORTHANC_FRAMEWORK_BRANCH)
    if (ORTHANC_FRAMEWORK_VERSION STREQUAL "mainline")
      set(ORTHANC_FRAMEWORK_BRANCH "default")
      set(ORTHANC_FRAMEWORK_MAJOR 999)
      set(ORTHANC_FRAMEWORK_MINOR 999)
      set(ORTHANC_FRAMEWORK_REVISION 999)

    else()
      set(ORTHANC_FRAMEWORK_BRANCH "Orthanc-${ORTHANC_FRAMEWORK_VERSION}")

      set(RE "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
      string(REGEX REPLACE ${RE} "\\1" ORTHANC_FRAMEWORK_MAJOR ${ORTHANC_FRAMEWORK_VERSION})
      string(REGEX REPLACE ${RE} "\\2" ORTHANC_FRAMEWORK_MINOR ${ORTHANC_FRAMEWORK_VERSION})
      string(REGEX REPLACE ${RE} "\\3" ORTHANC_FRAMEWORK_REVISION ${ORTHANC_FRAMEWORK_VERSION})

      if (NOT ORTHANC_FRAMEWORK_MAJOR MATCHES "^[0-9]+$" OR
          NOT ORTHANC_FRAMEWORK_MINOR MATCHES "^[0-9]+$" OR
          NOT ORTHANC_FRAMEWORK_REVISION MATCHES "^[0-9]+$")
        message("Bad version of the Orthanc framework, assuming a pre-release: ${ORTHANC_FRAMEWORK_VERSION}")
        set(ORTHANC_FRAMEWORK_MAJOR 999)
        set(ORTHANC_FRAMEWORK_MINOR 999)
        set(ORTHANC_FRAMEWORK_REVISION 999)
      endif()

      if (ORTHANC_FRAMEWORK_VERSION STREQUAL "1.3.1")
        set(ORTHANC_FRAMEWORK_MD5 "dac95bd6cf86fb19deaf4e612961f378") # pragma: allowlist secret
      elseif (ORTHANC_FRAMEWORK_VERSION STREQUAL "1.12.2")
        set(ORTHANC_FRAMEWORK_MD5 "d2476b9e796e339ac320b5333489bdb3") # pragma: allowlist secret
      endif()
    endif()
  endif()

elseif (ORTHANC_FRAMEWORK_SOURCE STREQUAL "path")
  message("Using the Orthanc framework from a path of the filesystem. Assuming mainline version.")
  set(ORTHANC_FRAMEWORK_MAJOR 999)
  set(ORTHANC_FRAMEWORK_MINOR 999)
  set(ORTHANC_FRAMEWORK_REVISION 999)
endif()



##
## Detection of the third-party software
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "hg")
  find_program(ORTHANC_FRAMEWORK_HG hg)
  
  if (${ORTHANC_FRAMEWORK_HG} MATCHES "ORTHANC_FRAMEWORK_HG-NOTFOUND")
    message(FATAL_ERROR "Please install Mercurial")
  endif()
endif()


if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "web")
  if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
    find_program(ORTHANC_FRAMEWORK_7ZIP 7z 
      PATHS 
      "$ENV{ProgramFiles}/7-Zip"
      "$ENV{ProgramW6432}/7-Zip"
      )

    if (${ORTHANC_FRAMEWORK_7ZIP} MATCHES "ORTHANC_FRAMEWORK_7ZIP-NOTFOUND")
      message(FATAL_ERROR "Please install the '7-zip' software (http://www.7-zip.org/)")
    endif()

  else()
    find_program(ORTHANC_FRAMEWORK_TAR tar)
    if (${ORTHANC_FRAMEWORK_TAR} MATCHES "ORTHANC_FRAMEWORK_TAR-NOTFOUND")
      message(FATAL_ERROR "Please install the 'tar' package")
    endif()
  endif()
endif()



##
## Case of the Orthanc framework specified as a path on the filesystem
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "path")
  if (NOT DEFINED ORTHANC_FRAMEWORK_ROOT OR
      ORTHANC_FRAMEWORK_ROOT STREQUAL "")
    message(FATAL_ERROR "The variable ORTHANC_FRAMEWORK_ROOT must provide the path to the sources of Orthanc")
  endif()
  
  if (NOT EXISTS ${ORTHANC_FRAMEWORK_ROOT})
    message(FATAL_ERROR "Non-existing directory: ${ORTHANC_FRAMEWORK_ROOT}")
  endif()
endif()



##
## Case of the Orthanc framework cloned using Mercurial
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "hg")
  if (NOT STATIC_BUILD AND NOT ALLOW_DOWNLOADS)
    message(FATAL_ERROR "CMake is not allowed to download from Internet. Please set the ALLOW_DOWNLOADS option to ON")
  endif()

  set(ORTHANC_ROOT ${CMAKE_BINARY_DIR}/orthanc)

  if (EXISTS ${ORTHANC_ROOT})
    message("Updating the Orthanc source repository using Mercurial")
    execute_process(
      COMMAND ${ORTHANC_FRAMEWORK_HG} pull
      WORKING_DIRECTORY ${ORTHANC_ROOT}
      RESULT_VARIABLE Failure
      )    
  else()
    message("Forking the Orthanc source repository using Mercurial")
    execute_process(
      COMMAND ${ORTHANC_FRAMEWORK_HG} clone "https://orthanc.uclouvain.be/hg/orthanc/"
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      RESULT_VARIABLE Failure
      )    
  endif()

  if (Failure OR NOT EXISTS ${ORTHANC_ROOT})
    message(FATAL_ERROR "Cannot fork the Orthanc repository")
  endif()

  message("Setting branch of the Orthanc repository to: ${ORTHANC_FRAMEWORK_BRANCH}")

  execute_process(
    COMMAND ${ORTHANC_FRAMEWORK_HG} update -c ${ORTHANC_FRAMEWORK_BRANCH}
    WORKING_DIRECTORY ${ORTHANC_ROOT}
    RESULT_VARIABLE Failure
    )

  if (Failure)
    message(FATAL_ERROR "Error while running Mercurial")
  endif()
endif()



##
## Case of the Orthanc framework provided as a source archive on the
## filesystem
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive")
  if (NOT DEFINED ORTHANC_FRAMEWORK_ARCHIVE OR
      ORTHANC_FRAMEWORK_ARCHIVE STREQUAL "")
    message(FATAL_ERROR "The variable ORTHANC_FRAMEWORK_ARCHIVE must provide the path to the sources of Orthanc")
  endif()
endif()



##
## Case of the Orthanc framework downloaded from the Web
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "web")
  if (DEFINED ORTHANC_FRAMEWORK_URL)
    string(REGEX REPLACE "^.*/" "" ORTHANC_FRAMEMORK_FILENAME "${ORTHANC_FRAMEWORK_URL}")
  else()
    # Default case: Download from the official Web site
    set(ORTHANC_FRAMEMORK_FILENAME Orthanc-${ORTHANC_FRAMEWORK_VERSION}.tar.gz)
    if (ORTHANC_FRAMEWORK_PRE_RELEASE)
      set(ORTHANC_FRAMEWORK_URL "https://orthanc.uclouvain.be/downloads/third-party-downloads/orthanc-framework/${ORTHANC_FRAMEMORK_FILENAME}")
    else()
      # HERE this one for `orthanc-s3`:
      # `https://orthanc.uclouvain.be/downloads/sources/orthanc/Orthanc-1.12.2.tar.gz`
      set(ORTHANC_FRAMEWORK_URL "https://orthanc.uclouvain.be/downloads/sources/orthanc/${ORTHANC_FRAMEMORK_FILENAME}")
    endif()
  endif()

  set(ORTHANC_FRAMEWORK_ARCHIVE "${CMAKE_SOURCE_DIR}/ThirdPartyDownloads/${ORTHANC_FRAMEMORK_FILENAME}")

  if (NOT EXISTS "${ORTHANC_FRAMEWORK_ARCHIVE}")
    if (NOT STATIC_BUILD AND NOT ALLOW_DOWNLOADS)
      message(FATAL_ERROR "CMake is not allowed to download from Internet. Please set the ALLOW_DOWNLOADS option to ON")
    endif()

    message("Downloading: ${ORTHANC_FRAMEWORK_URL}")
    # this is the problem. DownloadOrthancFramework.cmake downloads the https://orthanc.uclouvain.be/downloads/sources/orthanc/Orthanc-1.12.2.tar.gz and then calls the DownloadPackage.cmake that comes from it. 
    # but the DownloadPackage.cmake is not the one in the Common/Resources/Orthanc/CMake/DownloadPackage.cmake that I copied over.
    file(DOWNLOAD
      "${ORTHANC_FRAMEWORK_URL}" "${ORTHANC_FRAMEWORK_ARCHIVE}" 
      SHOW_PROGRESS EXPECTED_MD5 "${ORTHANC_FRAMEWORK_MD5}"
      TIMEOUT 60
      INACTIVITY_TIMEOUT 60
      )
  else()
    message("Using local copy of: ${ORTHANC_FRAMEWORK_URL}")
  endif()  
endif()




##
## Uncompressing the Orthanc framework, if it was retrieved from a
## source archive on the filesystem, or from the official Web site
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "web")

  if (NOT DEFINED ORTHANC_FRAMEWORK_ARCHIVE OR
      NOT DEFINED ORTHANC_FRAMEWORK_VERSION OR
      NOT DEFINED ORTHANC_FRAMEWORK_MD5)
    message(FATAL_ERROR "Internal error")
  endif()

  if (ORTHANC_FRAMEWORK_MD5 STREQUAL "")
    message(FATAL_ERROR "Unknown release of Orthanc: ${ORTHANC_FRAMEWORK_VERSION}")
  endif()

  file(MD5 ${ORTHANC_FRAMEWORK_ARCHIVE} ActualMD5)

  if (NOT "${ActualMD5}" STREQUAL "${ORTHANC_FRAMEWORK_MD5}")
    message(FATAL_ERROR "The MD5 hash of the Orthanc archive is invalid: ${ORTHANC_FRAMEWORK_ARCHIVE}")
  endif()

  set(ORTHANC_ROOT "${CMAKE_BINARY_DIR}/Orthanc-${ORTHANC_FRAMEWORK_VERSION}")

  if (NOT IS_DIRECTORY "${ORTHANC_ROOT}")
    if (NOT ORTHANC_FRAMEWORK_ARCHIVE MATCHES ".tar.gz$")
      message(FATAL_ERROR "Archive should have the \".tar.gz\" extension: ${ORTHANC_FRAMEWORK_ARCHIVE}")
    endif()
    
    message("Uncompressing: ${ORTHANC_FRAMEWORK_ARCHIVE}")

    if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
      # How to silently extract files using 7-zip
      # http://superuser.com/questions/331148/7zip-command-line-extract-silently-quietly

      execute_process(
        COMMAND ${ORTHANC_FRAMEWORK_7ZIP} e -y ${ORTHANC_FRAMEWORK_ARCHIVE}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE Failure
        OUTPUT_QUIET
        )
      
      if (Failure)
        message(FATAL_ERROR "Error while running the uncompression tool")
      endif()

      get_filename_component(TMP_FILENAME "${ORTHANC_FRAMEWORK_ARCHIVE}" NAME)
      string(REGEX REPLACE ".gz$" "" TMP_FILENAME2 "${TMP_FILENAME}")

      execute_process(
        COMMAND ${ORTHANC_FRAMEWORK_7ZIP} x -y ${TMP_FILENAME2}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE Failure
        OUTPUT_QUIET
        )

    else()
      execute_process(
        COMMAND sh -c "${ORTHANC_FRAMEWORK_TAR} xfz ${ORTHANC_FRAMEWORK_ARCHIVE}"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE Failure
        )
      execute_process(
        COMMAND sh -c "sed -i 's/The MD5 hash/The MD5 hash \\${ActualMD5} (expected \\${MD5})/g' Orthanc-1.12.2/OrthancFramework/Resources/CMake/DownloadPackage.cmake"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE Failure
        )
      execute_process(
        COMMAND sh -c "sed -i 's|message(FATAL_ERROR \"The package was not uncompressed at the proper location. Check the CMake instructions.\")|execute_process(COMMAND ls . OUTPUT_VARIABLE LS_OUTPUT OUTPUT_STRIP_TRAILING_WHITESPACE)\\nmessage(FATAL_ERROR \"The package was not uncompressed at the proper location (\${TargetDirectory}). Check the CMake instructions. List: \${LS_OUTPUT}\")|g' Orthanc-1.12.2/OrthancFramework/Resources/CMake/DownloadPackage.cmake"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE Failure
        )
      # We need to copy the DownloadPackage.cmake from the Common/Resources/Orthanc/CMake/DownloadPackage.cmake to the ${ORTHANC_FRAMEMORK_FILENAME}/ uncompressed folder
      # The local DownloadPackage.cmake was copied to the ${CMAKE_SOURCE_DIR}/ThirdPartyDownloads/ in the Dockerfile already.
      file(COPY "${CMAKE_SOURCE_DIR}/ThirdPartyDownloads/DownloadPackage.cmake"
       DESTINATION "${CMAKE_SOURCE_DIR}/ThirdPartyDownloads/Orthanc-1.12.2/OrthancFramework/Resources/CMake/")

    endif()
   
    if (Failure)
      message(FATAL_ERROR "Error while running the uncompression tool")
    endif()

    if (NOT IS_DIRECTORY "${ORTHANC_ROOT}")
      message(FATAL_ERROR "The Orthanc framework was not uncompressed at the proper location. Check the CMake instructions.")
    endif()
  endif()
endif()



##
## Determine the path to the sources of the Orthanc framework
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "archive" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "hg" OR
    ORTHANC_FRAMEWORK_SOURCE STREQUAL "web")
  if (NOT DEFINED ORTHANC_ROOT OR
      NOT DEFINED ORTHANC_FRAMEWORK_MAJOR OR
      NOT DEFINED ORTHANC_FRAMEWORK_MINOR OR
      NOT DEFINED ORTHANC_FRAMEWORK_REVISION)
    message(FATAL_ERROR "Internal error in the DownloadOrthancFramework.cmake file")
  endif()

  unset(ORTHANC_FRAMEWORK_ROOT CACHE)

  if ("${ORTHANC_FRAMEWORK_MAJOR}.${ORTHANC_FRAMEWORK_MINOR}.${ORTHANC_FRAMEWORK_REVISION}" VERSION_LESS "1.7.2")
    set(ORTHANC_FRAMEWORK_ROOT "${ORTHANC_ROOT}/Core" CACHE
      STRING "Path to the Orthanc framework source directory")
    set(ENABLE_PLUGINS_VERSION_SCRIPT OFF)
  else()
    set(ORTHANC_FRAMEWORK_ROOT "${ORTHANC_ROOT}/OrthancFramework/Sources" CACHE
      STRING "Path to the Orthanc framework source directory")
  endif()

  unset(ORTHANC_ROOT)
endif()

if (NOT ORTHANC_FRAMEWORK_SOURCE STREQUAL "system")
  if (NOT EXISTS ${ORTHANC_FRAMEWORK_ROOT}/OrthancException.h OR
      NOT EXISTS ${ORTHANC_FRAMEWORK_ROOT}/../Resources/CMake/OrthancFrameworkParameters.cmake)
    message(FATAL_ERROR "Directory not containing the source code of the Orthanc framework: ${ORTHANC_FRAMEWORK_ROOT}")
  endif()
endif()



##
## Case of the Orthanc framework installed as a shared library in a
## GNU/Linux distribution (typically Debian). New in Orthanc 1.7.2.
##

if (ORTHANC_FRAMEWORK_SOURCE STREQUAL "system")
  set(ORTHANC_FRAMEWORK_LIBDIR "" CACHE PATH "")
  set(ORTHANC_FRAMEWORK_USE_SHARED ON CACHE BOOL "Whether to use the shared library or the static library")
  set(ORTHANC_FRAMEWORK_ADDITIONAL_LIBRARIES "" CACHE STRING "Additional libraries to link against, separated by whitespaces, typically needed if using the static library (a common minimal value is \"boost_filesystem boost_iostreams boost_locale boost_regex boost_thread jsoncpp pugixml uuid\")")

  if (CMAKE_SYSTEM_NAME STREQUAL "Windows" AND
      CMAKE_COMPILER_IS_GNUCXX) # MinGW
    set(DYNAMIC_MINGW_STDLIB ON)   # Disable static linking against libc (to throw exceptions)
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-libstdc++")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++")
  endif()
  
  include(CheckIncludeFile)
  include(CheckIncludeFileCXX)
  include(FindPythonInterp)
  include(${CMAKE_CURRENT_LIST_DIR}/Compiler.cmake)
  include(${CMAKE_CURRENT_LIST_DIR}/DownloadPackage.cmake)
  include(${CMAKE_CURRENT_LIST_DIR}/AutoGeneratedCode.cmake)
  set(EMBED_RESOURCES_PYTHON ${CMAKE_CURRENT_LIST_DIR}/EmbedResources.py)

  if (ORTHANC_FRAMEWORK_USE_SHARED)
    list(GET CMAKE_FIND_LIBRARY_PREFIXES 0 Prefix)
    list(GET CMAKE_FIND_LIBRARY_SUFFIXES 0 Suffix)
  else()
    list(GET CMAKE_FIND_LIBRARY_PREFIXES 0 Prefix)
    list(GET CMAKE_FIND_LIBRARY_SUFFIXES 1 Suffix)
  endif()

  # The "OrthancFramework" library must be the first one to be included
  if ("${ORTHANC_FRAMEWORK_LIBDIR}" STREQUAL "")
    set(ORTHANC_FRAMEWORK_LIBRARIES ${Prefix}OrthancFramework${Suffix})
  else ()
    set(ORTHANC_FRAMEWORK_LIBRARIES ${ORTHANC_FRAMEWORK_LIBDIR}/${Prefix}OrthancFramework${Suffix})
  endif()

  if (NOT ORTHANC_FRAMEWORK_ADDITIONAL_LIBRARIES STREQUAL "")
    # https://stackoverflow.com/a/5272993/881731
    string(REPLACE " " ";" tmp ${ORTHANC_FRAMEWORK_ADDITIONAL_LIBRARIES})
    list(APPEND ORTHANC_FRAMEWORK_LIBRARIES ${tmp})
  endif()

  # Look for the version of the mandatory dependency JsonCpp (cf. JsonCppConfiguration.cmake)
  if (CMAKE_CROSSCOMPILING)
    set(JSONCPP_INCLUDE_DIR ${ORTHANC_FRAMEWORK_ROOT}/..)
  else()
    find_path(JSONCPP_INCLUDE_DIR json/reader.h
      ${ORTHANC_FRAMEWORK_ROOT}/..
      /usr/include/jsoncpp
      /usr/local/include/jsoncpp
      )
  endif()

  message("JsonCpp include dir: ${JSONCPP_INCLUDE_DIR}")
  include_directories(${JSONCPP_INCLUDE_DIR})

  CHECK_INCLUDE_FILE_CXX(${JSONCPP_INCLUDE_DIR}/json/reader.h HAVE_JSONCPP_H)
  if (NOT HAVE_JSONCPP_H)
    message(FATAL_ERROR "Please install the libjsoncpp-dev package")
  endif()

  # Look for Orthanc framework shared library
  include(CheckCXXSymbolExists)

  if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
    set(ORTHANC_FRAMEWORK_INCLUDE_DIR ${ORTHANC_FRAMEWORK_ROOT})
  else()
    find_path(ORTHANC_FRAMEWORK_INCLUDE_DIR OrthancFramework.h
      /usr/include/orthanc-framework
      /usr/local/include/orthanc-framework
      ${ORTHANC_FRAMEWORK_ROOT}
      )
  endif()

  if (${ORTHANC_FRAMEWORK_INCLUDE_DIR} STREQUAL "ORTHANC_FRAMEWORK_INCLUDE_DIR-NOTFOUND")
    message(FATAL_ERROR "Cannot locate the OrthancFramework.h header")
  endif()
  
  message("Orthanc framework include dir: ${ORTHANC_FRAMEWORK_INCLUDE_DIR}")
  include_directories(${ORTHANC_FRAMEWORK_INCLUDE_DIR})

  if (ORTHANC_FRAMEWORK_USE_SHARED)
    set(CMAKE_REQUIRED_INCLUDES "${ORTHANC_FRAMEWORK_INCLUDE_DIR}")
    set(CMAKE_REQUIRED_LIBRARIES "${ORTHANC_FRAMEWORK_LIBRARIES}")
    
    check_cxx_symbol_exists("Orthanc::InitializeFramework" "OrthancFramework.h" HAVE_ORTHANC_FRAMEWORK)
    if (NOT HAVE_ORTHANC_FRAMEWORK)
      message(FATAL_ERROR "Cannot find the Orthanc framework")
    endif()
    
    unset(CMAKE_REQUIRED_INCLUDES)
    unset(CMAKE_REQUIRED_LIBRARIES)
  endif()
endif()

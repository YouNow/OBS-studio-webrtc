project(websocketclient)

# -----------------------------------------------------------------------
# Global set up
#
set(CMAKE_CXX_STANDARD 11)
if( WIN32 )
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4503 /wd4267 /wd4244 /wd4996")
endif()
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/restclient-cpp/include)

find_package(LibObs REQUIRED)
include_directories(${LIBOBS_INCLUDE_DIRS})

#------------------------------------------------------------------------
# OpenSSL included in libwebrtc
#
# find_package(libwebrtc 65 REQUIRED)

#------------------------------------------------------------------------
# Asio
#
message(STATUS "ASIO Library at: " ${CMAKE_CURRENT_SOURCE_DIR} "/third_party/asio/include")

include_directories( ${CMAKE_CURRENT_SOURCE_DIR}/third_party/asio/include )

if( WIN32 )
  include_directories( "C:/OpenSSL-Win64/include")
elseif ( APPLE )
  include_directories( /usr/local/opt/openssl@1.1/include)
endif()

include_directories( ${CURL_INCLUDE_DIR} )

# WebSocket
#
set( websocketclient_SOURCES
  YouNowWebsocketClientImpl.cpp
  WebsocketClient.cpp
  restclient-cpp/source/connection.cc
  restclient-cpp/source/helpers.cc
  restclient-cpp/source/restclient.cc
)
if( WIN32 )
  set( websocketclient_SOURCES ${websocketclient_SOURCES} dllmain.cpp )
  add_definitions( -DWEBSOCKETCLIENT_EXPORTS )
elseif( APPLE )
  add_definitions( -DWEBSOCKETCLIENT_EXPORTS )
endif()

set( websocketclient_HEADERS
  json.hpp
  YouNowWebsocketClientImpl.h
  WebsocketClient.h
  )

add_library( websocketclient SHARED
  ${websocketclient_SOURCES}
  ${websocketclient_HEADERS}
  )

  # libcurl
  #
  if (WIN32)
    set (curl_path "${CURL_INCLUDE_DIR}/../bin/libcurl.lib")
  elseif (UNIX AND NOT APPLE)
    set (curl_path "${CURL_INCLUDE_DIR}/../lib/libcurl.a")
  elseif (APPLE)
    set (curl_path "/usr/lib/libcurl.dylib")
  endif()

  target_link_libraries(websocketclient ${curl_path})

# why ?
target_link_libraries( websocketclient
  ${WEBRTC_LIBRARIES}
)

install_obs_plugin(websocketclient)

if ( APPLE )
  target_link_libraries( websocketclient
    /usr/local/opt/openssl@1.1/lib/libssl.1.1.dylib
    /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib
    # /usr/local/lib/libssl.dylib
    # /usr/local/lib/libcrypto.dylib
  )
elseif ( WIN32 )
  target_link_libraries( websocketclient
    "c:/OpenSSL-WIN64/lib/libssl.lib"
    "c:/OpenSSL-WIN64/lib/libcrypto.lib"
  )
endif()

#-------------------------------------------------------------
# Libwebrtc with OpenSSL
#

# The developers used an installer for libwebrtc with OpenSSL
# Change destination if needed
# Works only if OpenSSL is built as a shared library
set( libwebrtc_rootdir ${libwebrtc_DIR}/..)

if ( UNIX AND NOT APPLE )
  install(
    FILES       ${libwebrtc_rootdir}/lib/libssl.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       ${libwebrtc_rootdir}/lib/libcrypto.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       ${libwebrtc_rootdir}/lib/libwebrtc.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       ${libwebrtc_rootdir}/lib/libssl.so.1.1
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       ${libwebrtc_rootdir}/lib/libcrypto.so.1.1
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
elseif ( APPLE )
  install(
    FILES       /usr/local/opt/openssl@1.1/lib/libssl.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       /usr/local/opt/openssl@1.1/lib/libcrypto.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       /Users/erankalmanson/dev/webrtc-checkout/src/out/Default/obj/libwebrtc.a
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       /usr/local/opt/openssl@1.1/lib/libssl.1.1.dylib
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
else ( WIN32 )
  install(
    FILES       "c:/OpenSSL-WIN64/lib/libssl.lib"
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       "c:/OpenSSL-WIN64/lib/libcrypto.lib"
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       "c:/dev/webrtc-checkout/src/out/Default/obj/webrtc.lib"
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       "c:/OpenSSL-WIN64/bin/libssl-1_1-x64.dll"
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  install(
    FILES       "c:/OpenSSL-WIN64/bin/libcrypto-1_1-x64.dll"
    DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Libraries )
  
  if( EXISTS "${libwebrtc_rootdir}/bin/libssl-1_1-x64.dll" )
    install(
      FILES       ${libwebrtc_rootdir}/bin/libssl-1_1-x64.dll
      DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Runtime )
    install(
      FILES       ${libwebrtc_rootdir}/bin/libcrypto-1_1-x64.dll
      DESTINATION ${OBS_EXECUTABLE_DESTINATION} COMPONENT   Runtime )
  endif()
endif ()

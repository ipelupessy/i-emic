cmake_minimum_required(VERSION 3.3)
  
set(MRILUCPP_INCLUDE_DIRS
  ../utils/
  ${MRILU_DIR}/mod
  ${CMAKE_CURRENT_SOURCE_DIR}
  )

add_library(mrilucpp SHARED mrilucpp.F90)
add_library(ifpack_mrilu SHARED Ifpack_MRILU.cpp)

target_compile_definitions(mrilucpp PUBLIC HAVE_IFPACK_MRILU)
target_compile_definitions(ifpack_mrilu PUBLIC HAVE_IFPACK_MRILU)

target_include_directories(ifpack_mrilu PUBLIC ${MRILUCPP_INCLUDE_DIRS})
target_include_directories(mrilucpp PUBLIC ${MRILUCPP_INCLUDE_DIRS})

if (TARGET mrilu)
  add_dependencies(mrilucpp mrilu)
endif ()

install(TARGETS mrilucpp ifpack_mrilu DESTINATION lib)

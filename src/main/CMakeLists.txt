cmake_minimum_required(VERSION 2.8.12.2)

add_executable(run_coupled run_coupled.C)
add_executable(run_ocean run_ocean.C)

add_dependencies(run_coupled jdqzpp)
add_dependencies(run_ocean   jdqzpp)


set(MAIN_INCLUDE_DIRS
  ${CMAKE_CURRENT_SOURCE_DIR}
  ../thetastepper/
  ../newton/
  ../continuation/
  )

target_link_libraries(run_coupled PUBLIC ${I-EMIC_LIBS})
target_link_libraries(run_coupled PUBLIC ${library_dependencies})
target_include_directories(run_coupled PUBLIC ${MAIN_INCLUDE_DIRS})

target_link_libraries(run_ocean PUBLIC ${I-EMIC_LIBS})
target_link_libraries(run_ocean PUBLIC ${library_dependencies})
target_include_directories(run_ocean PUBLIC ${MAIN_INCLUDE_DIRS})

install(TARGETS run_coupled DESTINATION bin)
install(TARGETS run_ocean DESTINATION bin)
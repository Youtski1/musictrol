cmake_minimum_required(VERSION 3.21)

project(musictrol VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Network)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(musictrol
    src/main.cpp
    src/core/Track.h
    src/core/TrackListModel.h
    src/core/TrackListModel.cpp
    src/core/MusicController.h
    src/core/MusicController.cpp
    src/player/MpvPlayer.h
    src/player/MpvPlayer.cpp
    src/youtube/YouTubeSearch.h
    src/youtube/YouTubeSearch.cpp
)

target_include_directories(musictrol PRIVATE src)

qt_add_qml_module(musictrol
    URI Musictrol
    VERSION 1.0
    QML_FILES
        qml/DevWindow.qml
)

target_link_libraries(musictrol PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    PkgConfig::MPV
)

install(TARGETS musictrol RUNTIME DESTINATION bin)

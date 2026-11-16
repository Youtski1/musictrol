cmake_minimum_required(VERSION 3.21)

project(musictrol VERSION 0.4.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Quick QuickControls2 Network Concurrent ShaderTools)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
pkg_check_modules(XCB REQUIRED IMPORTED_TARGET xcb xcb-shape xcb-keysyms xkbcommon xkbcommon-x11)

qt_standard_project_setup(REQUIRES 6.9)

qt_add_executable(musictrol
    src/main.cpp
    src/core/Track.h
    src/core/TrackListModel.h
    src/core/TrackListModel.cpp
    src/core/MusicController.h
    src/core/MusicController.cpp
    src/core/AppSettings.h
    src/core/AppSettings.cpp
    src/core/Library.h
    src/core/Library.cpp
    src/core/Downloads.h
    src/core/Downloads.cpp
    src/core/Lyrics.h
    src/core/Lyrics.cpp
    src/player/MpvPlayer.h
    src/player/MpvPlayer.cpp
    src/youtube/YouTubeSearch.h
    src/youtube/YouTubeSearch.cpp
    src/desktop/WindowHelper.h
    src/desktop/WindowHelper.cpp
    src/desktop/Wallpaper.h
    src/desktop/Wallpaper.cpp
    src/desktop/GlobalHotkeys.h
    src/desktop/GlobalHotkeys.cpp
)

# Подпапки нужны генератору регистрации QML-типов: он подключает заголовки по имени файла.
target_include_directories(musictrol PRIVATE src src/core src/player src/youtube src/desktop)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(musictrol
    URI Musictrol
    VERSION 1.0
    QML_FILES
        qml/App.qml
        qml/Theme.qml
        qml/MainWidget.qml
        qml/MiniWidget.qml
        qml/MusicPanel.qml
        qml/components/Icon.qml
        qml/components/IconButton.qml
        qml/components/GlassSlider.qml
        qml/components/VolumePill.qml
        qml/components/WaveSeek.qml
        qml/components/KeyChip.qml
        qml/components/LyricsView.qml
        qml/components/RoundedImage.qml
        qml/components/GlassPane.qml
        qml/components/Toggle.qml
        qml/components/PillButton.qml
        qml/components/PlaylistPicker.qml
)

# Шейдеры компилируются в .qsb при сборке (скругление обложек и т.п.).
qt_add_shaders(musictrol "shaders"
    PREFIX "/"
    FILES
        shaders/rounded.frag
)

target_link_libraries(musictrol PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Concurrent
    PkgConfig::MPV
    PkgConfig::XCB
)

install(TARGETS musictrol RUNTIME DESTINATION bin)

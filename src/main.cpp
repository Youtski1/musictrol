#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <clocale>

#include "core/AppSettings.h"
#include "core/Downloads.h"
#include "core/Library.h"
#include "core/MusicController.h"
#include "desktop/GlobalHotkeys.h"

namespace {
QString instanceName()
{
    return QStringLiteral("musictrol-%1").arg(qEnvironmentVariable("USER"));
}

// Если программа уже запущена — просим её открыть панель и выходим.
bool notifyRunningInstance()
{
    QLocalSocket socket;
    socket.connectToServer(instanceName());
    if (!socket.waitForConnected(300))
        return false;
    socket.write("open\n");
    socket.waitForBytesWritten(300);
    return true;
}
} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("musictrol"));
    QGuiApplication::setOrganizationName(QStringLiteral("musictrol"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Musictrol"));
    // Виджеты живут без «главного окна»: закрытие любого окна не выходит из программы.
    QGuiApplication::setQuitOnLastWindowClosed(false);
    // Прозрачные окна-виджеты.
    QQuickWindow::setDefaultAlphaBuffer(true);

    const bool snapshotMode = app.arguments().contains(QStringLiteral("--snapshot"));
    if (!snapshotMode && notifyRunningInstance())
        return 0;

    // libmpv требует «C»-локаль для чисел (Qt выставляет системную).
    std::setlocale(LC_NUMERIC, "C");

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Объекты объявлены раньше движка QML, значит живут дольше него.
    AppSettings settings;
    AppSettings::setInstance(&settings);
    Library library;
    Library::setInstance(&library);
    Downloads downloads;
    Downloads::setInstance(&downloads);
    MusicController controller;
    MusicController::setInstance(&controller);
    QObject::connect(&controller, &MusicController::trackStarted, &library, &Library::addToHistory);
    GlobalHotkeys hotkeys;
    GlobalHotkeys::setInstance(&hotkeys);

    QLocalServer server;
    if (!snapshotMode) {
        QLocalServer::removeServer(instanceName()); // остаток после аварийного выхода
        server.listen(instanceName());
        QObject::connect(&server, &QLocalServer::newConnection, &settings, [&server, &settings] {
            while (QLocalSocket *s = server.nextPendingConnection()) {
                QObject::connect(s, &QLocalSocket::disconnected, s, &QObject::deleteLater);
                emit settings.activateRequested();
            }
        });
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    engine.loadFromModule("Musictrol", "App");

    return app.exec();
}

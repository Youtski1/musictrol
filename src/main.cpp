#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <clocale>

#include "core/MusicController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("musictrol"));
    QGuiApplication::setOrganizationName(QStringLiteral("musictrol"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Musictrol"));

    // libmpv требует «C»-локаль для чисел (Qt выставляет системную).
    std::setlocale(LC_NUMERIC, "C");

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Контроллер объявлен раньше движка QML, значит живёт дольше него.
    MusicController controller;
    MusicController::setInstance(&controller);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    // Шаг 1: временное тестовое окно. На следующих шагах его заменят виджеты.
    engine.loadFromModule("Musictrol", "DevWindow");

    return app.exec();
}

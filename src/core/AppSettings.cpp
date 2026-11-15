#include "core/AppSettings.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
}

QString AppSettings::autostartFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
           + QStringLiteral("/autostart/musictrol.desktop");
}

bool AppSettings::autostart() const
{
    return QFile::exists(autostartFile());
}

void AppSettings::setAutostart(bool enabled)
{
    if (enabled == autostart())
        return;

    const QString file = autostartFile();
    if (enabled) {
        QDir().mkpath(QFileInfo(file).absolutePath());
        QFile f(file);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return;
        const QString exec = QCoreApplication::applicationFilePath();
        f.write(QStringLiteral(
                    "[Desktop Entry]\n"
                    "Type=Application\n"
                    "Name=Musictrol\n"
                    "Comment=Музыкальный виджет\n"
                    "Exec=\"%1\"\n"
                    "Terminal=false\n"
                    "X-GNOME-Autostart-enabled=true\n")
                    .arg(exec)
                    .toUtf8());
    } else {
        QFile::remove(file);
    }
    emit autostartChanged();
}

void AppSettings::quit()
{
    QCoreApplication::quit();
}

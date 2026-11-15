#pragma once

#include <QObject>
#include <QtQmlIntegration>

// Системные настройки приложения, которые нельзя хранить просто в QSettings
// (автозапуск — это файл в ~/.config/autostart).
class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    bool autostart() const;
    void setAutostart(bool enabled);

    Q_INVOKABLE void quit();

signals:
    void autostartChanged();

private:
    static QString autostartFile();
};

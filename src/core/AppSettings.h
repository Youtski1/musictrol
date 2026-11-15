#pragma once

#include <QObject>
#include <QtQmlIntegration>

class QQmlEngine;
class QJSEngine;

// Системные настройки приложения, которые нельзя хранить просто в QSettings
// (автозапуск — это файл в ~/.config/autostart).
class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)

public:
    // Без значения по умолчанию: иначе QML создаёт свою копию вместо нашей (create()).
    explicit AppSettings(QObject *parent);

    static void setInstance(AppSettings *instance);
    static AppSettings *create(QQmlEngine *, QJSEngine *);

    bool autostart() const;
    void setAutostart(bool enabled);

    Q_INVOKABLE void quit();

signals:
    void autostartChanged();
    // Программу запустили ещё раз — первая копия открывает панель музыки.
    void activateRequested();

private:
    static QString autostartFile();
    static AppSettings *s_instance;
};

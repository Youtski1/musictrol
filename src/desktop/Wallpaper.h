#pragma once

#include <QHash>
#include <QObject>
#include <QUrl>
#include <QtQmlIntegration>

class QProcess;

// Размытые обои рабочего стола XFCE — основа «стекла» для виджетов.
// Блюр считается один раз (в фоне) при старте и при смене обоев, дальше
// QML просто показывает нужный кусок готовой картинки.
class Wallpaper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    explicit Wallpaper(QObject *parent = nullptr);
    ~Wallpaper() override;

    int revision() const { return m_revision; }

    // Размытая картинка для монитора (имя как у QScreen::name(), напр. "HDMI-1").
    Q_INVOKABLE QUrl blurredFor(const QString &screenName) const;

    Q_INVOKABLE void reload();

signals:
    void changed();

private:
    struct Source {
        QString screenName;
        QString imagePath;
        int style = 5;       // xfce: 0 нет, 1 центр, 2 плитка, 3 растянуть, 4 вписать, 5 заполнить, 6 на все
        QSize screenSize;
    };

    QList<Source> readXfceSources() const;
    void startMonitor();

    QHash<QString, QUrl> m_blurred;
    int m_revision = 0;
    int m_generation = 0;
    QProcess *m_monitor = nullptr;
};

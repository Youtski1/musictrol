#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QtQmlIntegration>

class QNetworkAccessManager;
class QNetworkReply;
class QQmlEngine;
class QJSEngine;

// Текст песни для текущего трека: LRCLIB (lrclib.net), построчно с таймингами.
// Найденный текст кэшируется на диске; у скачанных треков рядом кладётся .lrc.
class Lyrics : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Lyrics)
    QML_SINGLETON

    // [{ time: секунды (−1 — без тайминга), text }]
    Q_PROPERTY(QVariantList lines READ lines NOTIFY changed)
    Q_PROPERTY(bool synced READ synced NOTIFY changed)
    // "idle" | "loading" | "found" | "notfound"
    Q_PROPERTY(QString status READ status NOTIFY changed)

public:
    explicit Lyrics(QObject *parent = nullptr);

    static void setInstance(Lyrics *instance);
    static Lyrics *create(QQmlEngine *, QJSEngine *);

    QVariantList lines() const { return m_lines; }
    bool synced() const { return m_synced; }
    QString status() const { return m_status; }

    // Индекс строки, которая звучит в момент position (секунды); −1 — до первой.
    Q_INVOKABLE int lineAt(double position) const;

    // Разобрать название ролика YouTube на исполнителя и песню.
    static void guessArtistTitle(const QString &rawTitle, const QString &channel, QString &artist, QString &title);

public slots:
    void loadFor(const QString &videoId, const QString &rawTitle, const QString &channel,
                 double duration, const QString &localFile);

signals:
    void changed();

private:
    void setResult(const QString &lrcOrPlain, bool synced);
    void setStatus(const QString &s);
    void parseLrc(const QString &lrc);
    QString cachePath(const QString &videoId) const;

    QNetworkAccessManager *m_net;
    QPointer<QNetworkReply> m_reply;
    QString m_videoId;
    QString m_localFile;
    QVariantList m_lines;
    QList<double> m_times;
    bool m_synced = false;
    QString m_status = QStringLiteral("idle");

    static Lyrics *s_instance;
};

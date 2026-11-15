#pragma once

#include <QJsonObject>
#include <QList>
#include <QMetaType>
#include <QString>

// Один трек: откуда играть и что показывать в интерфейсе.
struct Track
{
    QString videoId;
    QString title;
    QString artist;
    QString url;        // что отдаём mpv (страница YouTube или прямая ссылка)
    QString thumbnail;  // обложка
    double duration = 0; // секунды, 0 — неизвестно

    bool isValid() const { return !url.isEmpty(); }

    QJsonObject toJson() const
    {
        return {
            {QStringLiteral("id"), videoId},
            {QStringLiteral("title"), title},
            {QStringLiteral("artist"), artist},
            {QStringLiteral("url"), url},
            {QStringLiteral("thumb"), thumbnail},
            {QStringLiteral("dur"), duration},
        };
    }

    static Track fromJson(const QJsonObject &o)
    {
        Track t;
        t.videoId = o.value(QLatin1String("id")).toString();
        t.title = o.value(QLatin1String("title")).toString();
        t.artist = o.value(QLatin1String("artist")).toString();
        t.url = o.value(QLatin1String("url")).toString();
        t.thumbnail = o.value(QLatin1String("thumb")).toString();
        t.duration = o.value(QLatin1String("dur")).toDouble();
        return t;
    }
};

using TrackList = QList<Track>;

Q_DECLARE_METATYPE(Track)

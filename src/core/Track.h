#pragma once

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
};

using TrackList = QList<Track>;

Q_DECLARE_METATYPE(Track)

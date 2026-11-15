#pragma once

#include <QAbstractListModel>
#include <QtQmlIntegration>

#include "core/Track.h"

// Список треков для QML (результаты поиска, позже — очередь, плейлисты).
class TrackListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Создаётся в C++")
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        VideoIdRole = Qt::UserRole + 1,
        TitleRole,
        ArtistRole,
        UrlRole,
        ThumbnailRole,
        DurationRole,
    };

    explicit TrackListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_tracks.size()); }
    const TrackList &tracks() const { return m_tracks; }
    Track at(int row) const;
    Q_INVOKABLE QString titleAt(int row) const { return at(row).title; }

    void setTracks(const TrackList &tracks);
    void clear();
    void append(const Track &track);
    void prepend(const Track &track);
    void removeAt(int row);
    Q_INVOKABLE int indexOfVideo(const QString &videoId) const;

signals:
    void countChanged();

private:
    TrackList m_tracks;
};

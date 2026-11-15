#include "core/TrackListModel.h"

TrackListModel::TrackListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TrackListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_tracks.size());
}

QVariant TrackListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tracks.size())
        return {};

    const Track &t = m_tracks.at(index.row());
    switch (role) {
    case VideoIdRole:   return t.videoId;
    case TitleRole:     return t.title;
    case ArtistRole:    return t.artist;
    case UrlRole:       return t.url;
    case ThumbnailRole: return t.thumbnail;
    case DurationRole:  return t.duration;
    default:            return {};
    }
}

QHash<int, QByteArray> TrackListModel::roleNames() const
{
    return {
        {VideoIdRole, "videoId"},
        {TitleRole, "title"},
        {ArtistRole, "artist"},
        {UrlRole, "url"},
        {ThumbnailRole, "thumbnail"},
        {DurationRole, "duration"},
    };
}

Track TrackListModel::at(int row) const
{
    if (row < 0 || row >= m_tracks.size())
        return {};
    return m_tracks.at(row);
}

void TrackListModel::setTracks(const TrackList &tracks)
{
    beginResetModel();
    m_tracks = tracks;
    endResetModel();
    emit countChanged();
}

void TrackListModel::clear()
{
    setTracks({});
}

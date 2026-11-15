#include "core/Library.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QQmlEngine>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
constexpr int kHistoryLimit = 200;

QJsonArray tracksToJson(const TrackList &tracks)
{
    QJsonArray arr;
    for (const Track &t : tracks)
        arr.append(t.toJson());
    return arr;
}

TrackList tracksFromJson(const QJsonArray &arr)
{
    TrackList list;
    for (const QJsonValue &v : arr) {
        const Track t = Track::fromJson(v.toObject());
        if (t.isValid())
            list.append(t);
    }
    return list;
}
} // namespace

// ── PlaylistListModel ─────────────────────────────────────────────────────

PlaylistListModel::PlaylistListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PlaylistListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

QVariant PlaylistListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.size())
        return {};
    const Playlist &p = m_items.at(index.row());
    switch (role) {
    case NameRole:
        return p.name;
    case TrackCountRole:
        return int(p.tracks.size());
    case CoversRole: {
        QStringList covers;
        for (int i = 0; i < p.tracks.size() && covers.size() < 4; ++i)
            covers.append(p.tracks.at(i).thumbnail);
        return covers;
    }
    case DurationRole: {
        double total = 0;
        for (const Track &t : p.tracks)
            total += t.duration;
        return total;
    }
    default:
        return {};
    }
}

QHash<int, QByteArray> PlaylistListModel::roleNames() const
{
    return {{NameRole, "name"}, {TrackCountRole, "trackCount"}, {CoversRole, "covers"}, {DurationRole, "duration"}};
}

void PlaylistListModel::reset(const QList<Playlist> &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
    emit countChanged();
}

void PlaylistListModel::refreshRow(int row)
{
    if (row >= 0 && row < m_items.size())
        emit dataChanged(index(row), index(row));
}

void PlaylistListModel::appendItem(const Playlist &p)
{
    const int row = int(m_items.size());
    beginInsertRows({}, row, row);
    m_items.append(p);
    endInsertRows();
    emit countChanged();
}

void PlaylistListModel::removeItem(int row)
{
    if (row < 0 || row >= m_items.size())
        return;
    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
    emit countChanged();
}

// ── Library ───────────────────────────────────────────────────────────────

Library *Library::s_instance = nullptr;

Library::Library(QObject *parent)
    : QObject(parent)
    , m_favorites(new TrackListModel(this))
    , m_history(new TrackListModel(this))
    , m_opened(new TrackListModel(this))
    , m_playlists(new PlaylistListModel(this))
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, &Library::save);
    load();
}

Library::~Library()
{
    if (m_saveTimer.isActive())
        save();
    if (s_instance == this)
        s_instance = nullptr;
}

void Library::setInstance(Library *instance)
{
    s_instance = instance;
}

Library *Library::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

QString Library::filePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/library.json");
}

QString Library::openedPlaylistName() const
{
    if (m_openedPlaylist < 0 || m_openedPlaylist >= m_playlists->count())
        return {};
    return m_playlists->items().at(m_openedPlaylist).name;
}

void Library::toggleFavorite(TrackListModel *model, int index)
{
    if (!model)
        return;
    const Track t = model->at(index);
    if (!t.isValid())
        return;

    if (m_favIds.contains(t.videoId)) {
        m_favIds.remove(t.videoId);
        m_favorites->removeAt(m_favorites->indexOfVideo(t.videoId));
    } else {
        m_favIds.insert(t.videoId);
        m_favorites->prepend(t);
    }
    ++m_favRevision;
    emit favoritesChanged();
    scheduleSave();
}

int Library::createPlaylist(const QString &rawName)
{
    QString name = rawName.trimmed();
    if (name.isEmpty())
        name = tr("Плейлист %1").arg(m_playlists->count() + 1);
    m_playlists->appendItem({name, {}});
    scheduleSave();
    return m_playlists->count() - 1;
}

QString Library::playlistName(int index) const
{
    if (index < 0 || index >= m_playlists->count())
        return {};
    return m_playlists->items().at(index).name;
}

void Library::deletePlaylist(int index)
{
    if (index < 0 || index >= m_playlists->count())
        return;
    if (m_openedPlaylist == index) {
        m_openedPlaylist = -1;
        m_opened->clear();
        emit openedPlaylistChanged();
    } else if (m_openedPlaylist > index) {
        --m_openedPlaylist;
        emit openedPlaylistChanged();
    }
    m_playlists->removeItem(index);
    scheduleSave();
}

void Library::addToPlaylist(int playlist, TrackListModel *model, int index)
{
    if (!model || playlist < 0 || playlist >= m_playlists->count())
        return;
    const Track t = model->at(index);
    if (!t.isValid())
        return;
    m_playlists->items()[playlist].tracks.append(t);
    m_playlists->refreshRow(playlist);
    if (m_openedPlaylist == playlist)
        m_opened->append(t);
    scheduleSave();
}

void Library::removeFromOpenedPlaylist(int trackIndex)
{
    if (m_openedPlaylist < 0 || m_openedPlaylist >= m_playlists->count())
        return;
    TrackList &tracks = m_playlists->items()[m_openedPlaylist].tracks;
    if (trackIndex < 0 || trackIndex >= tracks.size())
        return;
    tracks.removeAt(trackIndex);
    m_opened->removeAt(trackIndex);
    m_playlists->refreshRow(m_openedPlaylist);
    scheduleSave();
}

void Library::openPlaylist(int index)
{
    if (index < 0 || index >= m_playlists->count()) {
        m_openedPlaylist = -1;
        m_opened->clear();
    } else {
        m_openedPlaylist = index;
        m_opened->setTracks(m_playlists->items().at(index).tracks);
    }
    emit openedPlaylistChanged();
}

void Library::addToHistory(const Track &track)
{
    if (!track.isValid())
        return;
    // Один трек — одна запись: повтор поднимается наверх.
    m_history->removeAt(m_history->indexOfVideo(track.videoId));
    m_history->prepend(track);
    while (m_history->count() > kHistoryLimit)
        m_history->removeAt(m_history->count() - 1);
    scheduleSave();
}

void Library::load()
{
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

    const TrackList favs = tracksFromJson(root.value(QLatin1String("favorites")).toArray());
    m_favorites->setTracks(favs);
    for (const Track &t : favs)
        m_favIds.insert(t.videoId);

    m_history->setTracks(tracksFromJson(root.value(QLatin1String("history")).toArray()));

    QList<Playlist> playlists;
    for (const QJsonValue &v : root.value(QLatin1String("playlists")).toArray()) {
        const QJsonObject o = v.toObject();
        playlists.append({o.value(QLatin1String("name")).toString(),
                          tracksFromJson(o.value(QLatin1String("tracks")).toArray())});
    }
    m_playlists->reset(playlists);
}

void Library::scheduleSave()
{
    m_saveTimer.start();
}

void Library::save() const
{
    QJsonArray playlists;
    for (const Playlist &p : m_playlists->items())
        playlists.append(QJsonObject{{QStringLiteral("name"), p.name}, {QStringLiteral("tracks"), tracksToJson(p.tracks)}});

    const QJsonObject root{
        {QStringLiteral("version"), 1},
        {QStringLiteral("favorites"), tracksToJson(m_favorites->tracks())},
        {QStringLiteral("history"), tracksToJson(m_history->tracks())},
        {QStringLiteral("playlists"), playlists},
    };

    const QString path = filePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile f(path); // атомарная запись: файл не побьётся при сбое
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    f.commit();
}

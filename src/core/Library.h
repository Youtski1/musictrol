#pragma once

#include <QAbstractListModel>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QtQmlIntegration>

#include "core/Track.h"
#include "core/TrackListModel.h"

class QQmlEngine;
class QJSEngine;

struct Playlist
{
    QString name;
    TrackList tracks;
};

// Список плейлистов для карусели (название, число треков, до 4 обложек для мозаики).
class PlaylistListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Создаётся в C++")
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role { NameRole = Qt::UserRole + 1, TrackCountRole, CoversRole, DurationRole };

    explicit PlaylistListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_items.size()); }
    QList<Playlist> &items() { return m_items; }
    const QList<Playlist> &items() const { return m_items; }
    void reset(const QList<Playlist> &items);
    void refreshRow(int row);
    void appendItem(const Playlist &p);
    void removeItem(int row);

signals:
    void countChanged();

private:
    QList<Playlist> m_items;
};

// Библиотека пользователя: избранное, история, плейлисты. Хранится в JSON
// (~/.local/share/musictrol/library.json), запись — с небольшой задержкой.
class Library : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(TrackListModel *favorites READ favorites CONSTANT)
    Q_PROPERTY(TrackListModel *history READ history CONSTANT)
    Q_PROPERTY(PlaylistListModel *playlists READ playlists CONSTANT)
    Q_PROPERTY(TrackListModel *openedTracks READ openedTracks CONSTANT)
    Q_PROPERTY(int openedPlaylist READ openedPlaylist NOTIFY openedPlaylistChanged)
    Q_PROPERTY(QString openedPlaylistName READ openedPlaylistName NOTIFY openedPlaylistChanged)
    // Меняется при любом изменении избранного — для обновления сердечек в QML.
    Q_PROPERTY(int favoritesRevision READ favoritesRevision NOTIFY favoritesChanged)

public:
    explicit Library(QObject *parent = nullptr);
    ~Library() override;

    static void setInstance(Library *instance);
    static Library *create(QQmlEngine *, QJSEngine *);

    TrackListModel *favorites() const { return m_favorites; }
    TrackListModel *history() const { return m_history; }
    PlaylistListModel *playlists() const { return m_playlists; }
    TrackListModel *openedTracks() const { return m_opened; }
    int openedPlaylist() const { return m_openedPlaylist; }
    QString openedPlaylistName() const;
    int favoritesRevision() const { return m_favRevision; }

    Q_INVOKABLE bool isFavorite(const QString &videoId) const { return m_favIds.contains(videoId); }
    Q_INVOKABLE void toggleFavorite(TrackListModel *model, int index);

    Q_INVOKABLE int createPlaylist(const QString &name);
    Q_INVOKABLE QString playlistName(int index) const;
    Q_INVOKABLE void deletePlaylist(int index);
    Q_INVOKABLE void addToPlaylist(int playlist, TrackListModel *model, int index);
    Q_INVOKABLE void removeFromOpenedPlaylist(int trackIndex);
    Q_INVOKABLE void openPlaylist(int index);

    void addToHistory(const Track &track);

signals:
    void favoritesChanged();
    void openedPlaylistChanged();

private:
    void load();
    void scheduleSave();
    void save() const;
    static QString filePath();

    TrackListModel *m_favorites;
    TrackListModel *m_history;
    TrackListModel *m_opened;
    PlaylistListModel *m_playlists;
    QSet<QString> m_favIds;
    int m_favRevision = 0;
    int m_openedPlaylist = -1;
    QTimer m_saveTimer;

    static Library *s_instance;
};

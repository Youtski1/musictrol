#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QtQmlIntegration>

#include "core/Track.h"
#include "core/TrackListModel.h"
#include "player/MpvPlayer.h"

class QQmlEngine;
class QJSEngine;
class QNetworkAccessManager;
class QNetworkReply;
class YouTubeSearch;

// Центр приложения: поиск, очередь, текущий трек. Один на всё приложение,
// все виджеты (карточка, капсула, мини-виджет, караоке) работают через него.
class MusicController : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Music)
    QML_SINGLETON

    Q_PROPERTY(MpvPlayer *player READ player CONSTANT)
    Q_PROPERTY(TrackListModel *results READ results CONSTANT)
    Q_PROPERTY(TrackListModel *queue READ queue CONSTANT)
    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)

    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentChanged)
    Q_PROPERTY(bool hasTrack READ hasTrack NOTIFY currentChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentChanged)
    Q_PROPERTY(QString currentArtist READ currentArtist NOTIFY currentChanged)
    Q_PROPERTY(QString currentThumbnail READ currentThumbnail NOTIFY currentChanged)
    Q_PROPERTY(QString currentVideoId READ currentVideoId NOTIFY currentChanged)
    // Главный цвет обложки — им подсвечиваются виджеты.
    Q_PROPERTY(QColor accentColor READ accentColor NOTIFY accentColorChanged)

public:
    explicit MusicController(QObject *parent = nullptr);
    ~MusicController() override;

    // Экземпляр создаётся в main(), QML получает тот же объект.
    static void setInstance(MusicController *instance);
    static MusicController *create(QQmlEngine *, QJSEngine *);

    MpvPlayer *player() const { return m_player; }
    TrackListModel *results() const { return m_results; }
    TrackListModel *queue() const { return m_queue; }
    bool searching() const;
    QString errorText() const { return m_errorText; }

    int currentIndex() const { return m_currentIndex; }
    bool hasTrack() const { return m_current.isValid(); }
    QString currentTitle() const { return m_current.title; }
    QString currentArtist() const { return m_current.artist; }
    QString currentThumbnail() const { return m_current.thumbnail; }
    QString currentVideoId() const { return m_current.videoId; }
    QColor accentColor() const { return m_accent; }

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void playResult(int index);   // играть из результатов, очередь = результаты
    Q_INVOKABLE void playQueueIndex(int index);
    Q_INVOKABLE void enqueueResult(int index); // добавить в конец очереди
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void clearError();
    Q_INVOKABLE QString formatTime(double seconds) const;

signals:
    void searchingChanged();
    void errorTextChanged();
    void currentChanged();
    void accentColorChanged();

private:
    void setError(const QString &text);
    void playTrack(const Track &track);
    void fetchAccent(const QString &thumbnailUrl);
    void setAccent(const QColor &color);

    MpvPlayer *m_player = nullptr;
    YouTubeSearch *m_search = nullptr;
    TrackListModel *m_results = nullptr;
    TrackListModel *m_queue = nullptr;

    QNetworkAccessManager *m_net = nullptr;
    QPointer<QNetworkReply> m_coverReply;

    Track m_current;
    int m_currentIndex = -1;
    QString m_errorText;
    QColor m_accent = QColor(0xff, 0x2a, 0x36);

    static MusicController *s_instance;
};

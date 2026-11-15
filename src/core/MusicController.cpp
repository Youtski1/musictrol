#include "core/MusicController.h"

#include <QJSEngine>
#include <QQmlEngine>
#include <cmath>

#include "youtube/YouTubeSearch.h"

MusicController *MusicController::s_instance = nullptr;

MusicController::MusicController(QObject *parent)
    : QObject(parent)
    , m_player(new MpvPlayer(this))
    , m_search(new YouTubeSearch(this))
    , m_results(new TrackListModel(this))
    , m_queue(new TrackListModel(this))
{
    connect(m_search, &YouTubeSearch::busyChanged, this, &MusicController::searchingChanged);
    connect(m_search, &YouTubeSearch::resultsReady, this, [this](const TrackList &tracks) {
        m_results->setTracks(tracks);
        if (tracks.isEmpty())
            setError(tr("Ничего не найдено"));
    });
    connect(m_search, &YouTubeSearch::failed, this, &MusicController::setError);

    connect(m_player, &MpvPlayer::endOfFile, this, &MusicController::next);
    connect(m_player, &MpvPlayer::errorOccurred, this, [this](const QString &msg) {
        setError(tr("Не удалось воспроизвести: %1").arg(msg));
    });
}

MusicController::~MusicController()
{
    if (s_instance == this)
        s_instance = nullptr;
}

void MusicController::setInstance(MusicController *instance)
{
    s_instance = instance;
}

MusicController *MusicController::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

bool MusicController::searching() const
{
    return m_search->busy();
}

void MusicController::search(const QString &query)
{
    clearError();
    m_search->search(query);
}

void MusicController::playResult(int index)
{
    if (index < 0 || index >= m_results->count())
        return;
    m_queue->setTracks(m_results->tracks());
    playQueueIndex(index);
}

void MusicController::playQueueIndex(int index)
{
    if (index < 0 || index >= m_queue->count())
        return;
    m_currentIndex = index;
    playTrack(m_queue->at(index));
}

void MusicController::enqueueResult(int index)
{
    const Track t = m_results->at(index);
    if (!t.isValid())
        return;
    TrackList list = m_queue->tracks();
    list.append(t);
    m_queue->setTracks(list);
    if (!hasTrack())
        playQueueIndex(int(list.size()) - 1);
}

void MusicController::next()
{
    if (m_currentIndex + 1 < m_queue->count())
        playQueueIndex(m_currentIndex + 1);
}

void MusicController::previous()
{
    // Как в обычных плеерах: если трек уже играет больше 3 секунд — в его начало.
    if (m_player->position() > 3.0 || m_currentIndex <= 0) {
        m_player->seek(0);
        return;
    }
    playQueueIndex(m_currentIndex - 1);
}

void MusicController::togglePause()
{
    if (hasTrack())
        m_player->togglePause();
}

void MusicController::clearError()
{
    setError({});
}

QString MusicController::formatTime(double seconds) const
{
    if (seconds <= 0 || !std::isfinite(seconds))
        return QStringLiteral("0:00");
    const int total = int(seconds);
    const int h = total / 3600, m = (total % 3600) / 60, s = total % 60;
    if (h > 0)
        return QStringLiteral("%1:%2:%3").arg(h).arg(m, 2, 10, QLatin1Char('0')).arg(s, 2, 10, QLatin1Char('0'));
    return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
}

void MusicController::setError(const QString &text)
{
    if (m_errorText == text)
        return;
    m_errorText = text;
    emit errorTextChanged();
}

void MusicController::playTrack(const Track &track)
{
    m_current = track;
    clearError();
    m_player->load(track.url);
    emit currentChanged();
}

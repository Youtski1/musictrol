#include "core/MusicController.h"

#include <QImage>
#include <QJSEngine>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlEngine>
#include <cmath>

#include "youtube/YouTubeSearch.h"

MusicController *MusicController::s_instance = nullptr;

namespace {
// «Живой» цвет обложки: средний цвет, где яркие и насыщенные пиксели весят больше.
// Тёмно-серые и почти белые почти не учитываются, чтобы не получить грязный цвет.
QColor vibrantColor(const QImage &source)
{
    const QImage img = source.scaled(32, 32, Qt::IgnoreAspectRatio, Qt::FastTransformation)
                           .convertToFormat(QImage::Format_RGB32);
    double r = 0, g = 0, b = 0, total = 0;
    for (int y = 0; y < img.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(img.constScanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QColor c = QColor::fromRgb(line[x]);
            const double s = c.hsvSaturationF();
            const double v = c.valueF();
            const double w = s * s * v + 0.002;
            r += c.redF() * w; g += c.greenF() * w; b += c.blueF() * w;
            total += w;
        }
    }
    QColor c = QColor::fromRgbF(float(r / total), float(g / total), float(b / total));
    // Подтягиваем к «неоновому» виду: достаточно насыщенный и светлый.
    float h, s, v;
    c.getHsvF(&h, &s, &v);
    if (h < 0)
        return QColor(0xff, 0x2a, 0x36); // обложка почти без цвета — фирменный красный
    return QColor::fromHsvF(h, std::max(s, 0.65f), std::max(v, 0.85f));
}
} // namespace

MusicController::MusicController(QObject *parent)
    : QObject(parent)
    , m_player(new MpvPlayer(this))
    , m_search(new YouTubeSearch(this))
    , m_results(new TrackListModel(this))
    , m_queue(new TrackListModel(this))
    , m_net(new QNetworkAccessManager(this))
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

void MusicController::playFrom(TrackListModel *model, int index)
{
    if (!model || index < 0 || index >= model->count())
        return;
    if (model != m_queue)
        m_queue->setTracks(model->tracks());
    playQueueIndex(index);
}

void MusicController::playQueueIndex(int index)
{
    if (index < 0 || index >= m_queue->count())
        return;
    m_currentIndex = index;
    playTrack(m_queue->at(index));
}

void MusicController::enqueue(TrackListModel *model, int index)
{
    if (!model)
        return;
    const Track t = model->at(index);
    if (!t.isValid())
        return;
    m_queue->append(t);
    if (!hasTrack())
        playQueueIndex(m_queue->count() - 1);
}

void MusicController::removeFromQueue(int index)
{
    if (index < 0 || index >= m_queue->count())
        return;
    m_queue->removeAt(index);
    // Текущий трек продолжает играть; «следующий» — тот, что шёл после удалённого.
    if (index <= m_currentIndex) {
        --m_currentIndex;
        emit currentChanged();
    }
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
    emit trackStarted(track);
    fetchAccent(track.thumbnail);
}

void MusicController::fetchAccent(const QString &thumbnailUrl)
{
    if (m_coverReply) {
        m_coverReply->abort();
        m_coverReply = nullptr;
    }
    if (thumbnailUrl.isEmpty())
        return;

    QNetworkReply *reply = m_net->get(QNetworkRequest(QUrl(thumbnailUrl)));
    m_coverReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply != m_coverReply || reply->error() != QNetworkReply::NoError)
            return;
        m_coverReply = nullptr;
        QImage img;
        if (img.loadFromData(reply->readAll()))
            setAccent(vibrantColor(img));
    });
}

void MusicController::setAccent(const QColor &color)
{
    if (m_accent == color)
        return;
    m_accent = color;
    emit accentColorChanged();
}

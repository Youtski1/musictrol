#include "youtube/YouTubeSearch.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace {
QString thumbnailFor(const QString &videoId)
{
    return QStringLiteral("https://i.ytimg.com/vi/%1/hqdefault.jpg").arg(videoId);
}
} // namespace

YouTubeSearch::YouTubeSearch(QObject *parent)
    : QObject(parent)
{
}

YouTubeSearch::~YouTubeSearch()
{
    cancel();
}

void YouTubeSearch::search(const QString &rawQuery, int limit)
{
    const QString query = rawQuery.trimmed();
    if (query.isEmpty())
        return;

    cancel(); // новый запрос отменяет старый

    if (QStandardPaths::findExecutable(QStringLiteral("yt-dlp")).isEmpty()) {
        emit failed(tr("Не найден yt-dlp. Установите: sudo pacman -S yt-dlp"));
        return;
    }

    const bool isUrl = query.startsWith(QLatin1String("http://")) || query.startsWith(QLatin1String("https://"));
    const QString target = isUrl ? query : QStringLiteral("ytsearch%1:%2").arg(limit).arg(query);

    auto *proc = new QProcess(this);
    m_process = proc;
    connect(proc, &QProcess::finished, this, &YouTubeSearch::onFinished);
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart && proc == m_process) {
            m_process = nullptr;
            proc->deleteLater();
            emit busyChanged();
            emit failed(tr("Не удалось запустить yt-dlp"));
        }
    });

    proc->start(QStringLiteral("yt-dlp"), {
        QStringLiteral("--flat-playlist"),
        QStringLiteral("--dump-json"),
        QStringLiteral("--no-warnings"),
        QStringLiteral("--ignore-errors"),
        QStringLiteral("--playlist-end"), QString::number(isUrl ? 200 : limit),
        target,
    });
    emit busyChanged();
}

void YouTubeSearch::cancel()
{
    if (!m_process)
        return;
    QProcess *proc = m_process;
    m_process = nullptr;
    proc->disconnect(this);
    proc->kill();
    proc->waitForFinished(200);
    proc->deleteLater();
    emit busyChanged();
}

void YouTubeSearch::onFinished(int exitCode, QProcess::ExitStatus status)
{
    auto *proc = qobject_cast<QProcess *>(sender());
    if (!proc || proc != m_process)
        return;

    const QByteArray out = proc->readAllStandardOutput();
    const QByteArray err = proc->readAllStandardError();
    m_process = nullptr;
    proc->deleteLater();
    emit busyChanged();

    const TrackList tracks = parse(out);
    if (tracks.isEmpty() && (status != QProcess::NormalExit || exitCode != 0)) {
        const QString reason = QString::fromUtf8(err).trimmed().section(QLatin1Char('\n'), -1);
        emit failed(reason.isEmpty() ? tr("Поиск не удался") : reason);
        return;
    }
    emit resultsReady(tracks);
}

TrackList YouTubeSearch::parse(const QByteArray &output)
{
    TrackList tracks;
    const QList<QByteArray> lines = output.split('\n');
    for (const QByteArray &line : lines) {
        if (line.trimmed().isEmpty())
            continue;
        const QJsonObject o = QJsonDocument::fromJson(line).object();
        if (o.isEmpty())
            continue;

        // В поиске попадаются каналы и плейлисты — пропускаем, нужны только видео.
        const QString ieKey = o.value(QLatin1String("ie_key")).toString();
        if (ieKey == QLatin1String("YoutubeTab"))
            continue;

        Track t;
        t.videoId = o.value(QLatin1String("id")).toString();
        if (t.videoId.isEmpty())
            continue;
        t.title = o.value(QLatin1String("title")).toString();
        t.artist = o.value(QLatin1String("channel")).toString();
        if (t.artist.isEmpty())
            t.artist = o.value(QLatin1String("uploader")).toString();
        t.duration = o.value(QLatin1String("duration")).toDouble();
        t.url = QStringLiteral("https://www.youtube.com/watch?v=%1").arg(t.videoId);
        t.thumbnail = thumbnailFor(t.videoId);
        tracks.append(t);
    }
    return tracks;
}

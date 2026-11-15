#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>

#include "core/Track.h"

// Поиск на YouTube через yt-dlp (без API-ключей).
// Понимает обычный запрос, ссылку на видео и ссылку на плейлист.
class YouTubeSearch : public QObject
{
    Q_OBJECT

public:
    explicit YouTubeSearch(QObject *parent = nullptr);
    ~YouTubeSearch() override;

    void search(const QString &query, int limit = 20);
    void cancel();
    bool busy() const { return m_process != nullptr; }

signals:
    void busyChanged();
    void resultsReady(const TrackList &tracks);
    void failed(const QString &message);

private:
    void onFinished(int exitCode, QProcess::ExitStatus status);
    static TrackList parse(const QByteArray &output);

    QPointer<QProcess> m_process;
};

#pragma once

#include <QObject>
#include <QtQmlIntegration>

struct mpv_handle;

// Тонкая обёртка над libmpv: только звук, YouTube через встроенный ytdl-хук (yt-dlp).
// Все вызовы асинхронные, события mpv приходят в главный поток через очередь Qt.
class MpvPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Создаётся в C++")
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit MpvPlayer(QObject *parent = nullptr);
    ~MpvPlayer() override;

    bool paused() const { return m_paused; }
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    double volume() const { return m_volume; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void load(const QString &url);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void seek(double seconds);
    void setPaused(bool paused);
    void setVolume(double volume);

signals:
    void pausedChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void loadingChanged();
    void endOfFile();                       // трек доиграл до конца
    void errorOccurred(const QString &message);

private:
    void processEvents();
    void setLoading(bool loading);
    void handlePropertyChange(const char *name, int format, void *data);

    static void wakeup(void *ctx);

    mpv_handle *m_mpv = nullptr;
    bool m_paused = false;
    double m_position = 0;
    double m_duration = 0;
    double m_volume = 70;
    bool m_loading = false;
};

#include "player/MpvPlayer.h"

#include <QDebug>
#include <QMetaObject>
#include <algorithm>
#include <cmath>
#include <cstring>

#include <mpv/client.h>

namespace {
// Позицию обновляем не чаще ~10 раз в секунду: этого хватает для ползунка и
// не гоняет перерисовку интерфейса на каждом аудиокадре.
constexpr double kPositionStep = 0.1;

enum ObserveId : uint64_t {
    PauseId = 1,
    TimePosId,
    DurationId,
    VolumeId,
    MuteId,
};
} // namespace

MpvPlayer::MpvPlayer(QObject *parent)
    : QObject(parent)
{
    m_mpv = mpv_create();
    if (!m_mpv) {
        qCritical() << "mpv_create() failed";
        return;
    }

    // Только звук, никаких окон и клавиш mpv.
    mpv_set_option_string(m_mpv, "vid", "no");
    mpv_set_option_string(m_mpv, "audio-display", "no");
    mpv_set_option_string(m_mpv, "terminal", "no");
    mpv_set_option_string(m_mpv, "input-default-bindings", "no");
    mpv_set_option_string(m_mpv, "idle", "yes");
    // YouTube: mpv сам зовёт yt-dlp и берёт лучшую аудиодорожку.
    mpv_set_option_string(m_mpv, "ytdl", "yes");
    mpv_set_option_string(m_mpv, "ytdl-format", "bestaudio/best");
    mpv_set_option_string(m_mpv, "volume", QByteArray::number(m_volume).constData());
    // Небольшой кэш, чтобы перемотка внутри загруженного куска была мгновенной.
    mpv_set_option_string(m_mpv, "cache", "yes");
    mpv_set_option_string(m_mpv, "demuxer-max-bytes", "32MiB");

    mpv_observe_property(m_mpv, PauseId, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, TimePosId, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, DurationId, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, VolumeId, "volume", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, MuteId, "mute", MPV_FORMAT_FLAG);

    mpv_request_log_messages(m_mpv, "warn");
    mpv_set_wakeup_callback(m_mpv, &MpvPlayer::wakeup, this);

    if (mpv_initialize(m_mpv) < 0) {
        qCritical() << "mpv_initialize() failed";
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
    }
}

MpvPlayer::~MpvPlayer()
{
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
        mpv_terminate_destroy(m_mpv);
    }
}

void MpvPlayer::wakeup(void *ctx)
{
    // Вызывается из потока mpv — переносим обработку в главный поток.
    auto *self = static_cast<MpvPlayer *>(ctx);
    QMetaObject::invokeMethod(self, &MpvPlayer::processEvents, Qt::QueuedConnection);
}

void MpvPlayer::load(const QString &url)
{
    if (!m_mpv)
        return;
    const QByteArray u = url.toUtf8();
    const char *cmd[] = {"loadfile", u.constData(), "replace", nullptr};
    mpv_command_async(m_mpv, 0, cmd);

    setLoading(true);
    if (m_position != 0) { m_position = 0; emit positionChanged(); }
    if (m_duration != 0) { m_duration = 0; emit durationChanged(); }
    setPaused(false);
}

void MpvPlayer::stop()
{
    if (!m_mpv)
        return;
    const char *cmd[] = {"stop", nullptr};
    mpv_command_async(m_mpv, 0, cmd);
    setLoading(false);
}

void MpvPlayer::togglePause()
{
    setPaused(!m_paused);
}

void MpvPlayer::seek(double seconds)
{
    if (!m_mpv)
        return;
    const QByteArray pos = QByteArray::number(std::max(0.0, seconds), 'f', 2);
    const char *cmd[] = {"seek", pos.constData(), "absolute", nullptr};
    mpv_command_async(m_mpv, 0, cmd);
}

void MpvPlayer::setPaused(bool paused)
{
    if (!m_mpv)
        return;
    int flag = paused ? 1 : 0;
    mpv_set_property_async(m_mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
    if (m_paused != paused) {
        m_paused = paused;
        emit pausedChanged();
    }
}

void MpvPlayer::setVolume(double volume)
{
    if (!m_mpv)
        return;
    volume = std::clamp(volume, 0.0, 100.0);
    mpv_set_property_async(m_mpv, 0, "volume", MPV_FORMAT_DOUBLE, &volume);
    if (!qFuzzyCompare(m_volume, volume)) {
        m_volume = volume;
        emit volumeChanged();
    }
}

void MpvPlayer::setMuted(bool muted)
{
    if (!m_mpv)
        return;
    int flag = muted ? 1 : 0;
    mpv_set_property_async(m_mpv, 0, "mute", MPV_FORMAT_FLAG, &flag);
    if (m_muted != muted) {
        m_muted = muted;
        emit mutedChanged();
    }
}

void MpvPlayer::setLoading(bool loading)
{
    if (m_loading == loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}

void MpvPlayer::processEvents()
{
    if (!m_mpv)
        return;

    while (true) {
        mpv_event *ev = mpv_wait_event(m_mpv, 0);
        if (!ev || ev->event_id == MPV_EVENT_NONE)
            break;

        switch (ev->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *prop = static_cast<mpv_event_property *>(ev->data);
            handlePropertyChange(prop->name, prop->format, prop->data);
            break;
        }
        case MPV_EVENT_FILE_LOADED:
        case MPV_EVENT_PLAYBACK_RESTART:
            setLoading(false);
            break;
        case MPV_EVENT_END_FILE: {
            auto *ef = static_cast<mpv_event_end_file *>(ev->data);
            if (ef->reason == MPV_END_FILE_REASON_EOF) {
                setLoading(false);
                emit endOfFile();
            } else if (ef->reason == MPV_END_FILE_REASON_ERROR) {
                setLoading(false);
                emit errorOccurred(QString::fromUtf8(mpv_error_string(ef->error)));
            }
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            auto *msg = static_cast<mpv_event_log_message *>(ev->data);
            qWarning().noquote() << "[mpv]" << msg->prefix << QString::fromUtf8(msg->text).trimmed();
            break;
        }
        case MPV_EVENT_SHUTDOWN:
            mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
            return;
        default:
            break;
        }
    }
}

void MpvPlayer::handlePropertyChange(const char *name, int format, void *data)
{
    if (std::strcmp(name, "pause") == 0) {
        if (format == MPV_FORMAT_FLAG) {
            const bool p = *static_cast<int *>(data) != 0;
            if (p != m_paused) { m_paused = p; emit pausedChanged(); }
        }
    } else if (std::strcmp(name, "time-pos") == 0) {
        const double v = format == MPV_FORMAT_DOUBLE ? *static_cast<double *>(data) : 0.0;
        if (std::abs(v - m_position) >= kPositionStep || v == 0.0) {
            m_position = v;
            emit positionChanged();
        }
    } else if (std::strcmp(name, "duration") == 0) {
        const double v = format == MPV_FORMAT_DOUBLE ? *static_cast<double *>(data) : 0.0;
        if (!qFuzzyCompare(v + 1, m_duration + 1)) { m_duration = v; emit durationChanged(); }
    } else if (std::strcmp(name, "mute") == 0) {
        if (format == MPV_FORMAT_FLAG) {
            const bool m = *static_cast<int *>(data) != 0;
            if (m != m_muted) { m_muted = m; emit mutedChanged(); }
        }
    } else if (std::strcmp(name, "volume") == 0) {
        if (format == MPV_FORMAT_DOUBLE) {
            const double v = *static_cast<double *>(data);
            if (!qFuzzyCompare(v + 1, m_volume + 1)) { m_volume = v; emit volumeChanged(); }
        }
    }
}
